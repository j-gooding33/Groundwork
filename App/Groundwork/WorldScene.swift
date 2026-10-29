import SpriteKit
import UIKit
import GroundworkCore
import GroundworkView

/// Draws what GroundworkView's SceneBuilder says exists, and passes touches
/// to the store. No game decisions are made here.
@MainActor
final class WorldScene: SKScene {
    weak var store: GameStore?
    private var atlas: Atlas?
    private let cameraNode = SKCameraNode()
    private let staticLayer = SKNode()
    private let dynamicLayer = SKNode()
    private let overlayLayer = SKNode()
    private let tintNode = SKSpriteNode(color: .white, size: CGSize(width: 2000, height: 1200))
    private var pools: [ObjectIdentifier: [String: SKSpriteNode]] = [:]
    private var labels: [String: SKLabelNode] = [:]
    private var mapLabels: [String: SKLabelNode] = [:]
    private var mapLabelShadows: [String: SKLabelNode] = [:]
    private var playing: [String: [String]] = [:]

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.839, alpha: 1)   // paper
        addChild(staticLayer)
        addChild(dynamicLayer)
        addChild(overlayLayer)
        addChild(cameraNode)
        camera = cameraNode
        tintNode.blendMode = .multiply
        tintNode.zPosition = CGFloat(Layer.tint)
        cameraNode.addChild(tintNode)
    }

    required init?(coder: NSCoder) {
        fatalError("WorldScene is created in code")
    }

    convenience init(store: GameStore) {
        self.init(size: CGSize(width: Camera.viewWidth, height: Camera.viewHeight))
        self.store = store
        atlas = Atlas(manifest: store.atlas)
    }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 60
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if let view { store?.mapping = ViewMapping(width: Double(view.bounds.width), height: Double(view.bounds.height)) }
    }

    // MARK: Frame

    override func update(_ currentTime: TimeInterval) {
        guard let store, let atlas, let session = store.session else { return }
        if let view { store.mapping = ViewMapping(width: Double(view.bounds.width), height: Double(view.bounds.height)) }
        store.frame(now: currentTime)
        let world = session.world
        let time = store.renderTime

        if store.staticDirty {
            apply(store.builder.staticLayer(world), to: staticLayer, atlas: atlas)
            store.staticDirty = false
        }
        apply(store.builder.dynamicLayer(world, time: time), to: dynamicLayer, atlas: atlas)
        if let hud = store.hud {
            apply(store.builder.overlayLayer(world, input: store.input, hud: hud, time: time), to: overlayLayer, atlas: atlas)
        }

        applyRateLabels(store.input.showRates ? store.builder.rateLabels(world) : [])
        applyMapLabels(store.builder.mapLabels(world))

        cameraNode.position = CGPoint(x: store.camera.center.x, y: store.camera.center.y)
        cameraNode.setScale(CGFloat(1 / store.camera.zoom))
        let m = DayNight(tick: world.tick).tint.multiplier
        tintNode.color = UIColor(red: CGFloat(m.r), green: CGFloat(m.g), blue: CGFloat(m.b), alpha: 1)

        for effect in store.takeEffects() { play(effect, atlas: atlas) }
    }

    /// Makes `layer`'s children match `sprites`, reusing a node per sprite id.
    private func apply(_ sprites: [Sprite], to layer: SKNode, atlas: Atlas) {
        let key = ObjectIdentifier(layer)
        var pool = pools[key] ?? [:]
        var seen = Set<String>()
        for sprite in sprites {
            seen.insert(sprite.id)
            let node: SKSpriteNode
            if let existing = pool[sprite.id] {
                node = existing
            } else {
                node = SKSpriteNode(texture: atlas.texture(sprite.name))
                layer.addChild(node)
                pool[sprite.id] = node
            }
            configure(node, sprite, atlas: atlas)
        }
        for (id, node) in pool where !seen.contains(id) {
            node.removeFromParent()
            pool[id] = nil
            playing[id] = nil
        }
        pools[key] = pool
    }

    private func configure(_ node: SKSpriteNode, _ sprite: Sprite, atlas: Atlas) {
        if sprite.frames.count > 1 {
            if playing[sprite.id] != sprite.frames {
                node.removeAction(forKey: "frames")
                let textures = sprite.frames.map { atlas.texture($0) }
                let loop = SKAction.repeatForever(.animate(with: textures, timePerFrame: sprite.frameSeconds))
                let offset = sprite.phase.truncatingRemainder(dividingBy: sprite.frameSeconds * Double(sprite.frames.count))
                node.run(.sequence([.wait(forDuration: offset), loop]), withKey: "frames")
                playing[sprite.id] = sprite.frames
            }
        } else {
            if playing[sprite.id] != nil {
                node.removeAction(forKey: "frames")
                playing[sprite.id] = nil
            }
            let texture = atlas.texture(sprite.name)
            if node.texture !== texture { node.texture = texture }
        }
        if let texture = node.texture { node.size = texture.size() }
        node.position = CGPoint(x: sprite.x, y: sprite.y)
        node.zPosition = CGFloat(sprite.z)
        if node.action(forKey: "bounce") == nil {
            node.xScale = CGFloat(sprite.flipX ? -sprite.scale : sprite.scale)
            node.yScale = CGFloat(sprite.flipY ? -sprite.scale : sprite.scale)
        }
        node.alpha = CGFloat(sprite.alpha)
        node.color = UIColor(red: CGFloat(sprite.tint.r), green: CGFloat(sprite.tint.g), blue: CGFloat(sprite.tint.b), alpha: 1)
        node.colorBlendFactor = CGFloat(sprite.tint.amount)
    }

    /// Small text under buildings while the rates view is on. One label node
    /// per building, reused, with the warning line in brick red.
    private func applyRateLabels(_ rateLabels: [RateLabel]) {
        var seen = Set<String>()
        for label in rateLabels {
            seen.insert(label.id)
            let node: SKLabelNode
            if let existing = labels[label.id] {
                node = existing
            } else {
                node = SKLabelNode(fontNamed: "Menlo-Bold")
                node.fontSize = 6
                node.numberOfLines = 0
                node.verticalAlignmentMode = .top
                node.zPosition = CGFloat(Layer.overlay)
                overlayLayer.addChild(node)
                labels[label.id] = node
            }
            let warning = label.warning.map { "\n" + $0 } ?? ""
            node.text = label.lines.joined(separator: "\n") + warning
            node.fontColor = label.warning == nil
                ? UIColor(red: 1.0, green: 0.957, blue: 0.839, alpha: 1)
                : UIColor(red: 1.0, green: 0.541, blue: 0.239, alpha: 1)
            node.position = CGPoint(x: label.x, y: label.y)
        }
        for (id, node) in labels where !seen.contains(id) {
            node.removeFromParent()
            labels[id] = nil
        }
    }

    /// Landmark names written on the map, light text over a dark shadow so
    /// they read on grass and water alike.
    private func applyMapLabels(_ items: [MapLabel]) {
        var seen = Set<String>()
        for item in items {
            seen.insert(item.id)
            let node: SKLabelNode
            if let existing = mapLabels[item.id] {
                node = existing
            } else {
                node = SKLabelNode(fontNamed: "Menlo-Bold")
                node.fontSize = 7
                node.verticalAlignmentMode = .center
                node.fontColor = UIColor(red: 1.0, green: 0.957, blue: 0.839, alpha: 1)
                node.zPosition = CGFloat(Layer.overlay)
                let shadow = SKLabelNode(fontNamed: "Menlo-Bold")
                shadow.fontSize = 7
                shadow.verticalAlignmentMode = .center
                shadow.fontColor = UIColor(red: 0.102, green: 0.110, blue: 0.173, alpha: 0.8)
                shadow.position = CGPoint(x: 1, y: -1)
                shadow.zPosition = -1
                node.addChild(shadow)
                overlayLayer.addChild(node)
                mapLabels[item.id] = node
                mapLabelShadows[item.id] = shadow
            }
            node.text = item.text
            mapLabelShadows[item.id]?.text = item.text
            node.position = CGPoint(x: item.x, y: item.y)
        }
        for (id, node) in mapLabels where !seen.contains(id) {
            node.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
            mapLabels[id] = nil
            mapLabelShadows[id] = nil
        }
    }

    // MARK: Effects

    private func node(for id: EntityID) -> SKSpriteNode? {
        pools[ObjectIdentifier(dynamicLayer)]?["b:\(id)"]
    }

    private func play(_ effect: Effect, atlas: Atlas) {
        switch effect {
        case let .placed(id, at):
            // A small bounce and a dust puff.
            if let node = node(for: id) {
                node.setScale(0.6)
                let bounce = SKAction.sequence([.scale(to: 1.15, duration: 0.09), .scale(to: 1.0, duration: 0.08)])
                node.run(bounce, withKey: "bounce")
            }
            puff(at: at, atlas: atlas)
        case let .removed(at):
            puff(at: at, atlas: atlas)
        case let .squash(id):
            if let node = node(for: id), node.action(forKey: "bounce") == nil {
                let squash = SKAction.sequence([.scaleX(to: 1.08, y: 0.92, duration: 0.05), .scale(to: 1.0, duration: 0.07)])
                node.run(squash, withKey: "bounce")
            }
        case let .floatText(text, at):
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = text
            label.fontSize = 7
            label.fontColor = UIColor(red: 1.0, green: 0.957, blue: 0.839, alpha: 1)
            label.position = CGPoint(x: at.x, y: at.y + 14)
            label.zPosition = CGFloat(Layer.effects + 1)
            overlayLayer.addChild(label)
            label.run(.sequence([.group([.moveBy(x: 0, y: 14, duration: 0.9), .fadeOut(withDuration: 0.9)]),
                                 .removeFromParent()]))
        case let .nameTag(_, name, description, at):
            let tag = SKLabelNode(fontNamed: "Menlo-Bold")
            tag.text = name + "\n" + description
            tag.numberOfLines = 0
            tag.fontSize = 6
            tag.verticalAlignmentMode = .bottom
            tag.fontColor = UIColor(red: 1.0, green: 0.957, blue: 0.839, alpha: 1)
            tag.position = CGPoint(x: at.x, y: at.y + 18)
            tag.zPosition = CGFloat(Layer.effects + 1)
            overlayLayer.addChild(tag)
            tag.run(.sequence([.wait(forDuration: EffectPlanner.nameTagSeconds - 1), .fadeOut(withDuration: 1),
                               .removeFromParent()]))
        case .celebrate:
            // A warm light sweep across the view.
            let flash = SKSpriteNode(color: UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1),
                                     size: CGSize(width: Camera.viewWidth * 3, height: Camera.viewHeight * 3))
            flash.alpha = 0
            flash.zPosition = CGFloat(Layer.effects + 2)
            cameraNode.addChild(flash)
            flash.run(.sequence([.fadeAlpha(to: 0.45, duration: 0.25), .fadeOut(withDuration: 1.2), .removeFromParent()]))
        case .haptic, .sound, .musicLayers:
            break   // handled by the store's Feel
        }
    }

    private func puff(at point: ScenePoint, atlas: Atlas) {
        let frames = ["fx_pop_1", "fx_pop_2", "fx_pop_3"].map { atlas.texture($0) }
        let puff = SKSpriteNode(texture: frames[0])
        puff.position = CGPoint(x: point.x, y: point.y - 6)
        puff.zPosition = CGFloat(Layer.effects)
        overlayLayer.addChild(puff)
        puff.run(.sequence([.animate(with: frames, timePerFrame: 0.07), .removeFromParent()]))
    }

    // MARK: Touches

    private func viewPoint(_ touch: UITouch) -> ViewPoint? {
        guard let view else { return nil }
        let p = touch.location(in: view)
        return ViewPoint(Double(p.x), Double(p.y))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let p = viewPoint(touch) { store?.touchBegan(ObjectIdentifier(touch).hashValue, p, time: touch.timestamp) }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let p = viewPoint(touch) { store?.touchMoved(ObjectIdentifier(touch).hashValue, p, time: touch.timestamp) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let p = viewPoint(touch) { store?.touchEnded(ObjectIdentifier(touch).hashValue, p, time: touch.timestamp) }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { store?.touchCancelled(ObjectIdentifier(touch).hashValue) }
    }
}
