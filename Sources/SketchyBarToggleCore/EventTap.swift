import CoreGraphics
import AppKit
import Foundation

/// Monitors mouse position by polling NSEvent.mouseLocation on a timer.
/// This approach requires no special permissions (no Input Monitoring or Accessibility).
public final class EventTapMonitor {
    private let stateMachine: BarStateMachine
    private let debugLog: ((String) -> Void)?
    private var pollTimer: DispatchSourceTimer?
    private let pollInterval: TimeInterval
    private var pollCount = 0

    public init(
        stateMachine: BarStateMachine,
        debugLog: ((String) -> Void)? = nil,
        pollInterval: TimeInterval = 0.016  // ~60 Hz
    ) {
        self.stateMachine = stateMachine
        self.debugLog = debugLog
        self.pollInterval = pollInterval
    }

    /// Start monitoring mouse position. Always returns true (no permissions needed).
    @discardableResult
    public func start() -> Bool {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            self?.pollMousePosition()
        }
        pollTimer = timer
        timer.resume()
        debugLog?("polling started at \(Int(1.0 / pollInterval)) Hz")
        return true
    }

    public func stop() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    private func pollMousePosition() {
        // NSEvent.mouseLocation is in NS coordinates (origin bottom-left)
        let mouseNS = NSEvent.mouseLocation
        guard let screen = screenForNSPoint(mouseNS) else {
            return
        }

        // Convert to distance from top of screen
        let screenTopNS = screen.frame.origin.y + screen.frame.height
        let distanceFromTop = screenTopNS - mouseNS.y

        pollCount += 1
        if distanceFromTop < 60 || pollCount <= 3 || pollCount % 1000 == 0 {
            debugLog?("poll#\(pollCount) dist=\(Int(distanceFromTop)) state=\(stateMachine.state)")
        }

        stateMachine.handleMousePosition(distanceFromTop: distanceFromTop)
    }

    // MARK: - Screen geometry helpers

    private func screenForNSPoint(_ nsPoint: NSPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            // Expand by 1px to include screen edges (NSRect.contains uses half-open intervals)
            if screen.frame.insetBy(dx: -1, dy: -1).contains(nsPoint) {
                return screen
            }
        }
        return nil
    }
}
