import XCTest
@testable import GroundworkCore

final class UtilityTests: XCTestCase {
    // Water down the left edge, a rock at (20, 1).
    private let field = [
        "~~~...........................",
        "~~~.................^.........",
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

    /// A construction site filled straight away, so it works.
    private func build(_ type: BuildingTypeID, at p: GridPoint, _ session: GameSession,
                       file: StaticString = #filePath, line: UInt = #line) throws -> EntityID {
        let id = try TestSupport.place(type, at: p, in: session, file: file, line: line)
        if let def = session.content.building(type), def.kind == .construction {
            for item in def.accepts { session.stock(id, with: item, count: def.inputCapacity) }
        }
        return id
    }

    func testAQuarryCutsStoneFromRock() throws {
        let session = try TestSupport.session(field)
        XCTAssertNotEqual(session.place("quarry", at: GridPoint(10, 1)), .ok, "Only on rock")
        let quarry = try TestSupport.place("quarry", at: GridPoint(20, 1), in: session)
        session.advance(ticks: 200)
        XCTAssertGreaterThan(session.world.building(quarry)?.output.count(of: "stone") ?? 0, 0)
    }

    func testWaterwheelsAndPumpsGoBesideWater() throws {
        let session = try TestSupport.session(field)
        XCTAssertNotEqual(session.place("waterwheel", at: GridPoint(10, 3)), .ok)
        XCTAssertEqual(session.place("waterwheel", at: GridPoint(3, 3)), .ok)
        XCTAssertNotEqual(session.place("water_pump", at: GridPoint(12, 8)), .ok)
        XCTAssertEqual(session.place("water_pump", at: GridPoint(3, 8)), .ok)
    }

    func testAWaterwheelPowersAFewMachinesNearby() throws {
        let session = try TestSupport.session(field)
        let wheel = try TestSupport.place("waterwheel", at: GridPoint(3, 3), in: session)
        let pump = try build("water_pump", at: GridPoint(3, 7), session)
        session.advance(ticks: 1)
        XCTAssertFalse(session.world.isPowered(pump), "An unfinished wheel gives no power")
        session.stock(wheel, with: "plank", count: 12)
        session.advance(ticks: 1)
        XCTAssertTrue(session.world.isPowered(pump))
        let far = try build("water_pump", at: GridPoint(3, 11), session)
        session.advance(ticks: 1)
        XCTAssertFalse(session.world.isPowered(far), "Seven tiles away is too far")
        for y in [5, 6, 8, 9] { _ = try build("water_pump", at: GridPoint(3, y), session) }
        session.advance(ticks: 1)
        let pumps = session.world.buildings.filter { $0.type == "water_pump" }
        XCTAssertEqual(pumps.filter { session.world.isPowered($0.id) }.count, 4, "One wheel drives four machines")
    }

    func testPipedWaterReachesHomesAroundATower() throws {
        let session = try TestSupport.session(field)
        _ = try build("waterwheel", at: GridPoint(3, 3), session)
        _ = try build("water_pump", at: GridPoint(3, 6), session)
        let tower = try build("water_tower", at: GridPoint(14, 5), session)
        let near = session.insert("cottage", at: GridPoint(18, 8))
        let far = session.insert("cottage", at: GridPoint(27, 0))
        session.advance(ticks: 60)
        XCTAssertFalse(session.world.hasWater(near), "No pipe yet")
        XCTAssertEqual(session.layPipe(from: GridPoint(4, 6), to: GridPoint(13, 5)), .ok)
        session.advance(ticks: 60)
        XCTAssertTrue(session.world.hasWater(near), "Within the tower's reach")
        XCTAssertFalse(session.world.hasWater(far), "Too far from the tower")
        session.advance(ticks: 600)
        XCTAssertGreaterThan(session.world.storedWater(tower), 0, "Spare water fills the tower")
        XCTAssertTrue(session.drainEvents().contains(.waterChanged(near, true)))
    }

    func testAPumpWithoutPowerGivesNoWater() throws {
        let session = try TestSupport.session(field)
        _ = try build("water_pump", at: GridPoint(3, 6), session)
        _ = try build("water_tower", at: GridPoint(14, 5), session)
        let home = session.insert("cottage", at: GridPoint(18, 8))
        session.layPipe(from: GridPoint(4, 6), to: GridPoint(13, 5))
        session.advance(ticks: 120)
        XCTAssertFalse(session.world.hasWater(home))
    }

    func testAWellServesAFewHomesWithoutPipes() throws {
        let session = try TestSupport.session(field)
        _ = try build("well", at: GridPoint(15, 6), session)
        let homes = [GridPoint(17, 6), GridPoint(12, 6), GridPoint(15, 8), GridPoint(15, 3), GridPoint(18, 9)]
            .map { session.insert("cottage", at: $0) }
        session.advance(ticks: 60)
        let served = homes.filter(session.world.hasWater).count
        XCTAssertGreaterThan(served, 0)
        XCTAssertLessThan(served, homes.count, "A well only runs to a few homes")
    }

    func testPipesRunUnderRoadsButNotBuildings() throws {
        let session = try TestSupport.session(field)
        XCTAssertEqual(session.layRoad(from: GridPoint(10, 0), to: GridPoint(10, 11)), .ok)
        XCTAssertEqual(session.layPipe(from: GridPoint(5, 5), to: GridPoint(15, 5)), .ok)
        XCTAssertTrue(session.world.hasPipe(GridPoint(10, 5)), "Under the road")
        _ = try TestSupport.place("storage_crate", at: GridPoint(20, 5), in: session)
        session.layPipe(from: GridPoint(18, 5), to: GridPoint(22, 5))
        XCTAssertFalse(session.world.hasPipe(GridPoint(20, 5)), "Around the crate")
        XCTAssertEqual(session.undo(), .ok)
    }

    func testUtilitiesSurviveSaving() throws {
        let session = try TestSupport.session(field)
        _ = try build("waterwheel", at: GridPoint(3, 3), session)
        _ = try build("water_pump", at: GridPoint(3, 6), session)
        _ = try build("water_tower", at: GridPoint(14, 5), session)
        session.insert("cottage", at: GridPoint(18, 8))
        session.layPipe(from: GridPoint(4, 6), to: GridPoint(13, 5))
        session.advance(ticks: 130)
        let loaded = try GameSession.load(try session.save(), content: session.content)
        XCTAssertEqual(loaded.world, session.world)
        loaded.advance(ticks: 300)
        session.advance(ticks: 300)
        XCTAssertEqual(try loaded.save(), try session.save())
    }

    func testNewConditions() {
        XCTAssertEqual(TutorialCondition("watered:5"), .watered(5))
        XCTAssertEqual(TutorialCondition("powered:water_pump"), .powered("water_pump"))
    }
}

extension UtilityTests {
    func testDraggingFromABuildingStartsBesideIt() throws {
        let session = try TestSupport.session(field)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(10, 5), in: session)
        XCTAssertEqual(session.layPipe(from: GridPoint(10, 5), to: GridPoint(20, 5)), .ok)
        XCTAssertTrue(session.world.hasPipe(GridPoint(11, 5)), "Starts on the side facing where it goes")
        XCTAssertEqual(session.layRoad(from: GridPoint(10, 5), to: GridPoint(10, 11)), .ok)
        XCTAssertTrue(session.world.hasRoad(GridPoint(10, 6)))
        _ = crate
    }
}
