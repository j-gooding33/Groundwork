/// A string-backed identifier that reads and writes as a bare JSON string.
///
/// Content IDs are kept as distinct types so an item ID can never be passed
/// where a building ID is expected.
public protocol StringID: RawRepresentable, Codable, Hashable, Comparable,
    ExpressibleByStringLiteral, CustomStringConvertible, Sendable where RawValue == String {
    init(rawValue: String)
}

extension StringID {
    public init(stringLiteral value: String) { self.init(rawValue: value) }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String { rawValue }
}

public struct ItemID: StringID {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct SourceID: StringID {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct BuildingTypeID: StringID {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct RecipeID: StringID {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}
