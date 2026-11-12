import XCTest
@testable import SketchyBarToggleCore

final class ConfigTests: XCTestCase {

    func testDefaultConfig() throws {
        let config = try parseArguments([])
        XCTAssertEqual(config.triggerZone, 10)
        XCTAssertEqual(config.menuBarHeight, 50)
        XCTAssertEqual(config.debounce, 0.15)
        XCTAssertEqual(config.hideDelay, 0)
        XCTAssertFalse(config.checkPermissions)
        XCTAssertFalse(config.setup)
        XCTAssertFalse(config.showVersion)
        XCTAssertFalse(config.showHelp)
    }

    func testTriggerZone() throws {
        let config = try parseArguments(["--trigger-zone", "5"])
        XCTAssertEqual(config.triggerZone, 5)
    }

    func testMenuBarHeight() throws {
        let config = try parseArguments(["--menu-bar-height", "44"])
        XCTAssertEqual(config.menuBarHeight, 44)
    }

    func testDebounceConvertsMillisecondsToSeconds() throws {
        let config = try parseArguments(["--debounce", "300"])
        XCTAssertEqual(config.debounce, 0.3)
    }

    func testHideDelayConvertsMillisecondsToSeconds() throws {
        let config = try parseArguments(["--hide-delay", "300"])
        XCTAssertEqual(config.hideDelay, 0.3)
    }

    func testHideDelayAcceptsZeroAndFractionalMilliseconds() throws {
        XCTAssertEqual(try parseArguments(["--hide-delay", "0"]).hideDelay, 0)
        XCTAssertEqual(try parseArguments(["--hide-delay", "12.5"]).hideDelay, 0.0125)
    }

    func testInvalidHideDelayThrows() {
        for value in ["-1", "nan", "inf", "1e999", "abc", "--debug"] {
            XCTAssertThrowsError(try parseArguments(["--hide-delay", value])) { error in
                XCTAssertEqual(error as? ConfigError, .invalidHideDelay)
            }
        }
        XCTAssertThrowsError(try parseArguments(["--hide-delay"])) { error in
            XCTAssertEqual(error as? ConfigError, .invalidHideDelay)
        }
    }

    func testHideAndShowDelaysAreIndependent() throws {
        let config = try parseArguments(["--hide-delay", "300", "--debounce", "1"])
        XCTAssertEqual(config.hideDelay, 0.3)
        XCTAssertEqual(config.debounce, 0.001)
    }

    func testCheckPermissions() throws {
        let config = try parseArguments(["--check-permissions"])
        XCTAssertTrue(config.checkPermissions)
    }

    func testSetup() throws {
        let config = try parseArguments(["--setup"])
        XCTAssertTrue(config.setup)
    }

    func testVersion() throws {
        let config = try parseArguments(["--version"])
        XCTAssertTrue(config.showVersion)
    }

    func testMultipleArguments() throws {
        let config = try parseArguments([
            "--trigger-zone", "4",
            "--menu-bar-height", "44",
            "--debounce", "300"
        ])
        XCTAssertEqual(config.triggerZone, 4)
        XCTAssertEqual(config.menuBarHeight, 44)
        XCTAssertEqual(config.debounce, 0.3)
    }

    func testUnknownArgumentThrows() {
        XCTAssertThrowsError(try parseArguments(["--unknown"])) { error in
            guard case ConfigError.unknownArgument("--unknown") = error else {
                XCTFail("Expected unknownArgument error")
                return
            }
        }
    }

    func testFloatingPointTriggerZone() throws {
        let config = try parseArguments(["--trigger-zone", "2.5"])
        XCTAssertEqual(config.triggerZone, 2.5)
    }

    func testHelpFlag() throws {
        let config = try parseArguments(["--help"])
        XCTAssertTrue(config.showHelp)
        XCTAssertFalse(config.showVersion)
    }

    func testShortHelpFlag() throws {
        let config = try parseArguments(["-h"])
        XCTAssertTrue(config.showHelp)
        XCTAssertFalse(config.showVersion)
    }
}
