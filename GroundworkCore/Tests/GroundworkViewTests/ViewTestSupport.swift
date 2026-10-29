import Foundation
import XCTest
import GroundworkCore
@testable import GroundworkView

enum ViewTestSupport {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()

    static func content() throws -> ContentDatabase {
        try ContentDatabase.load(from: root.appendingPathComponent("Data"))
    }

    static func atlas() throws -> AtlasManifest {
        try AtlasManifest.load(from: root.appendingPathComponent("Art/generated/atlas.json"))
    }

    static func builder() throws -> SceneBuilder {
        SceneBuilder(content: try content(), atlas: try atlas())
    }

    static func session(_ rows: [String]) throws -> GameSession {
        let content = try content()
        return GameSession(content: content, map: try TileMap.parse(rows.joined(separator: "\n"), content: content), seed: 1)
    }

    /// The Level 3 town from the preview: two pits, two camps, kiln, sawmill, yard, belts.
    static func town(ticks: Int) throws -> GameSession {
        let town = try GameSession(content: try content(), seed: 3, chapter: 2)
        var input = InputController()
        for (type, x, y) in [("clay_pit", 36, 30), ("clay_pit", 37, 31), ("lumber_camp", 42, 23),
                             ("lumber_camp", 44, 23), ("brick_kiln", 41, 28), ("sawmill", 47, 25),
                             ("builders_yard", 51, 28)] {
            input.use(.build(BuildingTypeID(rawValue: type)))
            XCTAssertNil(input.tap(GridPoint(x, y), session: town).toast, "place \(type)")
        }
        input.use(.belt)
        for (a, b) in [((36, 30), (41, 28)), ((37, 31), (41, 28)), ((42, 23), (41, 28)),
                       ((44, 23), (47, 25)), ((41, 28), (51, 28)), ((47, 25), (51, 28))] {
            input.dragBegan(GridPoint(a.0, a.1), session: town)
            XCTAssertNil(input.dragEnded(GridPoint(b.0, b.1), session: town).toast, "belt \(a) to \(b)")
        }
        town.advance(ticks: ticks)
        return town
    }
}
