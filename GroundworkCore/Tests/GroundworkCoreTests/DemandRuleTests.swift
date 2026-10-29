import XCTest
@testable import GroundworkCore

final class DemandRuleTests: XCTestCase {
    private let field = [
        "........................",
        "........................",
        "........................",
        "........................",
        "........................",
        "........................",
        "........................",
        "........................",
    ]

    /// Hand-delivers materials into the yard from a crate, a few at a time.
    private func feed(_ session: GameSession, yard: EntityID, crate: EntityID, bricks: Int, planks: Int) {
        session.stock(crate, with: "brick", count: bricks)
        session.stock(crate, with: "plank", count: planks)
        if bricks > 0 { session.pickUp(from: crate, item: "brick", count: bricks); session.drop(into: yard) }
        if planks > 0 { session.pickUp(from: crate, item: "plank", count: planks); session.drop(into: yard) }
    }

    private func homes(_ session: GameSession) -> [Building] {
        session.world.buildings.filter { $0.type == "cottage" }
    }

    func testSteadySupplyOrdersACottage() throws {
        let session = try TestSupport.session(field)
        let yard = try TestSupport.place("builders_yard", at: GridPoint(10, 3), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(1, 1), in: session)
        // 2 bricks and 1 plank every 6 seconds: 20 bricks and 10 planks a minute.
        for _ in 0..<9 {
            feed(session, yard: yard, crate: crate, bricks: 2, planks: 1)
            session.advance(ticks: 60)
        }
        XCTAssertTrue(homes(session).isEmpty, "Stock is enough, but supply has not been steady for a full minute")
        feed(session, yard: yard, crate: crate, bricks: 2, planks: 1)
        session.advance(ticks: 60)

        let built = homes(session)
        XCTAssertEqual(built.count, 1)
        let home = try XCTUnwrap(built.first)
        XCTAssertEqual(home.status, .constructing)
        XCTAssertEqual(session.world.building(yard)?.input.count(of: "brick"), 20 - 10)
        XCTAssertEqual(session.world.building(yard)?.input.count(of: "plank"), 10 - 6)
        let events = session.drainEvents()
        XCTAssertTrue(events.contains(.homeStarted(home.id, by: yard)))

        session.advance(ticks: 100)
        XCTAssertEqual(session.world.building(home.id)?.status, .complete)
        XCTAssertTrue(session.drainEvents().contains(.homeCompleted(home.id)))
    }

    func testOneBigDeliveryIsNotSteady() throws {
        let session = try TestSupport.session(field)
        let yard = try TestSupport.place("builders_yard", at: GridPoint(10, 3), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(1, 1), in: session)
        feed(session, yard: yard, crate: crate, bricks: 10, planks: 10)
        session.advance(ticks: 2000)
        XCTAssertTrue(homes(session).isEmpty, "A pile delivered long ago is not a steady supply")
    }

    func testOnlyOneHomeAtATime() throws {
        let session = try TestSupport.session(field)
        let yard = try TestSupport.place("builders_yard", at: GridPoint(10, 3), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(1, 1), in: session)
        for _ in 0..<10 {
            feed(session, yard: yard, crate: crate, bricks: 4, planks: 3)
            session.advance(ticks: 60)
        }
        XCTAssertEqual(homes(session).count, 1)
        XCTAssertEqual(homes(session).filter { !$0.isBuilt }.count, 1)
        feed(session, yard: yard, crate: crate, bricks: 4, planks: 3)
        session.advance(ticks: 60)
        XCTAssertEqual(homes(session).count, 1, "Still building the first")
        session.advance(ticks: 60)
        XCTAssertEqual(homes(session).count, 2, "The next starts once the first is done")
    }

    func testHomesGoOnPlotsAndKeepAGap() throws {
        let session = try TestSupport.session(field)
        session.setHousingPlots([GridPoint(20, 6), GridPoint(2, 5)])
        let yard = try TestSupport.place("builders_yard", at: GridPoint(10, 3), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(1, 1), in: session)
        for _ in 0..<10 {
            feed(session, yard: yard, crate: crate, bricks: 2, planks: 1)
            session.advance(ticks: 60)
        }
        XCTAssertEqual(homes(session).map(\.origin), [GridPoint(20, 6)], "First plot that fits")

        let auto = try TestSupport.session(field)
        let autoYard = try TestSupport.place("builders_yard", at: GridPoint(10, 3), in: auto)
        let autoCrate = try TestSupport.place("storage_crate", at: GridPoint(1, 1), in: auto)
        for _ in 0..<10 {
            feed(auto, yard: autoYard, crate: autoCrate, bricks: 2, planks: 1)
            auto.advance(ticks: 60)
        }
        let home = try XCTUnwrap(homes(auto).first)
        let yardDef = try XCTUnwrap(auto.content.building("builders_yard"))
        let yardBuilding = try XCTUnwrap(auto.world.building(autoYard))
        let homeDef = try XCTUnwrap(auto.content.building("cottage"))
        for point in home.footprint(homeDef) {
            for neighbour in point.neighbours {
                XCTAssertFalse(yardBuilding.covers(neighbour, yardDef), "Homes leave a gap around the yard")
            }
        }
    }

    // MARK: The whole prototype chain, automated

    private let valley = [
        "..............................",
        ".cc...........................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        ".TT...........................",
        "..............................",
        "..............................",
        "..............................",
    ]

    private func buildChain() throws -> GameSession {
        let session = try TestSupport.session(valley, seed: 7)
        try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        try TestSupport.place("clay_pit", at: GridPoint(2, 1), in: session)
        try TestSupport.place("lumber_camp", at: GridPoint(1, 8), in: session)
        try TestSupport.place("lumber_camp", at: GridPoint(2, 8), in: session)
        try TestSupport.place("brick_kiln", at: GridPoint(8, 2), in: session)
        try TestSupport.place("sawmill", at: GridPoint(8, 8), in: session)
        try TestSupport.place("builders_yard", at: GridPoint(16, 5), in: session)
        TestSupport.layBelt(from: GridPoint(1, 1), to: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(2, 1), to: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(1, 8), to: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(2, 8), to: GridPoint(8, 8), in: session)
        TestSupport.layBelt(from: GridPoint(8, 2), to: GridPoint(16, 5), in: session)
        TestSupport.layBelt(from: GridPoint(8, 8), to: GridPoint(16, 5), in: session)
        return session
    }

    func testTheChainBuildsCottagesOnItsOwn() throws {
        let session = try buildChain()
        session.advance(ticks: 3000)
        let built = homes(session).filter(\.isBuilt)
        XCTAssertGreaterThanOrEqual(built.count, 2, "Five minutes of brick and plank should build cottages")
        let trace = session.trace(.building(try XCTUnwrap(built.first).id))
        XCTAssertEqual(Set(trace.allNodes.compactMap { node -> SourceID? in
            if case let .source(id) = node.subject { return id }
            return nil
        }), ["clay_deposit", "forest"], "A cottage traces back to clay and forest")
    }

    func testTheChainIsDeterministic() throws {
        let fast = try buildChain()
        let slow = try buildChain()
        fast.advance(ticks: 2000)
        for _ in 0..<2000 { slow.advance(ticks: 1) }
        XCTAssertEqual(try fast.save(), try slow.save(), "Fast-forward gives identical results")

        let straight = try buildChain()
        straight.advance(ticks: 2000)
        let first = try buildChain()
        first.advance(ticks: 777)
        let resumed = try GameSession.load(try first.save(), content: first.content)
        resumed.advance(ticks: 2000 - 777)
        XCTAssertEqual(try resumed.save(), try straight.save(), "Save, load, run equals running straight")
    }
}
