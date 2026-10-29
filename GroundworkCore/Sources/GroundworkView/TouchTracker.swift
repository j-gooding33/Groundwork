/// A point on the device screen, in UIKit points (y grows down).
public struct ViewPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

public enum Gesture: Equatable, Sendable {
    case tap(ViewPoint)
    case longPress(ViewPoint)
    /// One finger moving: the app lays a belt with these when the belt tool is
    /// active, and pans with `pan` otherwise.
    case dragBegan(ViewPoint)
    case dragMoved(ViewPoint)
    case dragEnded(ViewPoint)
    /// A drag that turned into a pinch: drop any half-laid belt.
    case dragCancelled
    case pan(dx: Double, dy: Double)
    /// Two fingers moving together: always moves the map, whatever the tool.
    case twoFingerPan(dx: Double, dy: Double)
    case pinch(factor: Double, center: ViewPoint)
}

/// Turns raw touches into gestures. Kept free of UIKit so it is tested on
/// Linux; the SpriteKit scene feeds it touches and acts on what comes out.
public struct TouchTracker: Sendable {
    /// Movement under this many points still counts as a tap.
    public static let tapSlop = 10.0
    public static let longPressSeconds = 0.45

    private enum Mode: Sendable { case idle, pending, dragging, pinching, finished }

    private struct Touch: Sendable {
        var start: ViewPoint
        var last: ViewPoint
        var startTime: Double
    }

    private var mode = Mode.idle
    private var touches: [Int: Touch] = [:]
    private var order: [Int] = []
    private var lastPinchDistance = 0.0
    private var lastPinchCenter = ViewPoint(0, 0)

    public init() {}

    public mutating func began(_ id: Int, _ p: ViewPoint, time: Double) -> [Gesture] {
        touches[id] = Touch(start: p, last: p, startTime: time)
        order.append(id)
        switch touches.count {
        case 1:
            mode = .pending
            return []
        case 2:
            let wasDragging = mode == .dragging
            mode = .pinching
            (lastPinchDistance, lastPinchCenter) = pinchState()
            return wasDragging ? [.dragCancelled] : []
        default:
            return []
        }
    }

    public mutating func moved(_ id: Int, _ p: ViewPoint, time: Double) -> [Gesture] {
        guard var touch = touches[id] else { return [] }
        let previous = touch.last
        touch.last = p
        touches[id] = touch
        switch mode {
        case .pending:
            guard distance(touch.start, p) > Self.tapSlop else { return [] }
            mode = .dragging
            return [.dragBegan(touch.start), .dragMoved(p), .pan(dx: p.x - touch.start.x, dy: p.y - touch.start.y)]
        case .dragging:
            return [.dragMoved(p), .pan(dx: p.x - previous.x, dy: p.y - previous.y)]
        case .pinching:
            guard touches.count >= 2 else { return [] }
            let (d, center) = pinchState()
            defer { (lastPinchDistance, lastPinchCenter) = (d, center) }
            var gestures: [Gesture] = []
            if lastPinchDistance > 0, d > 0 { gestures.append(.pinch(factor: d / lastPinchDistance, center: center)) }
            gestures.append(.twoFingerPan(dx: center.x - lastPinchCenter.x, dy: center.y - lastPinchCenter.y))
            return gestures
        case .idle, .finished:
            return []
        }
    }

    public mutating func ended(_ id: Int, _ p: ViewPoint, time: Double) -> [Gesture] {
        guard touches[id] != nil else { return [] }
        touches[id] = nil
        order.removeAll { $0 == id }
        var gestures: [Gesture] = []
        switch mode {
        case .pending: gestures = [.tap(p)]
        case .dragging: gestures = [.dragEnded(p)]
        default: break
        }
        mode = touches.isEmpty ? .idle : .finished
        return gestures
    }

    public mutating func cancelled(_ id: Int) -> [Gesture] {
        guard touches[id] != nil else { return [] }
        touches[id] = nil
        order.removeAll { $0 == id }
        let gestures: [Gesture] = mode == .dragging ? [.dragCancelled] : []
        mode = touches.isEmpty ? .idle : .finished
        return gestures
    }

    /// Call every frame: a finger held still becomes a long press.
    public mutating func update(time: Double) -> [Gesture] {
        guard mode == .pending, let id = order.first, let touch = touches[id],
              time - touch.startTime >= Self.longPressSeconds else { return [] }
        mode = .finished
        return [.longPress(touch.start)]
    }

    private func pinchState() -> (Double, ViewPoint) {
        guard order.count >= 2, let a = touches[order[0]]?.last, let b = touches[order[1]]?.last else {
            return (0, ViewPoint(0, 0))
        }
        return (distance(a, b), ViewPoint((a.x + b.x) / 2, (a.y + b.y) / 2))
    }

    private func distance(_ a: ViewPoint, _ b: ViewPoint) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }
}

/// Maps the device screen onto the 480x270 view the scene draws, which
/// SpriteKit scales up with aspect-fill (cropping the longer side).
public struct ViewMapping: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// Device points per scene point.
    public var scale: Double { max(width / Camera.viewWidth, height / Camera.viewHeight) }

    /// A screen point in the camera's 480x270 view, y up.
    public func toView(_ p: ViewPoint) -> ScenePoint {
        let s = scale
        let x = (p.x - (width - Camera.viewWidth * s) / 2) / s
        let y = (p.y - (height - Camera.viewHeight * s) / 2) / s
        return ScenePoint(x, Camera.viewHeight - y)
    }

    /// A screen drag in the camera's view units, y up.
    public func toView(dx: Double, dy: Double) -> (dx: Double, dy: Double) {
        (dx / scale, -dy / scale)
    }
}
