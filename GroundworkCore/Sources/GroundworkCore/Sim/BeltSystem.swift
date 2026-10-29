/// Moves items along belts one slot at a time, takes them from the building a
/// belt starts at, and hands them to the building or belt a belt points into.
enum BeltSystem {
    static func step(_ world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        let rules = content.rules
        guard world.tick % UInt64(rules.beltTicksPerSlot) == 0 else { return }
        let last = rules.beltSlotsPerTile - 1

        // Downstream tiles come first, so a slot freed at the front of a line
        // is filled from behind in the same tick and the line moves as one.
        for i in world.belts.indices {
            let tile = world.belts[i]

            if let item = tile.slots[last], handOff(item, from: tile, world: &world, content: content, events: &events) {
                world.belts[i].slots[last] = nil
            }

            for slot in stride(from: last - 1, through: 0, by: -1)
            where world.belts[i].slots[slot] != nil && world.belts[i].slots[slot + 1] == nil {
                world.belts[i].slots[slot + 1] = world.belts[i].slots[slot]
                world.belts[i].slots[slot] = nil
            }

            if world.belts[i].slots[0] == nil, let sourceID = tile.pullsFrom,
               let b = world.buildingIndex(sourceID), let def = content.building(world.buildings[b].type),
               let item = Production.takeable(world.buildings[b], def: def)?.stacks.first?.item,
               Production.take(item, 1, from: b, world: &world, def: def) == 1 {
                world.belts[i].slots[0] = item
            }
        }
    }

    /// Passes the item at a tile's exit to whatever it points into. Returns true if it moved.
    private static func handOff(_ item: ItemID, from tile: BeltTile, world: inout World,
                                content: ContentDatabase, events: inout [GameEvent]) -> Bool {
        if let n = world.beltIndex(at: tile.next) {
            let next = world.belts[n]
            guard next.direction != tile.direction.opposite else { return false }
            // Straight on enters at the start; joining from the side enters mid-tile.
            let entry = next.direction == tile.direction ? 0 : next.slots.count / 2
            guard next.slots[entry] == nil else { return false }
            world.belts[n].slots[entry] = item
            return true
        }
        if case let .building(b)? = world.index.occupant(at: tile.next),
           let def = content.building(world.buildings[b].type),
           Production.room(for: item, in: world.buildings[b], def: def, content: content) > 0 {
            Production.deliver(item, 1, to: b, world: &world, content: content)
            events.append(.itemDelivered(world.buildings[b].id, item, via: .belt))
            return true
        }
        return false
    }

    /// The belt a tile feeds into, if any (head-on belts do not connect).
    static func downstream(of tile: BeltTile, in world: World) -> Int? {
        guard let n = world.beltIndex(at: tile.next), world.belts[n].direction != tile.direction.opposite else {
            return nil
        }
        return n
    }

    /// Sorts belts so each tile comes after the tile it feeds, then rebuilds
    /// the tile index. Loops go last, in point order.
    static func reorder(_ world: inout World, content: ContentDatabase) {
        world.index = WorldIndex(world: world, content: content)
        let count = world.belts.count
        let next = world.belts.map { downstream(of: $0, in: world) }
        let unknown = -1
        var depth = Array(repeating: unknown, count: count)

        for start in 0..<count where depth[start] == unknown {
            var path: [Int] = []
            var onPath = Set<Int>()
            var current: Int? = start
            var base = 0
            while let c = current {
                if depth[c] != unknown { base = depth[c] + 1; break }
                if onPath.contains(c) { base = count; break } // a loop
                path.append(c)
                onPath.insert(c)
                current = next[c]
            }
            for (offset, tile) in path.reversed().enumerated() {
                depth[tile] = base + offset
            }
        }

        let order = (0..<count).sorted {
            (depth[$0], world.belts[$0].point) < (depth[$1], world.belts[$1].point)
        }
        world.belts = order.map { world.belts[$0] }
        world.index = WorldIndex(world: world, content: content)
    }

    /// Buildings whose items reach `building` by belt, in id order.
    static func feeders(of building: Building, in world: World, content: ContentDatabase) -> [EntityID] {
        guard let def = content.building(building.type) else { return [] }
        var queue = world.belts.indices.filter { building.covers(world.belts[$0].next, def) }
        var seen = Set(queue)
        var found = Set<EntityID>()
        while let i = queue.popLast() {
            let tile = world.belts[i]
            if let source = tile.pullsFrom, source != building.id { found.insert(source) }
            for direction in Direction.allCases {
                guard let u = world.beltIndex(at: tile.point.moved(direction)), !seen.contains(u),
                      downstream(of: world.belts[u], in: world) == i else { continue }
                seen.insert(u)
                queue.append(u)
            }
        }
        return found.sorted()
    }
}

extension World {
    /// True if a belt tile leads nowhere: not into a building, not onto
    /// another belt it can join. Items pile up at its end.
    public func isDeadEnd(_ tile: BeltTile) -> Bool {
        building(at: tile.next) == nil && BeltSystem.downstream(of: tile, in: self) == nil
    }
}
