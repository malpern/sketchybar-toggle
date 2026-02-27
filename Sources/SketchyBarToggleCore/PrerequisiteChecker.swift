import Foundation

public struct PrerequisiteReport {
    public let sketchyBarRunning: Bool
    public let topmostValue: String?
    public let topmostCorrect: Bool
    public let menuBarAutoHide: Bool
    public var issues: [String]

    public var allPassed: Bool { issues.isEmpty }

    public init(
        sketchyBarRunning: Bool,
        topmostValue: String?,
        topmostCorrect: Bool,
        menuBarAutoHide: Bool,
        issues: [String]
    ) {
        self.sketchyBarRunning = sketchyBarRunning
        self.topmostValue = topmostValue
        self.topmostCorrect = topmostCorrect
        self.menuBarAutoHide = menuBarAutoHide
        self.issues = issues
    }
}

public final class PrerequisiteChecker {
    private let sketchybarPath: String

    public init() {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/sketchybar") {
            sketchybarPath = "/opt/homebrew/bin/sketchybar"
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/sketchybar") {
            sketchybarPath = "/usr/local/bin/sketchybar"
        } else {
            sketchybarPath = "sketchybar"
        }
    }

    public func check() -> PrerequisiteReport {
        var issues: [String] = []

        // Check SketchyBar running + topmost value
        let (running, topmostVal) = querySketchyBar()
        let topmostCorrect: Bool
        if !running {
            issues.append("SketchyBar does not appear to be running")
            topmostCorrect = false
        } else if let val = topmostVal {
            topmostCorrect = val == "window"
            if !topmostCorrect {
                issues.append("SketchyBar topmost is set to \"\(val)\" — it must be \"window\" for sketchybar-toggle to work")
            }
        } else {
            topmostCorrect = false
            issues.append("Could not read topmost value from SketchyBar — ensure topmost = \"window\" is set")
        }

        // Check menu bar auto-hide
        let autoHide = checkMenuBarAutoHide()
        if !autoHide {
            issues.append("macOS menu bar auto-hide is not enabled (System Settings > Control Center > Automatically hide and show the menu bar)")
        }

        return PrerequisiteReport(
            sketchyBarRunning: running,
            topmostValue: topmostVal,
            topmostCorrect: topmostCorrect,
            menuBarAutoHide: autoHide,
            issues: issues
        )
    }

    // MARK: - Internal (for testing)

    /// Parse the topmost value from `sketchybar --query bar` JSON output.
    internal func parseTopmost(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let topmost = obj["topmost"] else {
            return nil
        }
        if let str = topmost as? String {
            return str
        }
        // Handle boolean/numeric values — sketchybar returns strings, but be safe
        if let bool = topmost as? Bool {
            return bool ? "on" : "off"
        }
        return "\(topmost)"
    }

    // MARK: - Private

    private func querySketchyBar() -> (running: Bool, topmost: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sketchybarPath)
        process.arguments = ["--query", "bar"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (false, nil)
        }

        guard process.terminationStatus == 0 else {
            return (false, nil)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return (true, nil)
        }

        return (true, parseTopmost(from: output))
    }

    private func checkMenuBarAutoHide() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "NSGlobalDomain", "_HIHideMenuBar"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        guard process.terminationStatus == 0 else {
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output == "1"
    }
}
