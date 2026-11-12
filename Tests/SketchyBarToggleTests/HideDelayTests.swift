import XCTest
@testable import SketchyBarToggleCore

final class HideDelayTests: XCTestCase {
    private func after(_ delay: TimeInterval, check: @escaping () -> Void) {
        let done = expectation(description: "Timer check")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            check()
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
    }

    func testHidesOnlyAfterDelayAndOnlyOnce() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, hideDelay: 0.05)
        sm.handleMousePosition(distanceFromTop: 0)
        XCTAssertEqual(sm.state, .visible)
        XCTAssertTrue(sm.hasPendingHide)
        XCTAssertEqual(mock.hideCallCount, 0)
        after(0.15) {
            XCTAssertEqual(sm.state, .hidden)
            XCTAssertFalse(sm.hasPendingHide)
            XCTAssertEqual(mock.hideCallCount, 1)
        }
        after(0.1) { XCTAssertEqual(mock.hideCallCount, 1) }
    }

    func testLeavingTriggerZoneCancelsEvenWithinMenuBarZone() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, triggerZone: 4, hideDelay: 0.05)
        sm.handleMousePosition(distanceFromTop: 0)
        sm.handleMousePosition(distanceFromTop: 4) // exact trigger boundary cancels
        XCTAssertFalse(sm.hasPendingHide)
        after(0.15) {
            XCTAssertEqual(sm.state, .visible)
            XCTAssertEqual(mock.hideCallCount, 0)
        }
    }

    func testRepeatedPollsDoNotRestartHideDelay() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, hideDelay: 0.1)
        sm.handleMousePosition(distanceFromTop: 0)
        let poll = DispatchSource.makeTimerSource(queue: .main)
        poll.schedule(deadline: .now(), repeating: 0.01)
        poll.setEventHandler { sm.handleMousePosition(distanceFromTop: 1) }
        poll.resume()
        defer { poll.cancel() }
        after(0.25) {
            XCTAssertEqual(sm.state, .hidden)
            XCTAssertEqual(mock.hideCallCount, 1)
        }
    }

    func testReentryStartsFreshDelay() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, hideDelay: 0.1)
        sm.handleMousePosition(distanceFromTop: 0)
        sm.handleMousePosition(distanceFromTop: 30)
        after(0.15) { XCTAssertEqual(mock.hideCallCount, 0) }
        sm.handleMousePosition(distanceFromTop: 0)
        XCTAssertEqual(sm.state, .visible)
        XCTAssertTrue(sm.hasPendingHide)
        after(0.2) { XCTAssertEqual(mock.hideCallCount, 1) }
    }

    func testForceVisibleCancelsPendingHide() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, hideDelay: 0.05)
        sm.handleMousePosition(distanceFromTop: 0)
        sm.forceVisible()
        XCTAssertFalse(sm.hasPendingHide)
        after(0.15) {
            XCTAssertEqual(sm.state, .visible)
            XCTAssertEqual(mock.actions, [.show])
        }
    }

    func testClickOutsideTriggerCancelsPendingHide() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, hideDelay: 0.05)
        sm.handleMousePosition(distanceFromTop: 0)
        sm.handleMouseClick(distanceFromTop: 30)
        XCTAssertFalse(sm.hasPendingHide)
        after(0.15) { XCTAssertEqual(mock.actions, []) }
    }

    func testDelayedHideStillUsesShowDebounceAndClickRestore() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, debounceInterval: 0.05, hideDelay: 0.05)
        sm.handleMousePosition(distanceFromTop: 0)
        after(0.15) { XCTAssertEqual(sm.state, .hidden) }
        sm.handleMousePosition(distanceFromTop: 100)
        XCTAssertTrue(sm.hasPendingDebounce)
        after(0.15) { XCTAssertEqual(mock.actions, [.hide, .show]) }
        sm.handleMousePosition(distanceFromTop: 0)
        after(0.15) { XCTAssertEqual(sm.state, .hidden) }
        sm.handleMouseClick(distanceFromTop: 30)
        XCTAssertEqual(mock.actions, [.hide, .show, .hide, .show])
        XCTAssertEqual(sm.state, .visible)
    }

    func testDeallocationCancelsPendingHide() {
        let mock = MockBarController()
        var sm: BarStateMachine? = BarStateMachine(controller: mock, hideDelay: 0.05)
        weak var weakSM = sm
        sm?.handleMousePosition(distanceFromTop: 0)
        sm = nil
        XCTAssertNil(weakSM)
        after(0.15) { XCTAssertEqual(mock.hideCallCount, 0) }
    }
}
