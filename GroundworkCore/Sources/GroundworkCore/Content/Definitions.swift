// Content definitions, decoded from the JSON files in Data/.
// These describe what can exist; World holds what does exist.

public enum ItemTier: String, Codable, Sendable {
    case raw, processed, component, assembly
}

public struct ItemDef: Codable, Equatable, Sendable {
    public var id: ItemID
    public var name: String
    /// Used in sentences such as "Waiting for logs".
    public var plural: String
    public var tier: ItemTier
}

/// A natural source found in the world: a clay deposit, a forest, a lake.
public struct SourceDef: Codable, Equatable, Sendable {
    public var id: SourceID
    public var name: String
    public var item: ItemID
    /// Amount held by each tile when the map loads. Nil means it never runs out.
    public var startingAmount: Int?
    public var regrowPerMinute: Int
}

public struct ItemStack: Codable, Equatable, Hashable, Sendable {
    public var item: ItemID
    public var count: Int

    public init(item: ItemID, count: Int) {
        self.item = item
        self.count = count
    }
}

public enum InputRole: String, Codable, Sendable {
    case material, fuel
}

public struct RecipeInput: Codable, Equatable, Sendable {
    public var item: ItemID
    public var count: Int
    public var role: InputRole
}

public struct RecipeDef: Codable, Equatable, Sendable {
    public var id: RecipeID
    public var building: BuildingTypeID
    /// Set for gathering recipes, which take from a natural source instead of inputs.
    public var source: SourceID?
    public var durationTicks: Int
    public var power: Int
    public var level: Int
    public var inputs: [RecipeInput]
    public var outputs: [ItemStack]
}

public enum BuildingKind: String, Codable, Sendable {
    case gatherer, processor, storage, construction, yard, home
}

public enum PlacementRule: String, Codable, Sendable {
    /// Must sit on a tile with a natural source its recipe takes from.
    case source
    /// Any tile that is not water.
    case land
}

public struct BuildingDef: Codable, Equatable, Sendable {
    public var id: BuildingTypeID
    public var name: String
    public var kind: BuildingKind
    /// Footprint in tiles, as [width, height].
    public var size: [Int]
    public var recipes: [RecipeID]
    public var inputCapacity: Int
    public var outputCapacity: Int
    public var cost: [ItemStack]
    /// Items taken in without a recipe, such as bricks for a foundation.
    /// Empty means a building accepts whatever its recipes need, or anything for storage.
    public var accepts: [ItemID]
    public var level: Int
    public var placeOn: PlacementRule
    /// For a yard: the building it constructs, and how long each one takes.
    public var builds: BuildingTypeID?
    public var buildTicks: Int?

    public var width: Int { size.first ?? 1 }
    public var height: Int { size.count > 1 ? size[1] : 1 }
}

/// One character of a map file.
public struct LegendEntry: Codable, Equatable, Sendable {
    public var terrain: Terrain
    public var source: SourceID?
}
