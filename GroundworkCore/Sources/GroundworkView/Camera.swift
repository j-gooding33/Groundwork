import GroundworkCore

/// A point in scene space: pixels of world art, x to the east, y *up*
/// (SpriteKit's convention). Grid y grows south, so rows flip.
public struct ScenePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// Converts between grid tiles and scene points, and keeps the view on the map.
public struct Camera: Equatable, Sendable {
    public static let tile = 16.0
    /// The low-resolution view the world is drawn at, before scaling to the screen.
    public static let viewWidth = 480.0
    public static let viewHeight = 270.0

    public let mapWidth: Int
    public let mapHeight: Int
    public private(set) var center: ScenePoint
    /// 1 shows 480x270 points of world; 2 shows half that, magnified.
    public private(set) var zoom: Double

    public static let minZoom = 0.6
    public static let maxZoom = 3.0

    public init(mapWidth: Int, mapHeight: Int, focus: GridPoint? = nil, zoom: Double = 1) {
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.zoom = min(max(zoom, Self.minZoom), Self.maxZoom)
        center = Self.center(of: focus ?? GridPoint(mapWidth / 2, mapHeight / 2), w: 1, h: 1, mapHeight: mapHeight)
        clamp()
    }

    /// The scene point at the centre of a footprint whose top-left tile is `origin`.
    public static func center(of origin: GridPoint, w: Int, h: Int, mapHeight: Int) -> ScenePoint {
        ScenePoint((Double(origin.x) + Double(w) / 2) * tile,
                   (Double(mapHeight - origin.y) - Double(h) / 2) * tile)
    }

    public func center(of origin: GridPoint, w: Int = 1, h: Int = 1) -> ScenePoint {
        Self.center(of: origin, w: w, h: h, mapHeight: mapHeight)
    }

    /// The tile under a scene point. Points outside the map give tiles outside it too.
    public func tile(at point: ScenePoint) -> GridPoint {
        GridPoint(Int((point.x / Self.tile).rounded(.down)),
                  mapHeight - 1 - Int((point.y / Self.tile).rounded(.down)))
    }

    /// The scene point under a point in the view (0,0 bottom-left, 480x270).
    public func scenePoint(fromView v: ScenePoint) -> ScenePoint {
        ScenePoint(center.x + (v.x - Self.viewWidth / 2) / zoom,
                   center.y + (v.y - Self.viewHeight / 2) / zoom)
    }

    /// Visible scene rectangle: minX, minY, maxX, maxY.
    public var visible: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        let hw = Self.viewWidth / 2 / zoom, hh = Self.viewHeight / 2 / zoom
        return (center.x - hw, center.y - hh, center.x + hw, center.y + hh)
    }

    /// Moves the view by a drag measured in view points.
    public mutating func pan(byView dx: Double, _ dy: Double) {
        center.x -= dx / zoom
        center.y -= dy / zoom
        clamp()
    }

    /// Zooms by a pinch factor, keeping the point under the fingers still.
    public mutating func pinch(_ factor: Double, aroundView v: ScenePoint) {
        let before = scenePoint(fromView: v)
        zoom = min(max(zoom * factor, Self.minZoom), Self.maxZoom)
        let after = scenePoint(fromView: v)
        center.x += before.x - after.x
        center.y += before.y - after.y
        clamp()
    }

    public mutating func focus(on point: GridPoint) {
        center = center(of: point)
        clamp()
    }

    /// Keeps the map's edge (plus a little paper margin) inside the view.
    private mutating func clamp() {
        let margin = Self.tile * 2
        let hw = Self.viewWidth / 2 / zoom, hh = Self.viewHeight / 2 / zoom
        let w = Double(mapWidth) * Self.tile, h = Double(mapHeight) * Self.tile
        center.x = hw * 2 > w + margin * 2 ? w / 2 : min(max(center.x, hw - margin), w + margin - hw)
        center.y = hh * 2 > h + margin * 2 ? h / 2 : min(max(center.y, hh - margin), h + margin - hh)
    }
}
