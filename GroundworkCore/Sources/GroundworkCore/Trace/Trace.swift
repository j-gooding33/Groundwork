public enum TraceTarget: Equatable, Sendable {
    case item(ItemID)
    case building(EntityID)
}

public enum TraceState: String, Codable, Sendable {
    case running, slow, blocked, notBuilt

    /// Higher is healthier. Used to pick the state of an item made by several buildings.
    var health: Int {
        switch self {
        case .running: return 3
        case .slow: return 2
        case .blocked: return 1
        case .notBuilt: return 0
        }
    }
}

public struct TraceNode: Equatable, Sendable {
    public enum Subject: Equatable, Sendable {
        case item(ItemID)
        case building(EntityID, BuildingTypeID)
        /// A step in the chain with nothing built for it yet.
        case missingBuilding(BuildingTypeID)
        case source(SourceID)
    }

    public var subject: Subject
    public var label: String
    public var state: TraceState
    public var reason: String
    public var children: [TraceNode]
    /// The child that causes this step's problem, when it is known
    /// (a kiln waiting for logs blames its log child).
    public var blame: Int?

    public init(subject: Subject, label: String, state: TraceState, reason: String,
                children: [TraceNode], blame: Int? = nil) {
        self.subject = subject
        self.label = label
        self.state = state
        self.reason = reason
        self.children = children
        self.blame = blame
    }

    /// The placed building this node stands for, if any.
    public var entity: EntityID? {
        if case let .building(id, _) = subject { return id }
        return nil
    }
}

public struct TraceResult: Equatable, Sendable {
    /// The whole chain, from the target back to natural sources.
    public var root: TraceNode
    /// From the root down to the first broken step. Empty when everything runs.
    public var brokenPath: [TraceNode]

    public var firstBroken: TraceNode? { brokenPath.last }

    /// The building to centre the camera on: the broken step itself, or the
    /// nearest building above it in the chain.
    public var jumpTarget: EntityID? { brokenPath.reversed().lazy.compactMap(\.entity).first }

    /// Every node, depth first. Handy for drawing the gold and red lines.
    public var allNodes: [TraceNode] {
        var result: [TraceNode] = []
        func walk(_ node: TraceNode) {
            result.append(node)
            node.children.forEach(walk)
        }
        walk(root)
        return result
    }
}

/// Trace: a pure function from the world to the chain behind an item or a
/// building, with a state and a plain-English reason for every step.
public enum Trace {
    public static func run(_ target: TraceTarget, world: World, content: ContentDatabase) -> TraceResult {
        var tracer = Tracer(world: world, content: content)
        let root: TraceNode
        switch target {
        case let .item(item):
            root = tracer.item(item, consumer: nil)
        case let .building(id):
            if let building = world.building(id) {
                root = tracer.building(building)
            } else {
                root = TraceNode(subject: .building(id, "unknown"), label: "Gone", state: .blocked,
                                 reason: "That building no longer exists", children: [])
            }
        }
        return TraceResult(root: root, brokenPath: brokenPath(from: root))
    }

    /// Walks down from the root to the first step that is itself the problem:
    /// follows the blamed child where one is known, otherwise the first
    /// unhealthy child, and stops at a building that has not been built yet,
    /// since that is what the player has to do next.
    static func brokenPath(from root: TraceNode) -> [TraceNode] {
        guard root.state != .running else { return [] }
        var path = [root]
        var node = root
        while !isMissingBuilding(node) {
            let next: TraceNode?
            if let blame = node.blame, node.children.indices.contains(blame), node.children[blame].state != .running {
                next = node.children[blame]
            } else {
                next = node.children.first { $0.state != .running }
            }
            guard let next else { break }
            path.append(next)
            node = next
        }
        return path
    }

    private static func isMissingBuilding(_ node: TraceNode) -> Bool {
        if case .missingBuilding = node.subject { return true }
        return false
    }
}

private struct Tracer {
    let world: World
    let content: ContentDatabase
    var visitedBuildings = Set<EntityID>()
    var visitedRecipes = Set<RecipeID>()

    init(world: World, content: ContentDatabase) {
        self.world = world
        self.content = content
    }

    private var rules: GameRules { content.rules }
    private var tick: UInt64 { world.tick }

    // MARK: Items

    mutating func item(_ item: ItemID, consumer: Building?) -> TraceNode {
        let label = content.item(item)?.name ?? item.rawValue
        let plural = content.plural(item)
        let producers = world.buildings.filter { building in
            building.isBuilt && !visitedBuildings.contains(building.id) && makes(building, item)
        }

        if producers.isEmpty {
            let recipes = content.recipes(producing: item)
            guard let first = recipes.first else {
                return TraceNode(subject: .item(item), label: label, state: .blocked,
                                 reason: "Nothing can make \(plural)", children: [])
            }
            let children = recipes.map { recipeStep($0) }
            return TraceNode(subject: .item(item), label: label, state: .notBuilt,
                             reason: "No \(content.name(first.building)) built yet", children: children)
        }

        let children = producers.map { building($0) }
        let state = children.map(\.state).max { $0.health < $1.health } ?? .blocked
        var reason: String
        switch state {
        case .running, .slow:
            let perMinute = producers.reduce(0) { $0 + $1.rates.perMinute(.made, item, tick: tick, rules: rules) }
            reason = perMinute > 0 ? "Made at \(perMinute) per minute" : "Being made"
        case .blocked, .notBuilt:
            reason = producers.count == 1
                ? "\(content.name(producers[0].type)) output is 0 per minute"
                : "No \(plural) being made"
        }

        // Made somewhere, but no belt brings it to the building waiting for it.
        if let consumer, case let .blocked(blockReason) = consumer.status, blockReason.waitsFor(item) {
            let feeders = BeltSystem.feeders(of: consumer, in: world, content: content)
            if !producers.contains(where: { feeders.contains($0.id) }) {
                let maker = content.name(producers[0].type)
                return TraceNode(subject: .item(item), label: label, state: .blocked,
                                 reason: "No belt brings \(plural) from the \(maker) to the \(content.name(consumer.type))",
                                 children: children)
            }
        }
        return TraceNode(subject: .item(item), label: label, state: state, reason: reason, children: children)
    }

    private func makes(_ building: Building, _ item: ItemID) -> Bool {
        guard let def = content.building(building.type) else { return false }
        return def.recipes.contains { content.recipe($0)?.outputs.contains { $0.item == item } ?? false }
    }

    /// A recipe with nothing built for it: show what to build and what it would need.
    private mutating func recipeStep(_ recipe: RecipeDef) -> TraceNode {
        let name = content.name(recipe.building)
        var children: [TraceNode] = []
        if !visitedRecipes.contains(recipe.id) {
            visitedRecipes.insert(recipe.id)
            if let source = recipe.source {
                children = [sourceNode(source, at: nil)]
            } else {
                children = uniqueInputs(recipe).map { item($0, consumer: nil) }
            }
            visitedRecipes.remove(recipe.id)
        }
        return TraceNode(subject: .missingBuilding(recipe.building), label: name, state: .notBuilt,
                         reason: "Build a \(name)", children: children)
    }

    // MARK: Buildings

    mutating func building(_ building: Building) -> TraceNode {
        let type = building.type
        let name = content.name(type)
        guard let def = content.building(type) else {
            return TraceNode(subject: .building(building.id, type), label: name, state: .blocked,
                             reason: "Unknown building", children: [])
        }
        visitedBuildings.insert(building.id)
        defer { visitedBuildings.remove(building.id) }

        let recipe = def.recipes.first.flatMap(content.recipe)
        var children: [TraceNode] = []
        switch def.kind {
        case .gatherer:
            if let source = recipe?.source { children = [sourceNode(source, at: building.origin)] }
        case .processor:
            if let recipe { children = uniqueInputs(recipe).map { item($0, consumer: building) } }
        case .construction, .yard:
            children = def.accepts.map { item($0, consumer: building) }
        case .home:
            children = def.cost.map { item($0.item, consumer: nil) }
        case .storage:
            break
        }

        let (state, reason, blamed) = condition(of: building, def: def, recipe: recipe)
        let blame = blamed.flatMap { item in children.firstIndex { $0.subject == .item(item) } }
        return TraceNode(subject: .building(building.id, type), label: name, state: state,
                         reason: reason, children: children, blame: blame)
    }

    /// The building's state, its reason, and the input to blame, if any.
    private func condition(of building: Building, def: BuildingDef,
                           recipe: RecipeDef?) -> (TraceState, String, ItemID?) {
        switch building.status {
        case let .blocked(reason):
            return (.blocked, reason.text(content), reason.waitingItem)
        case .constructing:
            return (.running, "Being built", nil)
        case .complete:
            return (.running, def.kind == .home ? "Built" : "Complete", nil)
        case .idle where def.kind == .gatherer || def.kind == .processor:
            if let reason = building.waitReason { return (.blocked, reason.text(content), reason.waitingItem) }
            return (.running, "Starting up", nil)
        case .idle:
            switch def.kind {
            case .storage:
                return (.running, building.input.isEmpty ? "Empty" : "Holding \(building.input.total) items", nil)
            case .construction:
                return (.running, "Has \(building.input.total) of \(def.inputCapacity)", nil)
            case .yard:
                return (.running, building.job != nil ? "Building a home" : "Waiting for steady supply", nil)
            default:
                return (.running, "Idle", nil)
            }
        case .running:
            guard let recipe else { return (.running, "Working", nil) }
            if let (item, text) = slowInput(building, recipe: recipe) { return (.slow, text, item) }
            guard let output = recipe.outputs.first else { return (.running, "Working", nil) }
            let perMinute = building.rates.perMinute(.made, output.item, tick: tick, rules: rules)
            return (.running, perMinute > 0
                ? "Making \(perMinute) \(content.plural(output.item)) per minute"
                : "Producing as expected", nil)
        }
    }

    /// An input arriving more slowly than the recipe uses it, while the
    /// building runs below full speed. Judged once it has run for a full rate
    /// window. A machine with a full input buffer receives less than it "needs"
    /// only because it has no room, so full speed rules that out.
    private func slowInput(_ building: Building, recipe: RecipeDef) -> (ItemID, String)? {
        guard tick >= building.placedAtTick + UInt64(rules.rateWindowTicks),
              let output = recipe.outputs.first else { return nil }
        let fullSpeed = output.count * Simulation.ticksPerMinute / recipe.durationTicks
        let made = building.rates.perMinute(.made, output.item, tick: tick, rules: rules)
        guard made * 10 < fullSpeed * 9 else { return nil }
        for input in recipe.inputs {
            let needed = input.count * Simulation.ticksPerMinute / recipe.durationTicks
            let arriving = building.rates.perMinute(.received, input.item, tick: tick, rules: rules)
            if arriving < needed {
                let what = content.item(input.item)?.name ?? input.item.rawValue
                return (input.item, "\(what) delivery is too slow (\(arriving) of \(needed) per minute)")
            }
        }
        return nil
    }

    // MARK: Sources

    private func sourceNode(_ id: SourceID, at point: GridPoint?) -> TraceNode {
        let source = content.source(id)
        let label = source?.name ?? id.rawValue
        let lower = label.lowercased()
        if let point {
            guard let deposit = world.map.deposit(at: point), deposit.source == id else {
                return TraceNode(subject: .source(id), label: label, state: .blocked,
                                 reason: "There is no \(lower) here", children: [])
            }
            if let remaining = deposit.remaining {
                return remaining > 0
                    ? TraceNode(subject: .source(id), label: label, state: .running,
                                reason: "\(remaining) left here", children: [])
                    : TraceNode(subject: .source(id), label: label, state: .blocked,
                                reason: "The \(lower) here is used up", children: [])
            }
            return TraceNode(subject: .source(id), label: label, state: .running, reason: "Never runs out", children: [])
        }
        let left = world.map.deposits.contains { $0.source == id && ($0.remaining ?? 1) > 0 }
        return TraceNode(subject: .source(id), label: label, state: left ? .running : .blocked,
                         reason: left ? "Found in nature" : "No \(lower) left on this map", children: [])
    }

    private func uniqueInputs(_ recipe: RecipeDef) -> [ItemID] {
        var seen = Set<ItemID>()
        return recipe.inputs.map(\.item).filter { seen.insert($0).inserted }
    }
}

extension BlockReason {
    /// The item a machine is waiting for, if that is why it is blocked.
    var waitingItem: ItemID? {
        switch self {
        case let .missingInput(item), let .missingFuel(item): return item
        default: return nil
        }
    }

    func waitsFor(_ item: ItemID) -> Bool { waitingItem == item }
}
