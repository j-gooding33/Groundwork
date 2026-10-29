public enum Terrain: String, Codable, CaseIterable, Sendable {
    case grass, grassLight, grassDark, water, shore, dirt, clayGround, forest, rock

    public var isWater: Bool { self == .water }
}

/// What is left of a natural source on one tile.
public struct SourceDeposit: Codable, Equatable, Sendable {
    public var point: GridPoint
    public var source: SourceID
    /// Nil means the source never runs out.
    public var remaining: Int?
}

public enum MapError: Error, Equatable, CustomStringConvertible {
    case empty
    case raggedRow(row: Int, width: Int, expected: Int)
    case unknownCharacter(Character, row: Int, column: Int)
    case unknownSource(SourceID)

    public var description: String {
        switch self {
        case .empty:
            return "The map is empty"
        case let .raggedRow(row, width, expected):
            return "Map row \(row) is \(width) tiles wide, expected \(expected)"
        case let .unknownCharacter(character, row, column):
            return "Map character '\(character)' at row \(row), column \(column) is not in the legend"
        case let .unknownSource(source):
            return "The legend names unknown source '\(source)'"
        }
    }
}

/// The ground: terrain for every tile, plus what is left in each natural source.
public struct TileMap: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Row-major terrain, `width * height` long.
    public private(set) var terrain: [Terrain]
    /// Deposits sorted by point, at most one per tile.
    public private(set) var deposits: [SourceDeposit]

    /// Parses a text map: one line per row, one legend character per tile.
    /// Deposits start with the amount their source defines.
    public static func parse(_ text: String, content: ContentDatabase) throws -> TileMap {
        let rows = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.hasSuffix("\r") ? $0.dropLast() : $0 }
            .reversed().drop(while: \.isEmpty).reversed()
        guard let first = rows.first, !first.isEmpty else { throw MapError.empty }

        let width = first.count
        var terrain: [Terrain] = []
        var deposits: [SourceDeposit] = []
        terrain.reserveCapacity(width * rows.count)

        for (y, row) in rows.enumerated() {
            guard row.count == width else {
                throw MapError.raggedRow(row: y, width: row.count, expected: width)
            }
            for (x, character) in row.enumerated() {
                guard let entry = content.legend[String(character)] else {
                    throw MapError.unknownCharacter(character, row: y, column: x)
                }
                terrain.append(entry.terrain)
                if let sourceID = entry.source {
                    guard let source = content.source(sourceID) else { throw MapError.unknownSource(sourceID) }
                    deposits.append(SourceDeposit(point: GridPoint(x, y), source: sourceID,
                                                  remaining: source.startingAmount))
                }
            }
        }
        return TileMap(width: width, height: rows.count, terrain: terrain, deposits: deposits)
    }

    public init(width: Int, height: Int, terrain: [Terrain], deposits: [SourceDeposit] = []) {
        precondition(width > 0 && height > 0 && terrain.count == width * height,
                     "Terrain must have width * height tiles")
        self.width = width
        self.height = height
        self.terrain = terrain
        self.deposits = deposits.sorted { $0.point < $1.point }
    }

    public func contains(_ point: GridPoint) -> Bool {
        point.x >= 0 && point.y >= 0 && point.x < width && point.y < height
    }

    /// Terrain at a point, or nil outside the map.
    public func terrain(at point: GridPoint) -> Terrain? {
        contains(point) ? terrain[point.y * width + point.x] : nil
    }

    public func deposit(at point: GridPoint) -> SourceDeposit? {
        depositIndex(at: point).map { deposits[$0] }
    }

    /// Binary search over the sorted deposits.
    func depositIndex(at point: GridPoint) -> Int? {
        var low = 0
        var high = deposits.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let candidate = deposits[mid].point
            if candidate == point { return mid }
            if candidate < point { low = mid + 1 } else { high = mid - 1 }
        }
        return nil
    }
}
