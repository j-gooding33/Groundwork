/// Everything that exists in a game, as one Codable value.
///
/// Saving a game is encoding this; loading is decoding it. The simulation
/// changes it only through `Simulation.step` and the commands in GameSession.
/// Nothing in here is a Dictionary, so the same world always encodes to the
/// same bytes.
public struct World: Codable, Equatable, Sendable {
    public internal(set) var tick: UInt64
    public internal(set) var rng: SplitMix64
    public internal(set) var map: TileMap
    public internal(set) var nextEntityID: EntityID
    /// Sorted by id.
    public internal(set) var buildings: [Building] = []
    /// In processing order: each tile comes after the tile it feeds, so a
    /// whole line of items moves together in one tick.
    public internal(set) var belts: [BeltTile] = []
    /// What the player is carrying.
    public internal(set) var hand: ItemStack?
    /// Belt tiles the player may still lay; nil means unlimited.
    public internal(set) var beltsAvailable: Int?
    /// Buildings the player may place; nil means all of them.
    public internal(set) var unlocked: [BuildingTypeID]?
    /// Where yards build homes, in order. Empty means the yard picks the nearest free spot.
    public internal(set) var housingPlots: [GridPoint] = []
    /// Progress through the current level, if playing one.
    public internal(set) var level: LevelState?
    /// Fun-test numbers: time to first belt, bottlenecks fixed.
    public internal(set) var funTest = FunTestLog()
    /// The land drawn so far; nil means the whole map. Nothing can be built
    /// on paper that has not been drawn yet.
    public internal(set) var revealed: Reveal?
    /// For a generated world: its name, seed and the choices it was made with.
    public internal(set) var options: WorldOptions?
    /// Where a generated world begins (the camera's first view).
    public internal(set) var start: GridPoint?
    /// Hints offered in a generated world's first hour.
    public internal(set) var hints: HintState?
    /// Goals after the tutorial, and in new worlds.
    public internal(set) var milestones: MilestoneState?

    /// Tile lookups, rebuilt from the fields above. Never saved.
    var index = WorldIndex()

    public init(map: TileMap, seed: UInt64) {
        tick = 0
        rng = SplitMix64(seed: seed)
        self.map = map
        nextEntityID = 1
    }

    private enum CodingKeys: String, CodingKey {
        case tick, rng, map, nextEntityID, buildings, belts, hand, beltsAvailable, unlocked, housingPlots, level, funTest, revealed, options, start, hints, milestones
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tick = try c.decode(UInt64.self, forKey: .tick)
        rng = try c.decode(SplitMix64.self, forKey: .rng)
        map = try c.decode(TileMap.self, forKey: .map)
        nextEntityID = try c.decode(EntityID.self, forKey: .nextEntityID)
        buildings = try c.decode([Building].self, forKey: .buildings)
        belts = try c.decode([BeltTile].self, forKey: .belts)
        hand = try c.decodeIfPresent(ItemStack.self, forKey: .hand)
        beltsAvailable = try c.decodeIfPresent(Int.self, forKey: .beltsAvailable)
        unlocked = try c.decodeIfPresent([BuildingTypeID].self, forKey: .unlocked)
        housingPlots = try c.decode([GridPoint].self, forKey: .housingPlots)
        level = try c.decodeIfPresent(LevelState.self, forKey: .level)
        funTest = try c.decodeIfPresent(FunTestLog.self, forKey: .funTest) ?? FunTestLog()
        revealed = try c.decodeIfPresent(Reveal.self, forKey: .revealed)
        options = try c.decodeIfPresent(WorldOptions.self, forKey: .options)
        start = try c.decodeIfPresent(GridPoint.self, forKey: .start)
        hints = try c.decodeIfPresent(HintState.self, forKey: .hints)
        milestones = try c.decodeIfPresent(MilestoneState.self, forKey: .milestones)
        // The index needs building sizes from content, so the session rebuilds it after loading.
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tick, forKey: .tick)
        try c.encode(rng, forKey: .rng)
        try c.encode(map, forKey: .map)
        try c.encode(nextEntityID, forKey: .nextEntityID)
        try c.encode(buildings, forKey: .buildings)
        try c.encode(belts, forKey: .belts)
        try c.encode(hand, forKey: .hand)
        try c.encode(beltsAvailable, forKey: .beltsAvailable)
        try c.encode(unlocked, forKey: .unlocked)
        try c.encode(housingPlots, forKey: .housingPlots)
        try c.encode(level, forKey: .level)
        try c.encode(funTest, forKey: .funTest)
        try c.encode(revealed, forKey: .revealed)
        try c.encodeIfPresent(options, forKey: .options)
        try c.encodeIfPresent(start, forKey: .start)
        try c.encodeIfPresent(hints, forKey: .hints)
        try c.encodeIfPresent(milestones, forKey: .milestones)
    }

    public static func == (lhs: World, rhs: World) -> Bool {
        lhs.tick == rhs.tick && lhs.rng == rhs.rng && lhs.map == rhs.map
            && lhs.nextEntityID == rhs.nextEntityID && lhs.buildings == rhs.buildings
            && lhs.belts == rhs.belts && lhs.hand == rhs.hand && lhs.beltsAvailable == rhs.beltsAvailable
            && lhs.unlocked == rhs.unlocked && lhs.housingPlots == rhs.housingPlots && lhs.level == rhs.level
            && lhs.funTest == rhs.funTest && lhs.revealed == rhs.revealed
            && lhs.options == rhs.options && lhs.start == rhs.start && lhs.hints == rhs.hints
            && lhs.milestones == rhs.milestones
    }

    // MARK: Lookups

    public func building(_ id: EntityID) -> Building? {
        buildingIndex(id).map { buildings[$0] }
    }

    public func building(at point: GridPoint) -> Building? {
        if case let .building(i) = index.occupant(at: point) { return buildings[i] }
        return nil
    }

    public func belt(at point: GridPoint) -> BeltTile? {
        if case let .belt(i) = index.occupant(at: point) { return belts[i] }
        return nil
    }

    public func isRevealed(_ point: GridPoint) -> Bool {
        revealed?.contains(point) ?? true
    }

    public func isFree(_ point: GridPoint) -> Bool {
        guard let terrain = map.terrain(at: point), !terrain.isWater, isRevealed(point) else { return false }
        return index.occupant(at: point) == nil
    }

    func buildingIndex(_ id: EntityID) -> Int? {
        var low = 0
        var high = buildings.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if buildings[mid].id == id { return mid }
            if buildings[mid].id < id { low = mid + 1 } else { high = mid - 1 }
        }
        return nil
    }

    func beltIndex(at point: GridPoint) -> Int? {
        if case let .belt(i) = index.occupant(at: point) { return i }
        return nil
    }
}

/// A circle of drawn land. Integer maths, so it is the same on every device.
public struct Reveal: Codable, Equatable, Sendable {
    public var center: GridPoint
    public var radius: Int

    public func contains(_ p: GridPoint) -> Bool {
        let dx = p.x - center.x, dy = p.y - center.y
        return dx * dx + dy * dy <= radius * radius
    }
}

/// What occupies each tile, as array indices into World's buildings and belts.
struct WorldIndex: Sendable {
    enum Occupant: Equatable, Sendable {
        case building(Int)
        case belt(Int)
    }

    private var width = 0
    private var height = 0
    private var cells: [Occupant?] = []

    func occupant(at point: GridPoint) -> Occupant? {
        guard point.x >= 0, point.y >= 0, point.x < width, point.y < height else { return nil }
        return cells[point.y * width + point.x]
    }

    init() {}

    init(world: World, content: ContentDatabase) {
        width = world.map.width
        height = world.map.height
        cells = Array(repeating: nil, count: width * height)
        for (i, belt) in world.belts.enumerated() where world.map.contains(belt.point) {
            cells[belt.point.y * width + belt.point.x] = .belt(i)
        }
        for (i, building) in world.buildings.enumerated() {
            guard let def = content.building(building.type) else { continue }
            for point in building.footprint(def) where world.map.contains(point) {
                cells[point.y * width + point.x] = .building(i)
            }
        }
    }
}
