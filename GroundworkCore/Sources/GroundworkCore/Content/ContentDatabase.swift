import Foundation

public enum ContentError: Error, Equatable, CustomStringConvertible {
    case unreadable(file: String, reason: String)
    case invalid([String])

    public var description: String {
        switch self {
        case let .unreadable(file, reason): return "Could not read \(file): \(reason)"
        case let .invalid(problems): return "Invalid content:\n- " + problems.joined(separator: "\n- ")
        }
    }
}

/// All game content: items, sources, buildings, recipes, rules and the map legend.
///
/// Every list is kept sorted by ID, so anything that walks the content walks it
/// in the same order on every run.
public struct ContentDatabase: Sendable {
    public let items: [ItemDef]
    public let sources: [SourceDef]
    public let buildings: [BuildingDef]
    public let recipes: [RecipeDef]
    public let rules: GameRules
    public let levels: [LevelDef]
    /// Guided steps, keyed by the name a level refers to.
    public let tutorials: [String: [TutorialStep]]
    /// Map texts, keyed by file name relative to Data/.
    public let maps: [String: String]
    /// Map characters, keyed by a one-character string.
    public let legend: [String: LegendEntry]

    private let itemIndex: [ItemID: Int]
    private let sourceIndex: [SourceID: Int]
    private let buildingIndex: [BuildingTypeID: Int]
    private let recipeIndex: [RecipeID: Int]

    /// Builds a database and validates it. Throws `ContentError.invalid` listing every problem.
    public init(items: [ItemDef], sources: [SourceDef], buildings: [BuildingDef],
                recipes: [RecipeDef], rules: GameRules, legend: [String: LegendEntry],
                levels: [LevelDef] = [], tutorials: [String: [TutorialStep]] = [:],
                maps: [String: String] = [:]) throws {
        self.items = items.sorted { $0.id < $1.id }
        self.sources = sources.sorted { $0.id < $1.id }
        self.buildings = buildings.sorted { $0.id < $1.id }
        self.recipes = recipes.sorted { $0.id < $1.id }
        self.rules = rules
        self.legend = legend
        self.levels = levels
        self.tutorials = tutorials
        self.maps = maps
        itemIndex = Self.index(self.items.map(\.id))
        sourceIndex = Self.index(self.sources.map(\.id))
        buildingIndex = Self.index(self.buildings.map(\.id))
        recipeIndex = Self.index(self.recipes.map(\.id))

        let problems = validate()
        if !problems.isEmpty { throw ContentError.invalid(problems) }
    }

    /// Loads items, sources, buildings, recipes, rules, the map legend, levels,
    /// tutorials and every map a level uses, all from Data/.
    public static func load(from dataDirectory: URL) throws -> ContentDatabase {
        let levels: [LevelDef] = try decode("levels.json", in: dataDirectory)
        var maps: [String: String] = [:]
        for file in Set(levels.map(\.map)).sorted() {
            do {
                maps[file] = try String(contentsOf: dataDirectory.appendingPathComponent(file), encoding: .utf8)
            } catch {
                throw ContentError.unreadable(file: file, reason: String(describing: error))
            }
        }
        return try ContentDatabase(
            items: decode("items.json", in: dataDirectory),
            sources: decode("sources.json", in: dataDirectory),
            buildings: decode("buildings.json", in: dataDirectory),
            recipes: decode("recipes.json", in: dataDirectory),
            rules: decode("rules.json", in: dataDirectory),
            legend: decode("maps/legend.json", in: dataDirectory),
            levels: levels,
            tutorials: decode("tutorial.json", in: dataDirectory),
            maps: maps
        )
    }

    // MARK: Lookups

    public func item(_ id: ItemID) -> ItemDef? { itemIndex[id].map { items[$0] } }
    public func source(_ id: SourceID) -> SourceDef? { sourceIndex[id].map { sources[$0] } }
    public func building(_ id: BuildingTypeID) -> BuildingDef? { buildingIndex[id].map { buildings[$0] } }
    public func recipe(_ id: RecipeID) -> RecipeDef? { recipeIndex[id].map { recipes[$0] } }
    public func level(_ id: LevelID) -> LevelDef? { levels.first { $0.id == id } }

    /// The parsed map for a level.
    public func map(for level: LevelDef) throws -> TileMap {
        guard let text = maps[level.map] else {
            throw ContentError.unreadable(file: level.map, reason: "not loaded")
        }
        return try TileMap.parse(text, content: self)
    }

    /// "Waiting for logs" reads better than "Waiting for log".
    public func plural(_ id: ItemID) -> String { item(id)?.plural ?? id.rawValue }
    public func name(_ id: BuildingTypeID) -> String { building(id)?.name ?? id.rawValue }

    /// Recipes that output the item, in ID order.
    public func recipes(producing item: ItemID) -> [RecipeDef] {
        recipes.filter { recipe in recipe.outputs.contains { $0.item == item } }
    }

    // MARK: Validation

    private func validate() -> [String] {
        var problems: [String] = []

        problems += Self.duplicates(items.map(\.id), kind: "item")
        problems += Self.duplicates(sources.map(\.id), kind: "source")
        problems += Self.duplicates(buildings.map(\.id), kind: "building")
        problems += Self.duplicates(recipes.map(\.id), kind: "recipe")

        for source in sources {
            if item(source.item) == nil {
                problems.append("Source '\(source.id)' gives unknown item '\(source.item)'")
            }
            if let amount = source.startingAmount, amount <= 0 {
                problems.append("Source '\(source.id)' must start with more than 0")
            }
            if source.regrowPerMinute < 0 {
                problems.append("Source '\(source.id)' has a negative regrow rate")
            }
        }

        for recipe in recipes {
            let name = "Recipe '\(recipe.id)'"
            if building(recipe.building) == nil {
                problems.append("\(name) uses unknown building '\(recipe.building)'")
            }
            if recipe.durationTicks <= 0 {
                problems.append("\(name) must take at least 1 tick")
            }
            if recipe.power < 0 {
                problems.append("\(name) has negative power use")
            }
            if recipe.outputs.isEmpty {
                problems.append("\(name) has no outputs")
            }
            if let sourceID = recipe.source {
                if let source = source(sourceID) {
                    if !recipe.outputs.contains(where: { $0.item == source.item }) {
                        problems.append("\(name) takes from '\(sourceID)' but does not output '\(source.item)'")
                    }
                } else {
                    problems.append("\(name) takes from unknown source '\(sourceID)'")
                }
                if !recipe.inputs.isEmpty {
                    problems.append("\(name) gathers from a source, so it cannot also have inputs")
                }
            } else if recipe.inputs.isEmpty {
                problems.append("\(name) has no inputs and no source, so its output would appear from nothing")
            }
            for input in recipe.inputs {
                if item(input.item) == nil { problems.append("\(name) needs unknown item '\(input.item)'") }
                if input.count <= 0 { problems.append("\(name) needs a count above 0 of '\(input.item)'") }
            }
            for output in recipe.outputs {
                if item(output.item) == nil { problems.append("\(name) makes unknown item '\(output.item)'") }
                if output.count <= 0 { problems.append("\(name) makes a count above 0 of '\(output.item)'") }
            }
        }

        for building in buildings {
            let name = "Building '\(building.id)'"
            if building.size.count != 2 || building.size.contains(where: { $0 <= 0 }) {
                problems.append("\(name) needs a size of [width, height] above 0")
            }
            if building.inputCapacity < 0 || building.outputCapacity < 0 {
                problems.append("\(name) has a negative capacity")
            }
            for recipeID in building.recipes {
                if let recipe = recipe(recipeID) {
                    if recipe.building != building.id {
                        problems.append("\(name) lists recipe '\(recipeID)', which belongs to '\(recipe.building)'")
                    }
                } else {
                    problems.append("\(name) lists unknown recipe '\(recipeID)'")
                }
            }
            for stack in building.cost where item(stack.item) == nil {
                problems.append("\(name) costs unknown item '\(stack.item)'")
            }
            for accepted in building.accepts where item(accepted) == nil {
                problems.append("\(name) accepts unknown item '\(accepted)'")
            }
            if let built = building.builds {
                if self.building(built) == nil {
                    problems.append("\(name) builds unknown building '\(built)'")
                }
                if (building.buildTicks ?? 0) <= 0 {
                    problems.append("\(name) builds '\(built)' so it needs buildTicks above 0")
                }
            }
            if building.placeOn == .source && !building.recipes.contains(where: { recipe($0)?.source != nil }) {
                problems.append("\(name) must be placed on a source but has no gathering recipe")
            }
        }

        for key in legend.keys.sorted() {
            let entry = legend[key]!
            if key.count != 1 {
                problems.append("Map legend key '\(key)' must be a single character")
            }
            if let sourceID = entry.source, source(sourceID) == nil {
                problems.append("Map legend '\(key)' names unknown source '\(sourceID)'")
            }
        }

        problems += rules.problems()
        problems += traceRuleProblems()
        problems += Self.duplicates(levels.map(\.id), kind: "level")
        for level in levels { problems += levelProblems(level) }
        return problems
    }

    /// The Trace Rule: every item must trace back to a natural source.
    /// Marks items gathered from sources, then items whose every input is
    /// already marked, until nothing changes. Anything left unmarked can never
    /// be made, which also catches cycles such as a → b → a with no source.
    private func traceRuleProblems() -> [String] {
        var reachable = Set<ItemID>()
        var changed = true
        while changed {
            changed = false
            for recipe in recipes {
                let canRun = recipe.source.map { source($0) != nil }
                    ?? (!recipe.inputs.isEmpty && recipe.inputs.allSatisfy { reachable.contains($0.item) })
                guard canRun else { continue }
                for output in recipe.outputs where !reachable.contains(output.item) {
                    reachable.insert(output.item)
                    changed = true
                }
            }
        }
        return items
            .filter { !reachable.contains($0.id) }
            .map { "Item '\($0.id)' cannot be traced back to a natural source" }
    }

    private func levelProblems(_ level: LevelDef) -> [String] {
        let name = "Level '\(level.id)'"
        var problems: [String] = []
        for type in level.unlocked where building(type) == nil {
            problems.append("\(name) unlocks unknown building '\(type)'")
        }
        for stock in level.firstPlacementStock {
            if building(stock.building) == nil { problems.append("\(name) stocks unknown building '\(stock.building)'") }
            if item(stock.item) == nil { problems.append("\(name) stocks unknown item '\(stock.item)'") }
        }
        let goal = level.goal
        if goal.count <= 0 { problems.append("\(name) goal needs a count above 0") }
        switch goal.kind {
        case .deliver:
            if goal.item.flatMap(item) == nil { problems.append("\(name) goal delivers an unknown item") }
            if goal.to.flatMap(building) == nil { problems.append("\(name) goal delivers to an unknown building") }
        case .build:
            if goal.building.flatMap(building) == nil { problems.append("\(name) goal builds an unknown building") }
        }

        if let key = level.tutorial {
            if let steps = tutorials[key] {
                for step in steps { problems += stepProblems(step, in: name) }
            } else {
                problems.append("\(name) uses unknown tutorial '\(key)'")
            }
        }

        let map: TileMap
        do {
            map = try self.map(for: level)
        } catch {
            problems.append("\(name) map: \(error)")
            return problems
        }
        if !map.contains(level.focus) { problems.append("\(name) camera focus is off the map") }
        var world = World(map: map, seed: 0)
        for item in level.preplaced {
            guard let def = building(item.building) else {
                problems.append("\(name) preplaces unknown building '\(item.building)'")
                continue
            }
            if let problem = Commands.placementProblem(def, at: item.at, world: world, content: self) {
                problems.append("\(name) cannot preplace \(def.name) at \(item.at): \(problem.message)")
            } else {
                Commands.insertBuilding(item.building, at: item.at, facing: .south, world: &world, content: self)
            }
        }
        return problems
    }

    /// Tutorial text is at most two short lines, and every condition must make sense.
    private func stepProblems(_ step: TutorialStep, in levelName: String) -> [String] {
        let name = "\(levelName) step '\(step.id)'"
        var problems: [String] = []
        let lines = step.text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > 2 || lines.contains(where: { $0.count > Self.maxTutorialLineLength }) {
            problems.append("\(name) text must be at most 2 lines of \(Self.maxTutorialLineLength) characters")
        }
        guard let condition = TutorialCondition(step.when) else {
            return problems + ["\(name) has an unreadable condition '\(step.when)'"]
        }
        switch condition {
        case let .placed(type):
            if building(type) == nil { problems.append("\(name) waits for unknown building '\(type)'") }
        case let .produced(id), let .waiting(id):
            if item(id) == nil { problems.append("\(name) waits for unknown item '\(id)'") }
        case let .delivered(id, qualifier):
            if item(id) == nil { problems.append("\(name) waits for unknown item '\(id)'") }
            if let qualifier, qualifier != "hand", qualifier != "belt",
               building(BuildingTypeID(rawValue: qualifier)) == nil {
                problems.append("\(name) has an unknown delivery qualifier '\(qualifier)'")
            }
        case let .traced(type), let .count(type, _), let .slow(type):
            if building(type) == nil { problems.append("\(name) waits for unknown building '\(type)'") }
        case .ui, .goal:
            break
        case .wait:
            if (step.waitTicks ?? 0) <= 0 { problems.append("\(name) uses 'wait' so it needs waitTicks above 0") }
        }
        if step.pauseSim == true, (step.waitTicks ?? 0) > 0 {
            problems.append("\(name) pauses time, so its waitTicks could never pass")
        }
        for type in step.grant?.unlock ?? [] where building(type) == nil {
            problems.append("\(name) unlocks unknown building '\(type)'")
        }
        return problems
    }

    public static let maxTutorialLineLength = 48

    // MARK: Helpers

    private static func index<ID: Hashable>(_ ids: [ID]) -> [ID: Int] {
        var index: [ID: Int] = [:]
        for (offset, id) in ids.enumerated() where index[id] == nil { index[id] = offset }
        return index
    }

    private static func duplicates<ID: StringID>(_ ids: [ID], kind: String) -> [String] {
        var seen = Set<ID>()
        var reported = Set<ID>()
        var problems: [String] = []
        for id in ids where !seen.insert(id).inserted && reported.insert(id).inserted {
            problems.append("Duplicate \(kind) id '\(id)'")
        }
        return problems
    }

    private static func decode<T: Decodable>(_ file: String, in directory: URL) throws -> T {
        let url = directory.appendingPathComponent(file)
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw ContentError.unreadable(file: file, reason: String(describing: error))
        }
    }
}
