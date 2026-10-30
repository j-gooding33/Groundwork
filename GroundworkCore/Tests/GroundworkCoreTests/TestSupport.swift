import Foundation
import XCTest
@testable import GroundworkCore

enum TestSupport {
    /// The repo's Data/ folder, found relative to this file.
    static let dataDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // GroundworkCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // GroundworkCore
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("Data")

    static func content() throws -> ContentDatabase {
        try ContentDatabase.load(from: dataDirectory)
    }

    static func level1Map(_ content: ContentDatabase) throws -> TileMap {
        let text = try String(contentsOf: dataDirectory.appendingPathComponent("maps/level1.txt"), encoding: .utf8)
        return try TileMap.parse(text, content: content)
    }

    // MARK: Fixture content, small enough to read in a test

    static let clayItem = ItemDef(id: "clay", name: "Clay", plural: "clay", tier: .raw, description: "An item.")
    static let brickItem = ItemDef(id: "brick", name: "Brick", plural: "bricks", tier: .processed, description: "An item.")
    static let rules = GameRules(handCapacity: 10, beltSlotsPerTile: 4, beltTicksPerSlot: 2,
                                 rateBucketTicks: 60, rateBuckets: 10, blockGraceTicks: 20,
                                 truckCapacity: 10, truckTicksPerTile: 3, soilMax: 100, soilTired: 40)
    static let claySource = SourceDef(id: "clay_deposit", name: "Clay deposit", item: "clay",
                                      startingAmount: 40, regrowPerMinute: 0, description: "A source.")
    static let gatherClay = RecipeDef(id: "gather_clay", building: "clay_pit", source: "clay_deposit",
                                      durationTicks: 30, power: 0, level: 1, inputs: [],
                                      outputs: [ItemStack(item: "clay", count: 1)])
    static let fireBrick = RecipeDef(id: "brick", building: "kiln", source: nil, durationTicks: 50,
                                     power: 0, level: 1,
                                     inputs: [RecipeInput(item: "clay", count: 2, role: .material)],
                                     outputs: [ItemStack(item: "brick", count: 1)])

    static func building(_ id: BuildingTypeID, recipes: [RecipeID], placeOn: PlacementRule = .land) -> BuildingDef {
        BuildingDef(id: id, name: id.rawValue, description: "A building.", kind: .processor, size: [1, 1], recipes: recipes,
                    inputCapacity: 10, outputCapacity: 10, cost: [], accepts: [], level: 1, placeOn: placeOn)
    }

    static let legend: [String: LegendEntry] = [
        ".": LegendEntry(terrain: .grass, source: nil),
        "~": LegendEntry(terrain: .water, source: nil),
        "c": LegendEntry(terrain: .clayGround, source: "clay_deposit"),
    ]

    /// A valid two-recipe database. Tests copy and break one part of it.
    static func fixture(
        items: [ItemDef] = [clayItem, brickItem],
        sources: [SourceDef] = [claySource],
        buildings: [BuildingDef] = [building("clay_pit", recipes: ["gather_clay"], placeOn: .source),
                                    building("kiln", recipes: ["brick"])],
        recipes: [RecipeDef] = [gatherClay, fireBrick],
        rules: GameRules = rules,
        legend: [String: LegendEntry] = legend
    ) throws -> ContentDatabase {
        try ContentDatabase(items: items, sources: sources, buildings: buildings, recipes: recipes,
                            rules: rules, legend: legend)
    }

    // MARK: Small worlds on the real content

    /// A session on a small text map using the real content and legend.
    static func session(_ rows: [String], seed: UInt64 = 1) throws -> GameSession {
        let content = try content()
        return GameSession(content: content, map: try TileMap.parse(rows.joined(separator: "\n"), content: content),
                           seed: seed)
    }

    /// The id of the building whose footprint covers a point.
    static func id(at point: GridPoint, in session: GameSession) throws -> EntityID {
        try XCTUnwrap(session.world.building(at: point)?.id, "No building at \(point)")
    }

    /// Places a building and returns its id, failing the test if it is refused.
    @discardableResult
    static func place(_ type: BuildingTypeID, at point: GridPoint, in session: GameSession,
                      file: StaticString = #filePath, line: UInt = #line) throws -> EntityID {
        let result = session.place(type, at: point)
        XCTAssertEqual(result, .ok, "Placing \(type) at \(point)", file: file, line: line)
        return try id(at: point, in: session)
    }

    static func layBelt(from: GridPoint, to: GridPoint, in session: GameSession,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(session.layBelt(from: from, to: to), .ok, "Belt \(from) to \(to)", file: file, line: line)
    }
}

/// Asserts that building content fails and one of the problems mentions `text`.
func XCTAssertContentProblem(_ text: String, file: StaticString = #filePath, line: UInt = #line,
                             _ build: () throws -> ContentDatabase) {
    do {
        _ = try build()
        XCTFail("Expected a content problem mentioning '\(text)'", file: file, line: line)
    } catch let ContentError.invalid(problems) {
        XCTAssertTrue(problems.contains { $0.contains(text) },
                      "No problem mentions '\(text)': \(problems)", file: file, line: line)
    } catch {
        XCTFail("Unexpected error \(error)", file: file, line: line)
    }
}
