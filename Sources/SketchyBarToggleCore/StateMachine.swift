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
    public let hideDelay: TimeInterval

    private let controller: BarController
    private var debounceTimer: DispatchSourceTimer?
    private var hideTimer: DispatchSourceTimer?
    private let timerQueue: DispatchQueue

    public init(
        controller: BarController,
        triggerZone: CGFloat = 10,
        menuBarHeight: CGFloat = 50,
        debounceInterval: TimeInterval = 0.15,
        hideDelay: TimeInterval = 0,
        timerQueue: DispatchQueue = .main
    ) {
        self.controller = controller
        self.triggerZone = triggerZone
        self.menuBarHeight = menuBarHeight
        self.debounceInterval = debounceInterval
        self.hideDelay = hideDelay
        self.timerQueue = timerQueue
    }

    /// Process a mouse position update. `distanceFromTop` is the distance in pixels
    /// from the mouse cursor to the top edge of the current screen.
    public func handleMousePosition(distanceFromTop: CGFloat) {
        switch state {
        case .visible:
            if distanceFromTop < triggerZone {
                if hideDelay > 0 {
                    startHideDelay()
                } else {
                    state = .hidden
                    cancelDebounce()
                    controller.hide()
                }
            } else {
                cancelHideDelay()
            }

        case .hidden:
            if distanceFromTop > menuBarHeight {
                startDebounce()
            } else {
                cancelDebounce()
            }
        }
    }

    /// Process a mouse click while in the hidden state.
    /// If the click is outside the trigger zone, immediately restore SketchyBar
    /// so that window title bars near the top of the screen remain interactive.
    public func handleMouseClick(distanceFromTop: CGFloat) {
        if distanceFromTop >= triggerZone {
            cancelHideDelay()
        }
        guard state == .hidden, distanceFromTop >= triggerZone else { return }
        cancelDebounce()
        state = .visible
        controller.show()
    }

    /// Force a transition to visible. Used on startup/shutdown to restore SketchyBar.
    public func forceVisible() {
        cancelHideDelay()
        cancelDebounce()
        state = .visible
        controller.show()
    }

    public var hasPendingDebounce: Bool {
        debounceTimer != nil
    }

    public var hasPendingHide: Bool {
        hideTimer != nil
    }

    deinit {
        hideTimer?.cancel()
        debounceTimer?.cancel()
    }

    // MARK: - Hide delay

    private func startHideDelay() {
        // Polls inside the trigger zone must not restart the dwell timer.
        guard hideTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + hideDelay)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.hideTimer != nil, self.state == .visible else { return }
            self.cancelHideDelay()
            self.cancelDebounce()
            self.state = .hidden
            self.controller.hide()
        }
        hideTimer = timer
        timer.resume()
    }

    private func cancelHideDelay() {
        hideTimer?.cancel()
        hideTimer = nil
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
