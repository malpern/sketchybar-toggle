import XCTest
@testable import BarSwitchCore

final class ConfigTests: XCTestCase {

    func testDefaultConfig() throws {
        let config = try parseArguments([])
        XCTAssertEqual(config.triggerZone, 10)
        XCTAssertEqual(config.menuBarHeight, 50)
        XCTAssertEqual(config.debounce, 0.15)
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
