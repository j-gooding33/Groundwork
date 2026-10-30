import XCTest
@testable import GroundworkCore

final class ContentLoadingTests: XCTestCase {
    func testRealContentLoadsWithoutProblems() throws {
        let content = try TestSupport.content()
        // The first chain is always there; later phases only add to it.
        XCTAssertTrue(Set(content.items.map(\.id)).isSuperset(of: ["brick", "clay", "log", "plank"]))
        XCTAssertNotNil(content.recipe("brick"))
        XCTAssertNotNil(content.source("clay_deposit"))
        XCTAssertNotNil(content.building("builders_yard"))
        XCTAssertEqual(content.items.map(\.id), content.items.map(\.id).sorted(), "Sorted by id")
    }

    func testEverythingHasAShortDescription() throws {
        let content = try TestSupport.content()
        let lines = content.items.map(\.description) + content.sources.map(\.description)
            + content.buildings.map(\.description)
        for line in lines {
            XCTAssertFalse(line.isEmpty)
            XCTAssertLessThanOrEqual(line.count, 60, "One short line fits the palette: \(line)")
        }
        XCTAssertEqual(content.building("brick_kiln")?.description, "Bakes clay into bricks. Burns logs as fuel.")
    }

    func testOneWorldWithChaptersThatOpenUpTheMap() throws {
        let content = try TestSupport.content()
        XCTAssertEqual(content.levels.map(\.id), ["world"])
        let chapters = try XCTUnwrap(content.level("world")).chapters
        XCTAssertEqual(chapters.map(\.name), ["Bare Ground", "First Belts", "Stone to Roof", "Free Build"])
        let radii = chapters.compactMap(\.reveal)
        XCTAssertEqual(radii, radii.sorted(), "Each chapter draws more of the map")
        XCTAssertNil(chapters.last?.goal, "Free build has no goal")
    }

    func testBrickIsMadeByTheKilnFromClayAndLogFuel() throws {
        let content = try TestSupport.content()
        let recipes = content.recipes(producing: "brick")
        XCTAssertEqual(recipes.map(\.id), ["brick"])
        let brick = try XCTUnwrap(recipes.first)
        XCTAssertEqual(brick.building, "brick_kiln")
        XCTAssertEqual(brick.inputs.first { $0.role == .fuel }?.item, "log")
        XCTAssertEqual(brick.inputs.first { $0.role == .material }?.item, "clay")
    }

    func testLookupsByID() throws {
        let content = try TestSupport.content()
        XCTAssertEqual(content.building("cottage")?.cost,
                       [ItemStack(item: "brick", count: 10), ItemStack(item: "plank", count: 6)])
        XCTAssertEqual(content.source("forest")?.item, "log")
        XCTAssertEqual(content.building("brick_kiln")?.width, 2)
        XCTAssertNil(content.item("steel_beam"))
    }

    func testMissingFileIsReportedByName() {
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent("groundwork-missing-\(UUID())")
        XCTAssertThrowsError(try ContentDatabase.load(from: empty)) { error in
            guard case let ContentError.unreadable(file, _) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(file, "levels.json", "Levels load first, to find their maps")
        }
    }

    func testIDsEncodeAsBareStrings() throws {
        let data = try JSONEncoder().encode(ItemStack(item: "clay", count: 2))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"item\":\"clay\""), json)
    }
}
