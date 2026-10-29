/// One tile of belt. Items sit in discrete slots; the last slot is the exit end.
public struct BeltTile: Codable, Equatable, Sendable {
    public let point: GridPoint
    public let direction: Direction
    public internal(set) var slots: [ItemID?]
    /// The building this tile takes items from: set on the first tile of a belt
    /// dragged out of a building.
    public let pullsFrom: EntityID?

    init(point: GridPoint, direction: Direction, slots: Int, pullsFrom: EntityID?) {
        self.point = point
        self.direction = direction
        self.slots = Array(repeating: nil, count: slots)
        self.pullsFrom = pullsFrom
    }

    /// The tile this one feeds.
    public var next: GridPoint { point.moved(direction) }

    public var items: [ItemID] { slots.compactMap { $0 } }
}
