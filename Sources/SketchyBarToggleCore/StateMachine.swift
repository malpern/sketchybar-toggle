import Foundation

public enum BarState: Equatable {
    case visible
    case hidden
}

/// Pure state machine for coordinating menu bar and SketchyBar visibility.
/// Extracted from EventTapMonitor for testability.
public final class BarStateMachine {
    public private(set) var state: BarState = .visible

    public let triggerZone: CGFloat
    public let menuBarHeight: CGFloat
    public let debounceInterval: TimeInterval

    private let controller: BarController
    private var debounceTimer: DispatchSourceTimer?
    private let timerQueue: DispatchQueue

    public init(
        controller: BarController,
        triggerZone: CGFloat = 10,
        menuBarHeight: CGFloat = 50,
        debounceInterval: TimeInterval = 0.15,
        timerQueue: DispatchQueue = .main
    ) {
        self.controller = controller
        self.triggerZone = triggerZone
        self.menuBarHeight = menuBarHeight
        self.debounceInterval = debounceInterval
        self.timerQueue = timerQueue
    }

    /// Process a mouse position update. `distanceFromTop` is the distance in pixels
    /// from the mouse cursor to the top edge of the current screen.
    public func handleMousePosition(distanceFromTop: CGFloat) {
        switch state {
        case .visible:
            if distanceFromTop < triggerZone {
                state = .hidden
                cancelDebounce()
                controller.hide()
            }

        case .hidden:
            if distanceFromTop > menuBarHeight {
                startDebounce()
            } else {
                cancelDebounce()
            }
        }
    }

    /// Force a transition to visible. Used on startup/shutdown to restore SketchyBar.
    public func forceVisible() {
        cancelDebounce()
        state = .visible
        controller.show()
    }

    public var hasPendingDebounce: Bool {
        debounceTimer != nil
    }

    // MARK: - Debounce

    private func startDebounce() {
        guard debounceTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + debounceInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.state = .visible
            self.controller.show()
            self.debounceTimer = nil
        }
        debounceTimer = timer
        timer.resume()
    }

    private func cancelDebounce() {
        debounceTimer?.cancel()
        debounceTimer = nil
    }
}
