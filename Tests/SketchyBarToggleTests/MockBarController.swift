import SketchyBarToggleCore

final class MockBarController: BarController {
    private(set) var hideCallCount = 0
    private(set) var showCallCount = 0
    private(set) var lastAction: Action?

    enum Action: Equatable {
        case hide
        case show
    }

    var actions: [Action] = []

    func hide() {
        hideCallCount += 1
        lastAction = .hide
        actions.append(.hide)
    }

    func show() {
        showCallCount += 1
        lastAction = .show
        actions.append(.show)
    }

    func reset() {
        hideCallCount = 0
        showCallCount = 0
        lastAction = nil
        actions = []
    }
}
