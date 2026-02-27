import Foundation

/// Protocol for controlling SketchyBar visibility. Enables testing with mocks.
public protocol BarController: AnyObject {
    func hide()
    func show()
}
