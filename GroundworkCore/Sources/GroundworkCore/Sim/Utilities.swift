/// Water held in one tower. Saved with the world.
public struct StoredWater: Codable, Equatable, Sendable {
    public var tower: EntityID
    public var amount: Int
}

/// Power and water: the services buildings need beyond their inputs.
///
/// Power is mechanical: a finished waterwheel drives a few machines within
/// a short distance, nearest first in id order. Water flows from powered
/// pumps through pipes; towers store it and serve homes around them, and
/// wells serve homes nearby without pipes. Integer maths only.
enum Utilities {
    /// A construction site works once it has everything; anything else once built.
    static func isWorking(_ building: Building, _ def: BuildingDef, rules: GameRules) -> Bool {
        def.kind == .construction ? Production.remainingCapacity(of: building, def: def, rules: rules) == 0 : building.isBuilt
    }

    static func powerNeed(_ def: BuildingDef, content: ContentDatabase) -> Int {
        max(def.powerUse ?? 0, def.recipes.compactMap { content.recipe($0)?.power }.max() ?? 0)
    }

    /// Distance between two buildings' footprints, in tiles (the larger of the x and y gaps).
    static func gap(_ a: Building, _ ad: BuildingDef, _ b: Building, _ bd: BuildingDef) -> Int {
        let dx = max(0, max(a.origin.x - (b.origin.x + bd.width - 1), b.origin.x - (a.origin.x + ad.width - 1)))
        let dy = max(0, max(a.origin.y - (b.origin.y + bd.height - 1), b.origin.y - (a.origin.y + ad.height - 1)))
        return max(dx, dy)
    }

    // MARK: Power

    static func updatePower(_ world: inout World, content: ContentDatabase) {
        var supply: [(index: Int, left: Int, radius: Int)] = []
        for (i, b) in world.buildings.enumerated() {
            guard let def = content.building(b.type), let out = def.powerOutput, out > 0,
                  isWorking(b, def, rules: content.rules) else { continue }
            supply.append((i, out, def.powerRadius ?? 0))
        }
        var powered: [EntityID] = []
        for b in world.buildings {
            guard let def = content.building(b.type) else { continue }
            let need = powerNeed(def, content: content)
            guard need > 0, isWorking(b, def, rules: content.rules) else { continue }
            for k in supply.indices where supply[k].left >= need {
                let wheel = world.buildings[supply[k].index]
                guard let wheelDef = content.building(wheel.type),
                      gap(b, def, wheel, wheelDef) <= supply[k].radius else { continue }
                supply[k].left -= need
                powered.append(b.id)
                break
            }
        }
        world.powered = powered
    }

    // MARK: Water

    /// Connected pipe networks: each pipe tile gets a network number.
    static func networks(_ world: World) -> [GridPoint: Int] {
        var label: [GridPoint: Int] = [:]
        var next = 0
        for start in world.pipes where label[start] == nil {
            var stack = [start]
            label[start] = next
            while let p = stack.popLast() {
                for d in Direction.allCases {
                    let n = p.moved(d)
                    if world.index.hasPipe(n), label[n] == nil { label[n] = next; stack.append(n) }
                }
            }
            next += 1
        }
        return label
    }

    /// The pipe network a building touches, if any (the lowest-numbered one).
    static func network(of b: Building, _ def: BuildingDef, labels: [GridPoint: Int]) -> Int? {
        var found: Int?
        for p in b.footprint(def) {
            for d in Direction.allCases {
                if let n = labels[p.moved(d)] { found = min(found ?? n, n) }
            }
        }
        return found
    }

    static func updateWater(_ world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        let rules = content.rules
        // Rates are per minute; this runs once per rate bucket.
        let share = { (perMinute: Int) in perMinute * rules.rateBucketTicks / Simulation.ticksPerMinute }
        let labels = networks(world)
        var budget: [Int: Int] = [:]
        var towers: [(index: Int, network: Int?, radius: Int, capacity: Int)] = []
        var wells: [(index: Int, left: Int, radius: Int)] = []
        let powered = Set(world.powered)

        for (i, b) in world.buildings.enumerated() {
            guard let def = content.building(b.type), isWorking(b, def, rules: rules) else { continue }
            let net = network(of: b, def, labels: labels)
            if let out = def.waterOutput, def.waterRadius == nil {
                // A pump: needs power and a pipe.
                if let net, powerNeed(def, content: content) == 0 || powered.contains(b.id) {
                    budget[net, default: 0] += share(out)
                }
            } else if let out = def.waterOutput, let radius = def.waterRadius {
                wells.append((i, share(out), radius))
            }
            if let capacity = def.waterStorage {
                towers.append((i, net, def.waterRadius ?? 0, capacity))
                if let net { budget[net, default: 0] += world.waterStored.first { $0.tower == b.id }?.amount ?? 0 }
            }
        }

        var watered: [EntityID] = []
        for b in world.buildings {
            guard let def = content.building(b.type), let use = def.waterUse, b.isBuilt else { continue }
            let need = share(use)
            var served = false
            // Piped straight to the door...
            if let net = network(of: b, def, labels: labels), budget[net, default: 0] >= need {
                budget[net, default: 0] -= need
                served = true
            }
            // ...or from a tower nearby on a network with water...
            if !served {
                for tower in towers {
                    guard let net = tower.network, budget[net, default: 0] >= need else { continue }
                    let t = world.buildings[tower.index]
                    guard let td = content.building(t.type), gap(b, def, t, td) <= tower.radius else { continue }
                    budget[net, default: 0] -= need
                    served = true
                    break
                }
            }
            // ...or from a well close by.
            if !served {
                for k in wells.indices where wells[k].left >= need {
                    let w = world.buildings[wells[k].index]
                    guard let wd = content.building(w.type), gap(b, def, w, wd) <= wells[k].radius else { continue }
                    wells[k].left -= need
                    served = true
                    break
                }
            }
            if served { watered.append(b.id) }
        }

        // What is left fills the towers, in id order.
        var stored: [StoredWater] = []
        for tower in towers {
            guard let net = tower.network else { continue }
            let amount = min(tower.capacity, budget[net, default: 0])
            budget[net, default: 0] -= amount
            stored.append(StoredWater(tower: world.buildings[tower.index].id, amount: amount))
        }
        world.waterStored = stored

        let before = Set(world.watered), after = Set(watered)
        for id in after.subtracting(before).sorted() { events.append(.waterChanged(id, true)) }
        for id in before.subtracting(after).sorted() { events.append(.waterChanged(id, false)) }
        world.watered = watered
    }

    // MARK: Pipes

    static func planPipe(from: GridPoint, to: GridPoint, world: World) -> [GridPoint]? {
        func passable(_ p: GridPoint) -> Bool {
            guard let terrain = world.map.terrain(at: p), !terrain.isWater, world.isRevealed(p) else { return false }
            return world.building(at: p) == nil
        }
        return Roads.plan(from: from, to: to, world: world, passable: passable, existing: world.index.hasPipe)
    }

    static func layPipe(from: GridPoint, to: GridPoint, world: inout World,
                        content: ContentDatabase) -> Result<[GridPoint], CommandError> {
        guard let path = planPipe(from: from, to: to, world: world) else {
            return .failure(.noRoute("No clear path for a pipe"))
        }
        let new = path.filter { !world.index.hasPipe($0) }
        guard !new.isEmpty else { return .failure(.blocked("There is a pipe here already")) }
        world.pipes = (world.pipes + new).sorted()
        world.index = WorldIndex(world: world, content: content)
        return .success(new)
    }

    static func removePipes(_ points: [GridPoint], world: inout World, content: ContentDatabase) -> [GridPoint] {
        let wanted = Set(points)
        let removed = world.pipes.filter { wanted.contains($0) }
        guard !removed.isEmpty else { return [] }
        world.pipes.removeAll { wanted.contains($0) }
        world.index = WorldIndex(world: world, content: content)
        return removed
    }
}

extension World {
    public func hasPipe(_ point: GridPoint) -> Bool { index.hasPipe(point) }
    public func isPowered(_ id: EntityID) -> Bool { powered.contains(id) }
    public func hasWater(_ id: EntityID) -> Bool { watered.contains(id) }
    /// Tiles between two buildings' footprints (0 when they touch).
    public func tilesBetween(_ a: Building, _ b: Building, content: ContentDatabase) -> Int {
        guard let ad = content.building(a.type), let bd = content.building(b.type) else { return Int.max }
        return Utilities.gap(a, ad, b, bd)
    }

    public func storedWater(_ id: EntityID) -> Int { waterStored.first { $0.tower == id }?.amount ?? 0 }
}
