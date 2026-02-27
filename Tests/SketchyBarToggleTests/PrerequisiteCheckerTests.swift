import XCTest
@testable import SketchyBarToggleCore

final class PrerequisiteCheckerTests: XCTestCase {

    let checker = PrerequisiteChecker()

    // MARK: - parseTopmost

    func testParseTopmostWindow() {
        let json = """
        {"topmost": "window", "hidden": "off", "color": "0xff000000"}
        """
        XCTAssertEqual(checker.parseTopmost(from: json), "window")
    }

    func testParseTopmostOff() {
        let json = """
        {"topmost": "off", "hidden": "off"}
        """
        XCTAssertEqual(checker.parseTopmost(from: json), "off")
    }

    func testParseTopmostMissing() {
        let json = """
        {"hidden": "off", "color": "0xff000000"}
        """
        XCTAssertNil(checker.parseTopmost(from: json))
    }

    func testParseTopmostInvalidJSON() {
        XCTAssertNil(checker.parseTopmost(from: "not json"))
    }

    func testParseTopmostEmptyString() {
        XCTAssertNil(checker.parseTopmost(from: ""))
    }

    func testParseTopmostEmptyObject() {
        XCTAssertNil(checker.parseTopmost(from: "{}"))
    }

    // MARK: - PrerequisiteReport.allPassed

    func testAllPassedWithNoIssues() {
        let report = PrerequisiteReport(
            sketchyBarRunning: true,
            topmostValue: "window",
            topmostCorrect: true,
            menuBarAutoHide: true,
            issues: []
        )
        XCTAssertTrue(report.allPassed)
    }

    func testAllPassedWithIssues() {
        let report = PrerequisiteReport(
            sketchyBarRunning: false,
            topmostValue: nil,
            topmostCorrect: false,
            menuBarAutoHide: true,
            issues: ["SketchyBar does not appear to be running"]
        )
        XCTAssertFalse(report.allPassed)
    }

    func testAllPassedWithMultipleIssues() {
        let report = PrerequisiteReport(
            sketchyBarRunning: false,
            topmostValue: nil,
            topmostCorrect: false,
            menuBarAutoHide: false,
            issues: [
                "SketchyBar does not appear to be running",
                "macOS menu bar auto-hide is not enabled"
            ]
        )
        XCTAssertFalse(report.allPassed)
    }
}
