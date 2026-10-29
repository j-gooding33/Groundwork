// Stand-ins for the parts of UIKit the app uses, so Tools/check_app.sh can
// type-check app code on Linux. Signatures follow Apple's SDK; these do nothing.
@_exported import Foundation

open class UIColor: NSObject {
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
    public static var white: UIColor { UIColor(red: 1, green: 1, blue: 1, alpha: 1) }
}

open class UIImage: NSObject {
    public init?(contentsOfFile path: String) {}
}

@MainActor
open class UIResponder: NSObject {
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}
}

open class UIView: UIResponder {
    open var bounds: CGRect = .zero
    open var isMultipleTouchEnabled: Bool = false
}

open class UITouch: NSObject {
    open var timestamp: TimeInterval { 0 }
    open func location(in view: UIView?) -> CGPoint { .zero }
}

open class UIEvent: NSObject {}

@MainActor
open class UIFeedbackGenerator: NSObject {
    open func prepare() {}
}

open class UIImpactFeedbackGenerator: UIFeedbackGenerator {
    public enum FeedbackStyle: Int { case light, medium, heavy, soft, rigid }
    public init(style: FeedbackStyle) {}
    open func impactOccurred() {}
}

open class UINotificationFeedbackGenerator: UIFeedbackGenerator {
    public enum FeedbackType: Int { case success, warning, error }
    public override init() {}
    open func notificationOccurred(_ notificationType: FeedbackType) {}
}
