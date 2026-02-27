import CoreGraphics
import AppKit
import Foundation

/// Sets up a CGEventTap for mouse-moved events and feeds positions to the state machine.
public final class EventTapMonitor {
    private let stateMachine: BarStateMachine
    private var eventTap: CFMachPort?

    public init(stateMachine: BarStateMachine) {
        self.stateMachine = stateMachine
    }

    /// Start monitoring mouse events. Returns false if the event tap couldn't be created
    /// (usually means Input Monitoring permission is not granted).
    public func start() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<EventTapMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handleMouseMoved(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPointer
        ) else {
            return false
        }

        eventTap = tap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func handleMouseMoved(event: CGEvent) {
        let mouseLocation = event.location

        guard let screen = screenForPoint(mouseLocation) else { return }

        let screenTopY = screenTopCGY(for: screen)
        let distanceFromTop = mouseLocation.y - screenTopY

        stateMachine.handleMousePosition(distanceFromTop: distanceFromTop)
    }

    // MARK: - Screen geometry helpers

    private func screenForPoint(_ cgPoint: CGPoint) -> NSScreen? {
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let mainHeight = mainScreen.frame.height
        let nsPoint = NSPoint(x: cgPoint.x, y: mainHeight - cgPoint.y)

        for screen in NSScreen.screens {
            // Expand by 1px to include screen edges. NSRect.contains() uses
            // half-open intervals (excludes maxX/maxY), but CG Y=0 (top of
            // screen) maps to NS maxY, so the top edge would be excluded.
            if screen.frame.insetBy(dx: -1, dy: -1).contains(nsPoint) {
                return screen
            }
        }
        return nil
    }

    private func screenTopCGY(for screen: NSScreen) -> CGFloat {
        guard let mainScreen = NSScreen.screens.first else { return 0 }
        let mainHeight = mainScreen.frame.height
        let nsTopY = screen.frame.origin.y + screen.frame.height
        return mainHeight - nsTopY
    }
}
