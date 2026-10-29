/// A tile position. x grows to the east, y grows to the south; (0, 0) is the north-west corner.
public struct GridPoint: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    public func moved(_ direction: Direction, by steps: Int = 1) -> GridPoint {
        let offset = direction.offset
        return GridPoint(x + offset.x * steps, y + offset.y * steps)
    }

    /// The four orthogonal neighbours, in `Direction.allCases` order.
    public var neighbours: [GridPoint] { Direction.allCases.map { moved($0) } }

    /// Row-major order, so sorted points read like a page.
    public static func < (lhs: GridPoint, rhs: GridPoint) -> Bool {
        (lhs.y, lhs.x) < (rhs.y, rhs.x)
    }

    public var description: String { "(\(x), \(y))" }
}

public enum Direction: String, Codable, CaseIterable, Sendable {
    case north, east, south, west

    public var offset: (x: Int, y: Int) {
        switch self {
        case .north: return (0, -1)
        case .east: return (1, 0)
        case .south: return (0, 1)
        case .west: return (-1, 0)
        }
    }

    public var opposite: Direction {
        switch self {
        case .north: return .south
        case .east: return .west
        case .south: return .north
        case .west: return .east
        }
    }

    public var turnedRight: Direction {
        switch self {
        case .north: return .east
        case .east: return .south
        case .south: return .west
        case .west: return .north
        }
    }

    public var turnedLeft: Direction { turnedRight.opposite }
}
