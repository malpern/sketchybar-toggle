import Foundation
import AppKit
import SketchyBarToggleCore

let version = "0.4.0"

// MARK: - Parse arguments

let config: Config
do {
    config = try parseArguments(Array(CommandLine.arguments.dropFirst()))
} catch let ConfigError.unknownArgument(arg) {
    fputs("Unknown argument: \(arg)\n", stderr)
    printUsage()
    exit(1)
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}

if config.showHelp {
    printUsage()
    exit(0)
}

if config.showVersion {
    print("sketchybar-toggle \(version)")
    exit(0)
}

if config.checkPermissions {
    print("No special permissions required (v0.4.0+ uses polling instead of event taps).")
    exit(0)
}

if config.setup {
    runSetup()
    exit(0)
}

// MARK: - Setup

let controller = SketchyBarController()
let stateMachine = BarStateMachine(
    controller: controller,
    triggerZone: config.triggerZone,
    menuBarHeight: config.menuBarHeight,
    debounceInterval: config.debounce
)

// Ensure SketchyBar is visible on startup (recover from previous crash)
stateMachine.forceVisible()

// Signal handlers — restore SketchyBar on exit
func restoreAndExit() {
    controller.show()
    exit(0)
}

signal(SIGINT) { _ in restoreAndExit() }
signal(SIGTERM) { _ in restoreAndExit() }

// Debug logging
var debugLogFile: FileHandle?
let debugLog: ((String) -> Void)?

if config.debug || ProcessInfo.processInfo.environment["SKETCHYBAR_TOGGLE_DEBUG"] != nil {
    let logPath = "/tmp/sketchybar-toggle-debug.log"
    FileManager.default.createFile(atPath: logPath, contents: nil)
    debugLogFile = FileHandle(forWritingAtPath: logPath)
    debugLog = { msg in
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
        debugLogFile?.write(line.data(using: .utf8) ?? Data())
    }
    debugLog?("started with trigger=\(Int(config.triggerZone)) menuBar=\(Int(config.menuBarHeight)) debounce=\(Int(config.debounce * 1000))ms")
} else {
    debugLog = nil
}

let monitor = EventTapMonitor(stateMachine: stateMachine, debugLog: debugLog)
monitor.start()

print("sketchybar-toggle v\(version) running (trigger: \(Int(config.triggerZone))px, menu bar: \(Int(config.menuBarHeight))px, debounce: \(Int(config.debounce * 1000))ms)")
if config.debug { print("Debug logging to /tmp/sketchybar-toggle-debug.log") }
print("Press Ctrl+C to stop.")

// Quick prerequisite check — warn but don't block
do {
    let checker = PrerequisiteChecker()
    let report = checker.check()
    if !report.allPassed {
        fputs("\nWarning: some prerequisites are not met:\n", stderr)
        for issue in report.issues {
            fputs("  - \(issue)\n", stderr)
        }
        fputs("Run `sketchybar-toggle --setup` for details.\n\n", stderr)
    }
}

// Run the main run loop — NSApplication needed for NSScreen
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.run()

// MARK: - Helpers

func printUsage() {
    print("""
    Usage: sketchybar-toggle [options]

    Options:
      --trigger-zone <px>       Pixels from top of screen to trigger hide (default: 10)
      --menu-bar-height <px>    Pixels from top defining menu bar zone (default: 50)
      --debounce <ms>           Debounce delay in milliseconds (default: 150)
      --check-permissions       Check permissions (no longer needed in v0.4.0+)
      --setup                   Check prerequisites and show auto-start instructions
      --debug                   Log events to /tmp/sketchybar-toggle-debug.log
      --version                 Print version and exit
      --help, -h                Show this help
    """)
}

func runSetup() {
    // Run prerequisite checks first
    let checker = PrerequisiteChecker()
    let report = checker.check()

    print("Checking prerequisites...\n")

    // SketchyBar running
    if report.sketchyBarRunning {
        print("  [ok] SketchyBar is running")
    } else {
        print("  [!!] SketchyBar does not appear to be running")
    }

    // topmost setting (SketchyBar normalizes "window" to "on" in query output)
    if report.topmostCorrect {
        if report.topmostValue == "on" {
            print("  [ok] topmost = \"on\" (SketchyBar reports \"window\" as \"on\")")
        } else {
            print("  [ok] topmost = \"\(report.topmostValue ?? "window")\"")
        }
    } else if let val = report.topmostValue {
        print("  [!!] topmost = \"\(val)\" (must be \"window\")")
    } else if report.sketchyBarRunning {
        print("  [!!] Could not read topmost value (ensure topmost = \"window\" is set)")
    } else {
        print("  [!!] Cannot check topmost (SketchyBar not running)")
    }

    // Menu bar auto-hide
    if report.menuBarAutoHide {
        print("  [ok] macOS menu bar auto-hide is enabled")
    } else {
        print("  [!!] macOS menu bar auto-hide is not enabled")
        print("       Set it in System Settings > Control Center > Automatically hide and show the menu bar")
        print("       After changing, run: killall Dock")
    }

    print("")
    if report.allPassed {
        print("All prerequisites met.\n")
    } else {
        print("Some prerequisites need attention (see above).\n")
    }

    // Existing auto-start instructions
    let home = FileManager.default.homeDirectoryForCurrentUser
    let configDir = home.appendingPathComponent(".config/sketchybar")
    let initLua = configDir.appendingPathComponent("init.lua")
    let sketchybarrc = configDir.appendingPathComponent("sketchybarrc")

    let fm = FileManager.default

    if fm.fileExists(atPath: initLua.path) {
        printSetupInstructions(configFile: initLua, format: .lua)
    } else if fm.fileExists(atPath: sketchybarrc.path) {
        printSetupInstructions(configFile: sketchybarrc, format: .shell)
    } else {
        print("Could not find SketchyBar config at \(configDir.path)/")
        print("See the README for manual setup: https://github.com/malpern/sketchybar-toggle#auto-start")
    }
}

enum ConfigFormat {
    case lua
    case shell
}

func printSetupInstructions(configFile: URL, format: ConfigFormat) {
    let formatName = format == .lua ? "Lua" : "shell"
    print("Found SketchyBar \(formatName) config at \(configFile.path)")

    if let contents = try? String(contentsOfFile: configFile.path, encoding: .utf8),
       contents.contains("sketchybar-toggle") {
        print("sketchybar-toggle is already configured to auto-start. No changes needed.")
        return
    }

    print("")
    switch format {
    case .lua:
        print("Add this line to \(configFile.path) (before sbar.event_loop()):")
        print("")
        print("  sbar.exec(\"pkill -x sketchybar-toggle; sketchybar-toggle &\")")
    case .shell:
        print("Add this line to the end of \(configFile.path):")
        print("")
        print("  pkill -x sketchybar-toggle; sketchybar-toggle &")
    }
    print("")
    print("Then restart SketchyBar: brew services restart sketchybar")
}
