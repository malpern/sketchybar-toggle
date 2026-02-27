import XCTest
@testable import SketchyBarToggleCore

final class StateMachineTests: XCTestCase {

    // MARK: - Basic state transitions

    func testInitialStateIsVisible() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock)
        XCTAssertEqual(sm.state, .visible)
    }

    func testMouseInTriggerZoneHidesBar() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, triggerZone: 2)

        sm.handleMousePosition(distanceFromTop: 1) // inside trigger zone

        XCTAssertEqual(sm.state, .hidden)
        XCTAssertEqual(mock.hideCallCount, 1)
        XCTAssertEqual(mock.showCallCount, 0)
    }

    func testMouseAtExactTriggerZoneBoundaryDoesNotHide() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, triggerZone: 2)

        sm.handleMousePosition(distanceFromTop: 2) // at boundary, not less than

        XCTAssertEqual(sm.state, .visible)
        XCTAssertEqual(mock.hideCallCount, 0)
    }

    func testMouseBelowTriggerZoneNoChange() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, triggerZone: 2)

        sm.handleMousePosition(distanceFromTop: 100)

        XCTAssertEqual(sm.state, .visible)
        XCTAssertEqual(mock.hideCallCount, 0)
    }

    func testMouseInMenuBarZoneStaysHidden() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, triggerZone: 2, menuBarHeight: 40)

        // Enter trigger zone to hide
        sm.handleMousePosition(distanceFromTop: 1)
        XCTAssertEqual(sm.state, .hidden)

        // Move within menu bar zone (between trigger and menuBarHeight)
        sm.handleMousePosition(distanceFromTop: 20)
        XCTAssertEqual(sm.state, .hidden)
        XCTAssertEqual(mock.showCallCount, 0)
    }

    func testMouseAtMenuBarBoundaryStaysHidden() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, triggerZone: 2, menuBarHeight: 40)

        sm.handleMousePosition(distanceFromTop: 1) // hide
        sm.handleMousePosition(distanceFromTop: 40) // exactly at boundary

        XCTAssertEqual(sm.state, .hidden)
        XCTAssertEqual(mock.showCallCount, 0)
    }

    // MARK: - Debounce behavior

    func testMouseLeavingMenuBarStartsDebounce() {
        let mock = MockBarController()
        let sm = BarStateMachine(
            controller: mock,
            triggerZone: 2,
            menuBarHeight: 40,
            debounceInterval: 0.05
        )

        sm.handleMousePosition(distanceFromTop: 1) // hide
        sm.handleMousePosition(distanceFromTop: 50) // leave menu bar zone

        // Should still be hidden — debounce hasn't fired yet
        XCTAssertEqual(sm.state, .hidden)
        XCTAssertTrue(sm.hasPendingDebounce)
    }

    func testDebounceFiresAndShowsBar() {
        let mock = MockBarController()
        let sm = BarStateMachine(
            controller: mock,
            triggerZone: 2,
            menuBarHeight: 40,
            debounceInterval: 0.05,
            timerQueue: .main
        )

        sm.handleMousePosition(distanceFromTop: 1) // hide
        sm.handleMousePosition(distanceFromTop: 50) // leave menu bar zone

        let expectation = XCTestExpectation(description: "Debounce fires")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(sm.state, .visible)
            XCTAssertEqual(mock.showCallCount, 1)
            XCTAssertFalse(sm.hasPendingDebounce)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testDebounceCancelledByReenteringMenuBarZone() {
        let mock = MockBarController()
        let sm = BarStateMachine(
            controller: mock,
            triggerZone: 2,
            menuBarHeight: 40,
            debounceInterval: 0.1
        )

        sm.handleMousePosition(distanceFromTop: 1)  // hide
        sm.handleMousePosition(distanceFromTop: 50) // leave — starts debounce
        XCTAssertTrue(sm.hasPendingDebounce)

        sm.handleMousePosition(distanceFromTop: 20) // re-enter menu bar zone — cancels debounce
        XCTAssertFalse(sm.hasPendingDebounce)
        XCTAssertEqual(sm.state, .hidden)
    }

    // MARK: - Repeated triggers

    func testMultipleMovesInTriggerZoneOnlyHideOnce() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, triggerZone: 2)

        sm.handleMousePosition(distanceFromTop: 1)
        sm.handleMousePosition(distanceFromTop: 0)
        sm.handleMousePosition(distanceFromTop: 1)

        // Only the first triggers hide; after that we're in .hidden state
        XCTAssertEqual(mock.hideCallCount, 1)
    }

    func testMultipleExitsFromMenuBarDontStackDebounces() {
        let mock = MockBarController()
        let sm = BarStateMachine(
            controller: mock,
            triggerZone: 2,
            menuBarHeight: 40,
            debounceInterval: 0.05
        )

        sm.handleMousePosition(distanceFromTop: 1) // hide
        sm.handleMousePosition(distanceFromTop: 50) // start debounce
        sm.handleMousePosition(distanceFromTop: 60) // still outside — should not stack

        XCTAssertTrue(sm.hasPendingDebounce)

        let expectation = XCTestExpectation(description: "Only one show call")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(mock.showCallCount, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Full cycle

    func testFullHideShowCycle() {
        let mock = MockBarController()
        let sm = BarStateMachine(
            controller: mock,
            triggerZone: 2,
            menuBarHeight: 40,
            debounceInterval: 0.05
        )

        // Start visible
        XCTAssertEqual(sm.state, .visible)

        // Mouse hits top — hide
        sm.handleMousePosition(distanceFromTop: 1)
        XCTAssertEqual(sm.state, .hidden)
        XCTAssertEqual(mock.actions, [.hide])

        // Mouse moves away — debounce then show
        sm.handleMousePosition(distanceFromTop: 50)

        let expectation = XCTestExpectation(description: "Full cycle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(sm.state, .visible)
            XCTAssertEqual(mock.actions, [.hide, .show])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Force visible

    func testForceVisibleFromHiddenState() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, triggerZone: 2)

        sm.handleMousePosition(distanceFromTop: 1) // hide
        mock.reset()

        sm.forceVisible()
        XCTAssertEqual(sm.state, .visible)
        XCTAssertEqual(mock.showCallCount, 1)
    }

    func testForceVisibleCancelsPendingDebounce() {
        let mock = MockBarController()
        let sm = BarStateMachine(
            controller: mock,
            triggerZone: 2,
            menuBarHeight: 40,
            debounceInterval: 0.1
        )

        sm.handleMousePosition(distanceFromTop: 1)  // hide
        sm.handleMousePosition(distanceFromTop: 50) // start debounce
        XCTAssertTrue(sm.hasPendingDebounce)

        sm.forceVisible()
        XCTAssertFalse(sm.hasPendingDebounce)
        XCTAssertEqual(sm.state, .visible)
    }

    // MARK: - Custom thresholds

    func testCustomTriggerZone() {
        let mock = MockBarController()
        let sm = BarStateMachine(controller: mock, triggerZone: 10)

        sm.handleMousePosition(distanceFromTop: 5) // inside custom zone
        XCTAssertEqual(sm.state, .hidden)

        let mock2 = MockBarController()
        let sm2 = BarStateMachine(controller: mock2, triggerZone: 10)

        sm2.handleMousePosition(distanceFromTop: 15) // outside custom zone
        XCTAssertEqual(sm2.state, .visible)
    }

    func testCustomMenuBarHeight() {
        let mock = MockBarController()
        let sm = BarStateMachine(
            controller: mock,
            triggerZone: 2,
            menuBarHeight: 60,
            debounceInterval: 0.05
        )

        sm.handleMousePosition(distanceFromTop: 1) // hide
        sm.handleMousePosition(distanceFromTop: 50) // still within custom menu bar zone

        XCTAssertEqual(sm.state, .hidden)
        XCTAssertFalse(sm.hasPendingDebounce)
    }
}
