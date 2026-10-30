/// A truck that runs one fixed route: load at its source, drive the road to
/// its destination, unload, drive back. Saved with the world.
public struct Truck: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable {
        /// At the source, waiting for something the destination takes.
        case loading
        case outbound
        /// At the destination, waiting for room.
        case unloading
        case returning
    }

    public let id: EntityID
    /// Where it loads: any building with something to take (a depot, a kiln, a crate).
    public let source: EntityID
    /// Where it unloads.
    public let target: EntityID
    /// Road tiles from beside the source to beside the target. Empty while no road joins them.
    public internal(set) var path: [GridPoint] = []
    /// Index into `path` of the tile it is on.
    public internal(set) var position = 0
    /// Ticks spent on the current tile, for smooth drawing between tiles.
    public internal(set) var progress = 0
    public internal(set) var phase = Phase.loading
    public internal(set) var cargo: ItemStack?

    /// The tile it stands on, if it has a road to stand on.
    public var tile: GridPoint? { path.indices.contains(position) ? path[position] : nil }
}

/// Roads and the trucks on them. Roads are laid by dragging, like belts, and
/// join wherever they meet; trucks find their own way along them.
enum Roads {
    // MARK: Laying

    /// The cheapest route over free land (or existing road) between two tiles,
    /// straight runs preferred. The same drag always gives the same road.
    static func plan(from: GridPoint, to: GridPoint, world: World) -> [GridPoint]? {
        plan(from: from, to: to, world: world, passable: { world.isFree($0) || world.hasRoad($0) },
             existing: world.hasRoad)
    }

    /// The same search for any network laid by dragging: `passable` says where
    /// it may go, `existing` where it already is (cheaper, so new joins old).
    static func plan(from start: GridPoint, to end: GridPoint, world: World, passable: (GridPoint) -> Bool,
                     existing: (GridPoint) -> Bool) -> [GridPoint]? {
        // Dragging from (or to) a building means the tile beside it nearest the other end.
        func endpoint(_ p: GridPoint, toward q: GridPoint) -> GridPoint {
            guard !passable(p), let b = world.building(at: p) else { return p }
            func distance(_ n: GridPoint) -> Int { abs(n.x - q.x) + abs(n.y - q.y) }
            var best: GridPoint?
            for tile in world.footprintTiles(of: b) {
                for n in Direction.allCases.map({ tile.moved($0) }) where passable(n) && world.building(at: n)?.id != b.id {
                    if let current = best, (distance(current), current) <= (distance(n), n) { continue }
                    best = n
                }
            }
            return best ?? p
        }
        let from = endpoint(start, toward: end)
        let to = endpoint(end, toward: from)
        guard passable(from), passable(to) else { return nil }
        let w = world.map.width, h = world.map.height
        let directions = Direction.allCases
        // Dijkstra over (tile, heading) with a small cost per turn.
        let states = w * h * directions.count
        var cost = [Int](repeating: Int.max, count: states)
        var previous = [Int](repeating: -1, count: states)
        var frontier = MinHeap()
        func state(_ p: GridPoint, _ d: Int) -> Int { (p.y * w + p.x) * directions.count + d }
        for d in directions.indices {
            let s = state(from, d)
            cost[s] = 0
            frontier.push(0, s)
        }
        var goal: Int?
        while let (c, s) = frontier.pop() {
            guard c == cost[s] else { continue }
            let cell = s / directions.count, heading = s % directions.count
            let p = GridPoint(cell % w, cell / w)
            if p == to { goal = s; break }
            for (d, direction) in directions.enumerated() {
                let n = p.moved(direction)
                guard n.x >= 0, n.y >= 0, n.x < w, n.y < h, passable(n) else { continue }
                // Existing road is cheaper, so new roads join old ones.
                let step = (existing(n) ? 6 : 10) + (d == heading || p == from ? 0 : 4)
                let ns = state(n, d)
                if c + step < cost[ns] {
                    cost[ns] = c + step
                    previous[ns] = s
                    frontier.push(c + step, ns)
                }
            }
        }
        guard var s = goal else { return nil }
        var path: [GridPoint] = []
        while s >= 0 {
            let cell = s / directions.count
            path.append(GridPoint(cell % w, cell / w))
            s = previous[s]
        }
        return path.reversed()
    }

    /// Lays road along a planned route. Returns the tiles that are new.
    static func lay(from: GridPoint, to: GridPoint, world: inout World,
                    content: ContentDatabase) -> Result<[GridPoint], CommandError> {
        guard let path = plan(from: from, to: to, world: world) else {
            return .failure(.noRoute("No clear path for a road"))
        }
        let new = path.filter { !world.hasRoad($0) }
        guard !new.isEmpty else { return .failure(.blocked("There is road here already")) }
        world.roads = (world.roads + new).sorted()
        world.index = WorldIndex(world: world, content: content)
        rerouteTrucks(&world, content: content)
        return .success(new)
    }

    static func remove(_ points: [GridPoint], world: inout World, content: ContentDatabase) -> [GridPoint] {
        let wanted = Set(points)
        let removed = world.roads.filter { wanted.contains($0) }
        guard !removed.isEmpty else { return [] }
        world.roads.removeAll { wanted.contains($0) }
        world.index = WorldIndex(world: world, content: content)
        rerouteTrucks(&world, content: content)
        return removed
    }

    // MARK: Routes

    /// Road tiles touching a building's footprint.
    static func entrances(of building: Building, world: World, content: ContentDatabase) -> [GridPoint] {
        guard let def = content.building(building.type) else { return [] }
        var found = Set<GridPoint>()
        for p in building.footprint(def) {
            for d in Direction.allCases where world.hasRoad(p.moved(d)) { found.insert(p.moved(d)) }
        }
        return found.sorted()
    }

    /// The shortest drive along road from one building to another, or nil.
    static func route(from source: Building, to target: Building, world: World, content: ContentDatabase) -> [GridPoint]? {
        let starts = entrances(of: source, world: world, content: content)
        let goals = Set(entrances(of: target, world: world, content: content))
        guard !starts.isEmpty, !goals.isEmpty else { return nil }
        var previous: [GridPoint: GridPoint] = [:]
        var queue = starts
        var seen = Set(starts)
        var head = 0
        while head < queue.count {
            let p = queue[head]
            head += 1
            if goals.contains(p) {
                var path = [p]
                var at = p
                while let back = previous[at] { path.append(back); at = back }
                return path.reversed()
            }
            for d in Direction.allCases {
                let n = p.moved(d)
                guard world.hasRoad(n), !seen.contains(n) else { continue }
                seen.insert(n)
                previous[n] = p
                queue.append(n)
            }
        }
        return nil
    }

    /// Sets up a truck between two buildings. A second tap on the same pair
    /// takes the truck away again.
    static func setRoute(from source: EntityID, to target: EntityID, world: inout World,
                         content: ContentDatabase) -> Result<EntityID, CommandError> {
        guard source != target else { return .failure(.blocked("A truck needs to go somewhere else")) }
        guard let from = world.building(source), let to = world.building(target),
              let fromDef = content.building(from.type), let toDef = content.building(to.type) else {
            return .failure(.blocked("Pick two buildings"))
        }
        guard Production.takeable(from, def: fromDef) != nil else {
            return .failure(.blocked("A truck can't load at a \(fromDef.name)"))
        }
        guard toDef.kind != .gatherer, toDef.kind != .home else {
            return .failure(.blocked("A \(toDef.name) doesn't take deliveries"))
        }
        guard !entrances(of: from, world: world, content: content).isEmpty else {
            return .failure(.noRoute("The \(fromDef.name) needs a road beside it"))
        }
        guard !entrances(of: to, world: world, content: content).isEmpty else {
            return .failure(.noRoute("The \(toDef.name) needs a road beside it"))
        }
        guard let path = route(from: from, to: to, world: world, content: content) else {
            return .failure(.noRoute("No road joins the \(fromDef.name) to the \(toDef.name)"))
        }
        let id = world.nextEntityID
        world.nextEntityID += 1
        var truck = Truck(id: id, source: source, target: target)
        truck.path = path
        world.trucks.append(truck)
        return .success(id)
    }

    /// After roads change, every truck finds its way again. One with no road
    /// left waits at its source, keeping its load.
    static func rerouteTrucks(_ world: inout World, content: ContentDatabase) {
        for i in world.trucks.indices {
            let truck = world.trucks[i]
            guard let from = world.building(truck.source), let to = world.building(truck.target) else { continue }
            let path = route(from: from, to: to, world: world, content: content) ?? []
            if path != truck.path {
                world.trucks[i].path = path
                world.trucks[i].position = truck.phase == .outbound || truck.phase == .unloading
                    ? min(truck.position, max(0, path.count - 1)) : 0
                if truck.phase == .returning { world.trucks[i].phase = .loading }
                world.trucks[i].progress = 0
            }
        }
    }

    // MARK: Driving

    static func step(_ world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        let rules = content.rules
        for i in world.trucks.indices {
            var truck = world.trucks[i]
            guard !truck.path.isEmpty,
                  let s = world.buildingIndex(truck.source), let t = world.buildingIndex(truck.target),
                  let sourceDef = content.building(world.buildings[s].type),
                  let targetDef = content.building(world.buildings[t].type) else { continue }
            switch truck.phase {
            case .loading:
                if truck.cargo == nil, let stock = Production.takeable(world.buildings[s], def: sourceDef) {
                    // Load the first thing the destination has room for.
                    for stack in stock.stacks {
                        let room = Production.room(for: stack.item, in: world.buildings[t], def: targetDef, content: content)
                        guard room > 0 else { continue }
                        let taken = Production.take(stack.item, min(rules.truckCapacity, room, stack.count), from: s,
                                                    world: &world, def: sourceDef)
                        if taken > 0 { truck.cargo = ItemStack(item: stack.item, count: taken) }
                        break
                    }
                }
                if truck.cargo != nil {
                    truck.phase = .outbound
                    truck.position = 0
                    truck.progress = 0
                }
            case .outbound, .returning:
                truck.progress += 1
                if truck.progress >= rules.truckTicksPerTile {
                    truck.progress = 0
                    if truck.phase == .outbound {
                        if truck.position + 1 < truck.path.count { truck.position += 1 } else { truck.phase = .unloading }
                    } else {
                        if truck.position > 0 { truck.position -= 1 } else { truck.phase = .loading }
                    }
                }
            case .unloading:
                if let cargo = truck.cargo {
                    let room = Production.room(for: cargo.item, in: world.buildings[t], def: targetDef, content: content)
                    let n = min(room, cargo.count)
                    if n > 0 {
                        Production.deliver(cargo.item, n, to: t, world: &world, content: content)
                        events.append(.itemDelivered(world.buildings[t].id, cargo.item, via: .truck))
                        truck.cargo = n == cargo.count ? nil : ItemStack(item: cargo.item, count: cargo.count - n)
                    }
                }
                // Drive back once empty; a full destination keeps the truck waiting.
                if truck.cargo == nil {
                    truck.phase = .returning
                    truck.progress = 0
                }
            }
            world.trucks[i] = truck
        }
    }

    /// Buildings whose goods reach `building` by truck.
    static func suppliers(of building: Building, in world: World) -> [EntityID] {
        world.trucks.filter { $0.target == building.id && !$0.path.isEmpty }.map(\.source)
    }
}

/// A binary heap of (cost, state), lowest first; ties go to the lower state,
/// so the same search always visits tiles in the same order.
struct MinHeap {
    private var items: [(Int, Int)] = []

    mutating func push(_ cost: Int, _ state: Int) {
        items.append((cost, state))
        var i = items.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            guard items[i] < items[parent] else { break }
            items.swapAt(i, parent)
            i = parent
        }
    }

    mutating func pop() -> (Int, Int)? {
        guard let first = items.first else { return nil }
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var i = 0
            while true {
                let l = 2 * i + 1, r = l + 1
                var smallest = i
                if l < items.count, items[l] < items[smallest] { smallest = l }
                if r < items.count, items[r] < items[smallest] { smallest = r }
                if smallest == i { break }
                items.swapAt(i, smallest)
                i = smallest
            }
        }
        return first
    }
}

extension World {
    public func hasRoad(_ point: GridPoint) -> Bool {
        if case .road = index.occupant(at: point) { return true }
        return false
    }

    public func truck(_ id: EntityID) -> Truck? { trucks.first { $0.id == id } }

    /// Every tile a building covers.
    func footprintTiles(of building: Building) -> [GridPoint] {
        var tiles: [GridPoint] = []
        for y in max(0, building.origin.y - 1)...min(map.height - 1, building.origin.y + 4) {
            for x in max(0, building.origin.x - 1)...min(map.width - 1, building.origin.x + 4) {
                let p = GridPoint(x, y)
                if self.building(at: p)?.id == building.id { tiles.append(p) }
            }
        }
        return tiles
    }
}
