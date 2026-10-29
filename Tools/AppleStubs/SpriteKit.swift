// Stand-ins for the parts of SpriteKit the app uses (see UIKit.swift).
@_exported import UIKit

public enum SKBlendMode: Int { case alpha, add, subtract, multiply, multiplyX2, screen, replace }
public enum SKSceneScaleMode: Int { case fill, aspectFill, aspectFit, resizeFill }
public enum SKTextureFilteringMode: Int { case nearest, linear }
public enum SKLabelVerticalAlignmentMode: Int { case baseline, center, top, bottom }

open class SKTexture: NSObject {
    public init(image: UIImage) {}
    public init(rect: CGRect, in texture: SKTexture) {}
    open var filteringMode: SKTextureFilteringMode = .linear
    open func size() -> CGSize { .zero }
}

open class SKAction: NSObject {
    open class func animate(with textures: [SKTexture], timePerFrame sec: TimeInterval) -> SKAction { SKAction() }
    open class func repeatForever(_ action: SKAction) -> SKAction { SKAction() }
    open class func sequence(_ actions: [SKAction]) -> SKAction { SKAction() }
    open class func group(_ actions: [SKAction]) -> SKAction { SKAction() }
    open class func scale(to scale: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    open class func scaleX(to xScale: CGFloat, y yScale: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    open class func moveBy(x deltaX: CGFloat, y deltaY: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    open class func fadeOut(withDuration duration: TimeInterval) -> SKAction { SKAction() }
    open class func fadeAlpha(to alpha: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    open class func wait(forDuration duration: TimeInterval) -> SKAction { SKAction() }
    open class func removeFromParent() -> SKAction { SKAction() }
}

open class SKNode: UIResponder {
    open var position: CGPoint = .zero
    open var zPosition: CGFloat = 0
    open var xScale: CGFloat = 1
    open var yScale: CGFloat = 1
    open var alpha: CGFloat = 1
    open var children: [SKNode] { [] }
    public override init() {}
    open func addChild(_ node: SKNode) {}
    open func removeFromParent() {}
    open func run(_ action: SKAction) {}
    open func run(_ action: SKAction, withKey key: String) {}
    open func removeAction(forKey key: String) {}
    open func action(forKey key: String) -> SKAction? { nil }
    open func setScale(_ scale: CGFloat) {}
}

open class SKSpriteNode: SKNode {
    open var texture: SKTexture?
    open var size: CGSize = .zero
    open var color: UIColor = .white
    open var colorBlendFactor: CGFloat = 0
    open var blendMode: SKBlendMode = .alpha
    public convenience init(texture: SKTexture?) { self.init() }
    public convenience init(color: UIColor, size: CGSize) { self.init() }
}

open class SKLabelNode: SKNode {
    open var text: String?
    open var fontSize: CGFloat = 32
    open var fontColor: UIColor?
    open var numberOfLines: Int = 1
    open var verticalAlignmentMode: SKLabelVerticalAlignmentMode = .baseline
    public convenience init(fontNamed fontName: String?) { self.init() }
}

open class SKCameraNode: SKNode {}

open class SKView: UIView {
    open var ignoresSiblingOrder: Bool = false
    open var preferredFramesPerSecond: Int = 60
}

open class SKScene: SKNode {
    open var scaleMode: SKSceneScaleMode = .fill
    open var backgroundColor: UIColor = .white
    open var camera: SKCameraNode?
    open var view: SKView? { nil }
    open var size: CGSize = .zero
    public init(size: CGSize) { super.init() }
    public required init?(coder aDecoder: NSCoder) { super.init() }
    open func didMove(to view: SKView) {}
    open func didChangeSize(_ oldSize: CGSize) {}
    open func update(_ currentTime: TimeInterval) {}
}
