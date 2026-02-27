# BarSwitch

A lightweight macOS daemon that coordinates between [SketchyBar](https://github.com/FelixKratz/SketchyBar) and the native macOS menu bar.

## The Problem

If you use SketchyBar with the native macOS menu bar set to "auto-hide," both bars fight for the same space at the top of the screen. When you move your mouse up to reveal the native menu bar, it slides down *over* SketchyBar, creating an ugly overlap. There's no built-in way to coordinate them.

## What BarSwitch Does

BarSwitch watches your mouse position and:

1. **Mouse approaches the top of the screen** — BarSwitch hides SketchyBar so the native menu bar can appear cleanly
2. **Mouse moves away from the top** — BarSwitch slides SketchyBar back into view

The result: you get SketchyBar as your primary status bar, with seamless access to the native menu bar whenever you need it. The two never overlap.

## Prerequisites

1. **[SketchyBar](https://github.com/FelixKratz/SketchyBar)** installed and running
2. **macOS menu bar set to auto-hide**: System Settings > Control Center > "Automatically hide and show the menu bar" > select "Always" or "In Full Screen Only"

## Install

### Homebrew (recommended)

```bash
brew install malpern/tap/barswitch
```

### Build from source

```bash
git clone https://github.com/malpern/barswitch.git
cd barswitch
swift build -c release
```

Then copy the binary somewhere on your PATH:

```bash
# Apple Silicon (default Homebrew prefix)
cp .build/release/barswitch /opt/homebrew/bin/

# Or Intel Mac
cp .build/release/barswitch /usr/local/bin/
```

Requires Swift 5.9+ and macOS 13 (Ventura) or later.

### Grant Input Monitoring permission

BarSwitch needs **Input Monitoring** permission to track mouse position:

1. Run `barswitch` — macOS will prompt you to grant permission, or it will print an error
2. Go to **System Settings > Privacy & Security > Input Monitoring**
3. Add and enable the `barswitch` binary
4. Restart barswitch after granting permission

You can verify with `barswitch --check-permissions`.

## SketchyBar Configuration

BarSwitch works best when your SketchyBar bar settings allow for smooth hide/show transitions. BarSwitch controls your bar using:

- `sketchybar --bar hidden=on` — to hide
- `sketchybar --bar hidden=off y_offset=-50` followed by `sketchybar --animate sin 12 --bar y_offset=0` — to show with a slide-down animation

No changes to your SketchyBar config are required. BarSwitch works with any SketchyBar setup out of the box.

### Optional: transparent bar style

If you want your SketchyBar to visually match the native macOS menu bar (transparent background, no borders), here's an example bar config:

```lua
-- bar.lua
sbar.bar({
  height = 35,
  margin = 0,
  y_offset = 0,
  corner_radius = 0,
  color = 0x00000000,  -- fully transparent
  blur_radius = 0,
  border_width = 0,
})
```

And remove borders from the default item style:

```lua
-- default.lua (background section)
background = {
  height = 28,
  corner_radius = 5,
  border_width = 0,
  border_color = 0x00000000,
  color = 0x00000000,
},
```

## Auto-start

### Recommended: launch from SketchyBar's config

The simplest way to auto-start BarSwitch is to launch it from your SketchyBar config. This way BarSwitch starts and stops with SketchyBar.

If you use a **Lua config** (`sketchybarrc` calls into Lua), add this to your `init.lua` or `sketchybarrc`:

```lua
-- Kill any existing instance, then start barswitch in the background
sbar.exec("pkill -x barswitch; barswitch &")
```

If you use a **shell-based** `sketchybarrc`:

```bash
# Start barswitch alongside SketchyBar
pkill -x barswitch
barswitch &
```

### Alternative: launchd plist

If you prefer BarSwitch to run independently (e.g., start at login regardless of SketchyBar), copy the included plist:

```bash
cp com.barswitch.agent.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.barswitch.agent.plist
```

> **Note:** Edit the plist if your binary isn't at `/usr/local/bin/barswitch` — update the path in `ProgramArguments`.

To stop:

```bash
launchctl unload ~/Library/LaunchAgents/com.barswitch.agent.plist
```

Logs are written to `/tmp/barswitch.log`.

## Usage

```bash
# Run with defaults
barswitch

# Custom thresholds
barswitch --trigger-zone 10 --menu-bar-height 50 --debounce 150

# Check permissions
barswitch --check-permissions

# Print version
barswitch --version
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--trigger-zone <px>` | 10 | Distance from top of screen (in pixels) that triggers SketchyBar to hide |
| `--menu-bar-height <px>` | 50 | Distance from top defining the menu bar zone — SketchyBar won't reappear until the mouse is below this |
| `--debounce <ms>` | 150 | Delay in milliseconds before SketchyBar reappears, prevents flicker on rapid mouse movement |
| `--check-permissions` | | Check if Input Monitoring permission is granted |
| `--version` | | Print version |
| `--help` | | Show help |

### Tuning tips

- **SketchyBar hides too late** (you see overlap): decrease `--trigger-zone` (e.g., `--trigger-zone 5`)
- **SketchyBar hides when you don't want it to**: increase `--trigger-zone`
- **SketchyBar reappears while the menu bar is still visible**: increase `--menu-bar-height` (e.g., `--menu-bar-height 60`)
- **Transitions feel slow**: decrease `--debounce` (e.g., `--debounce 100`)
- **Flickering on rapid mouse movement**: increase `--debounce`

## How It Works

BarSwitch uses a passive [CGEventTap](https://developer.apple.com/documentation/coregraphics/cgevent) to monitor mouse movement at the Core Graphics level. This is event-driven (zero CPU when the mouse isn't moving) and works globally across all apps, including fullscreen.

The core logic is a simple state machine:

```
SKETCHYBAR_VISIBLE (default)
  → mouse enters trigger zone (top 10px)
  → hide SketchyBar instantly

SKETCHYBAR_HIDDEN
  → mouse leaves menu bar zone (below 50px)
  → wait for debounce (150ms)
  → slide SketchyBar back into view
```

BarSwitch controls SketchyBar via its CLI (`sketchybar --bar hidden=on/off`) and uses SketchyBar's built-in animation system for smooth slide-down transitions.

On startup, BarSwitch restores SketchyBar to visible (in case a previous instance crashed with the bar hidden). On SIGTERM/SIGINT (Ctrl+C or `kill`), it restores visibility before exiting.

## Architecture

```
barswitch/
├── Package.swift
├── Sources/
│   ├── BarSwitchCore/                  # Library — all testable logic
│   │   ├── BarController.swift         # Protocol for bar control (enables mocking)
│   │   ├── StateMachine.swift          # State machine: visible ↔ hidden with debounce
│   │   ├── EventTap.swift              # CGEventTap setup + screen geometry
│   │   ├── SketchyBarController.swift  # Shells out to sketchybar CLI
│   │   └── Config.swift                # CLI argument parsing
│   └── BarSwitch/
│       └── main.swift                  # Entry point, signal handlers, run loop
├── Tests/
│   └── BarSwitchTests/                 # 27 unit tests
├── com.barswitch.agent.plist           # launchd plist for auto-start
└── README.md
```

## Requirements

- macOS 13+ (Ventura)
- [SketchyBar](https://github.com/FelixKratz/SketchyBar)
- Swift 5.9+ (build only)
- No runtime dependencies — uses only system frameworks (CoreGraphics, AppKit, Foundation)

## License

MIT
