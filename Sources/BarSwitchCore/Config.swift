import Foundation

public struct Config: Equatable {
    public var triggerZone: CGFloat = 10
    public var menuBarHeight: CGFloat = 50
    public var debounce: TimeInterval = 0.15
    public var checkPermissions = false
    public var setup = false
    public var showVersion = false
    public var showHelp = false

    public init() {}
}

public enum ConfigError: Error, Equatable {
    case unknownArgument(String)
}

/// Parse command-line arguments into a Config. Accepts the args array (excluding argv[0]).
public func parseArguments(_ args: [String]) throws -> Config {
    var config = Config()
    var i = 0

    while i < args.count {
        switch args[i] {
        case "--trigger-zone":
            i += 1
            if i < args.count, let val = Double(args[i]) {
                config.triggerZone = CGFloat(val)
            }
        case "--menu-bar-height":
            i += 1
            if i < args.count, let val = Double(args[i]) {
                config.menuBarHeight = CGFloat(val)
            }
        case "--debounce":
            i += 1
            if i < args.count, let val = Double(args[i]) {
                config.debounce = val / 1000.0
            }
        case "--check-permissions":
            config.checkPermissions = true
        case "--setup":
            config.setup = true
        case "--version":
            config.showVersion = true
        case "--help", "-h":
            config.showHelp = true
        default:
            throw ConfigError.unknownArgument(args[i])
        }
        i += 1
    }

    return config
}
