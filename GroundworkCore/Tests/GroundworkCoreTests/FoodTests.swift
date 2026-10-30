import XCTest
@testable import GroundworkCore

final class FoodTests: XCTestCase {
    private let field = [
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
    ]

    private func build(_ type: BuildingTypeID, at p: GridPoint, _ session: GameSession) throws -> EntityID {
        let id = try TestSupport.place(type, at: p, in: session)
        if let def = session.content.building(type), def.kind == .construction {
            for item in def.accepts { session.stock(id, with: item, count: def.inputCapacity) }
        }
        return id
    }

    func testAFieldGrowsWheatOnlyWithWater() throws {
        let session = try TestSupport.session(field)
        let wheat = try TestSupport.place("wheat_field", at: GridPoint(12, 4), in: session)
        session.advance(ticks: 300)
        XCTAssertEqual(session.world.building(wheat)?.output.count(of: "wheat") ?? 0, 0)
        XCTAssertEqual(session.world.building(wheat)?.status, .blocked(.noWater))
        _ = try build("well", at: GridPoint(15, 4), session)
        session.advance(ticks: 400)
        XCTAssertGreaterThan(session.world.building(wheat)?.output.count(of: "wheat") ?? 0, 0)
    }

    func testSoilTiresAndCompostBringsItBack() throws {
        let session = try TestSupport.session(field)
        let wheat = try TestSupport.place("wheat_field", at: GridPoint(12, 4), in: session)
        _ = try build("well", at: GridPoint(15, 4), session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(12, 8), in: session)
        session.layBelt(from: GridPoint(12, 4), to: GridPoint(12, 8))
        session.advance(ticks: 120 * 25)
        let tired = try XCTUnwrap(session.world.building(wheat))
        let def = try XCTUnwrap(session.content.building("wheat_field"))
        XCTAssertTrue(tired.hasTiredSoil(def, rules: session.content.rules), "Soil \(tired.soil ?? -1) after many harvests")
        session.stock(wheat, with: "compost", count: 4)
        session.advance(ticks: 10)
        let fed = try XCTUnwrap(session.world.building(wheat))
        XCTAssertFalse(fed.hasTiredSoil(def, rules: session.content.rules), "Compost restores it")
        XCTAssertGreaterThan(session.world.building(crate)?.input.count(of: "wheat") ?? 0, 0)
    }

    func testTiredSoilGrowsAtHalfSpeed() throws {
        let rules = try TestSupport.content().rules
        let def = try XCTUnwrap(try TestSupport.content().building("wheat_field"))
        let recipe = try XCTUnwrap(try TestSupport.content().recipe("grow_wheat"))
        let session = try TestSupport.session(field)
        let id = try TestSupport.place("wheat_field", at: GridPoint(12, 4), in: session)
        var b = try XCTUnwrap(session.world.building(id))
        XCTAssertEqual(Production.duration(recipe, b, def, rules), recipe.durationTicks)
        b.soil = rules.soilTired - 1
        XCTAssertEqual(Production.duration(recipe, b, def, rules), recipe.durationTicks * 2)
    }

    func testTheMillNeedsPowerAndTheBakeryMakesBread() throws {
        let session = try TestSupport.session(field)
        let mill = try TestSupport.place("flour_mill", at: GridPoint(6, 2), in: session)
        session.stock(mill, with: "wheat", count: 10)
        session.advance(ticks: 100)
        XCTAssertEqual(session.world.building(mill)?.status, .blocked(.noPower))
        _ = try build("waterwheel", at: GridPoint(3, 2), session)
        session.advance(ticks: 200)
        XCTAssertGreaterThan(session.world.building(mill)?.output.count(of: "flour") ?? 0, 0)

        let bakery = try TestSupport.place("bakery", at: GridPoint(14, 2), in: session)
        _ = try build("well", at: GridPoint(17, 2), session)
        session.stock(bakery, with: "flour", count: 4)
        session.stock(bakery, with: "log", count: 2)
        session.advance(ticks: 300)
        XCTAssertGreaterThan(session.world.building(bakery)?.output.count(of: "bread") ?? 0, 0)
    }

    func testAMarketStallOnlyTakesBread() throws {
        let session = try TestSupport.session(field)
        let stall = try TestSupport.place("market_stall", at: GridPoint(10, 4), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(20, 4), in: session)
        session.stock(crate, with: "brick", count: 5)
        session.pickUp(from: crate)
        guard case .rejected = session.drop(into: stall) else { return XCTFail("A stall is for bread") }
        session.stock(crate, with: "bread", count: 5)
        session.drop(into: crate)
        session.pickUp(from: crate, item: "bread", count: 5)
        XCTAssertEqual(session.drop(into: stall), .ok)
        XCTAssertEqual(session.world.building(stall)?.input.count(of: "bread"), 5)
    }

    func testWheatTracesBackToTheSoil() throws {
        let content = try TestSupport.content()
        XCTAssertEqual(content.source("soil")?.everywhere, true)
        XCTAssertEqual(content.recipe("grow_wheat")?.source, "soil")
    }
}
