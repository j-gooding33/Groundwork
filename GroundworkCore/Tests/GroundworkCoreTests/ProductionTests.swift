import XCTest
@testable import GroundworkCore

final class ProductionTests: XCTestCase {
    private let field = [
        "..........",
        ".c........",
        "..........",
        ".T........",
        "....~~....",
        "..........",
    ]

    func testClayPitProducesAtTheDataRate() throws {
        let session = try TestSupport.session(field)
        let pit = try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        session.advance(ticks: 300)
        // 30 ticks per clay: exactly 10 in 300 ticks.
        XCTAssertEqual(session.world.building(pit)?.output.count(of: "clay"), 10)
        XCTAssertEqual(session.rates(of: pit).first { $0.item == "clay" }?.made, 20)
        XCTAssertEqual(session.world.map.deposit(at: GridPoint(1, 1))?.remaining, 190)
    }

    func testFullOutputBlocksTheMachine() throws {
        let session = try TestSupport.session(field)
        let pit = try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        session.advance(ticks: 400)
        let building = try XCTUnwrap(session.world.building(pit))
        XCTAssertEqual(building.output.count(of: "clay"), 10, "Output capacity is 10")
        XCTAssertEqual(building.status, .blocked(.outputFull))
        XCTAssertEqual(session.world.map.deposit(at: GridPoint(1, 1))?.remaining, 190, "Nothing taken while blocked")
    }

    func testKilnMakesABrickFromClayAndLogFuel() throws {
        let session = try TestSupport.session(field)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        session.stock(kiln, with: "clay", count: 2)
        session.stock(kiln, with: "log", count: 1)
        session.advance(ticks: 49)
        XCTAssertEqual(session.world.building(kiln)?.output.count(of: "brick"), 0)
        session.advance(ticks: 1)
        let building = try XCTUnwrap(session.world.building(kiln))
        XCTAssertEqual(building.output.count(of: "brick"), 1)
        XCTAssertTrue(building.input.isEmpty)
        XCTAssertTrue(session.drainEvents().contains(.itemProduced(kiln, "brick", count: 1)))
    }

    func testKilnWithoutFuelSaysWaitingForLogs() throws {
        let session = try TestSupport.session(field)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        session.stock(kiln, with: "clay", count: 4)
        session.advance(ticks: 19)
        XCTAssertEqual(session.world.building(kiln)?.status, .idle, "Grace period before showing blocked")
        session.advance(ticks: 1)
        let building = try XCTUnwrap(session.world.building(kiln))
        XCTAssertEqual(building.status, .blocked(.missingFuel("log")))
        XCTAssertEqual(BlockReason.missingFuel("log").text(session.content), "Waiting for logs")
    }

    func testKilnWithoutClaySaysWaitingForClay() throws {
        let session = try TestSupport.session(field)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        session.stock(kiln, with: "log", count: 4)
        session.advance(ticks: 25)
        XCTAssertEqual(session.world.building(kiln)?.status, .blocked(.missingInput("clay")))
    }

    func testPlacementRules() throws {
        let session = try TestSupport.session(field)
        guard case .rejected(.needsSource) = session.place("clay_pit", at: GridPoint(3, 1)) else {
            return XCTFail("A clay pit needs a clay deposit")
        }
        guard case .rejected(.needsSource) = session.place("lumber_camp", at: GridPoint(1, 1)) else {
            return XCTFail("A lumber camp cannot sit on clay")
        }
        guard case .rejected(.blocked) = session.place("brick_kiln", at: GridPoint(4, 4)) else {
            return XCTFail("No building on water")
        }
        guard case .rejected(.blocked) = session.place("brick_kiln", at: GridPoint(9, 5)) else {
            return XCTFail("A 2x2 kiln does not fit in the corner")
        }
        guard case .rejected(.builtByYard) = session.place("cottage", at: GridPoint(6, 1)) else {
            return XCTFail("Cottages come from the yard")
        }
        XCTAssertEqual(session.place("brick_kiln", at: GridPoint(6, 1)), .ok)
        guard case .rejected(.blocked) = session.place("storage_crate", at: GridPoint(7, 2)) else {
            return XCTFail("No overlapping buildings")
        }
        session.setUnlocked(["clay_pit"])
        guard case .rejected(.notUnlocked) = session.place("storage_crate", at: GridPoint(3, 1)) else {
            return XCTFail("Locked buildings cannot be placed")
        }
    }

    func testDepletedDepositBlocksTheGatherer() throws {
        let session = try TestSupport.session(field)
        let pit = try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(3, 1), in: session)
        let other = try TestSupport.place("storage_crate", at: GridPoint(3, 2), in: session)
        var crates = [crate, other, try TestSupport.place("storage_crate", at: GridPoint(5, 5), in: session),
                      try TestSupport.place("storage_crate", at: GridPoint(6, 5), in: session)]
        // Carry clay away by hand until the deposit (200) runs dry.
        for _ in 0..<700 {
            session.advance(ticks: 10)
            session.pickUp(from: pit)
            while session.world.hand != nil, let target = crates.first {
                if !session.drop(into: target).isOK { crates.removeFirst() }
            }
        }
        XCTAssertEqual(session.world.map.deposit(at: GridPoint(1, 1))?.remaining, 0)
        session.advance(ticks: 30)
        XCTAssertEqual(session.world.building(pit)?.status, .blocked(.sourceDepleted("clay_deposit")))
        XCTAssertEqual(BlockReason.sourceDepleted("clay_deposit").text(session.content),
                       "The clay deposit here is used up")
        XCTAssertTrue(session.drainEvents().contains(.sourceDepleted(GridPoint(1, 1), "clay_deposit")))
    }

    func testForestRegrows() throws {
        let content = try TestSupport.content()
        var map = try TileMap.parse(".T", content: content)
        XCTAssertTrue(map.take(120, at: GridPoint(1, 0)))
        XCTAssertFalse(map.take(1, at: GridPoint(1, 0)))
        var world = World(map: map, seed: 1)
        var events: [GameEvent] = []
        for _ in 0..<Simulation.ticksPerMinute { Simulation.step(&world, content: content, events: &events) }
        XCTAssertEqual(world.map.deposit(at: GridPoint(1, 0))?.remaining, 6, "6 per minute")
    }

    // MARK: Hand carry

    func testHandCarriesUpToTenOfOneItem() throws {
        let session = try TestSupport.session(field)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(3, 1), in: session)
        session.stock(crate, with: "clay", count: 15)
        session.stock(crate, with: "log", count: 5)
        XCTAssertEqual(session.pickUp(from: crate, item: "clay"), .ok)
        XCTAssertEqual(session.world.hand, ItemStack(item: "clay", count: 10))
        guard case let .rejected(.hands(message)) = session.pickUp(from: crate, item: "log") else {
            return XCTFail("Hands hold one kind of item")
        }
        XCTAssertEqual(message, "Your hands are full of clay")
        guard case .rejected(.hands) = session.pickUp(from: crate) else { return XCTFail("Hands are full") }
        XCTAssertEqual(session.world.building(crate)?.input.count(of: "clay"), 5)
    }

    func testCarryingClayFillsTheKiln() throws {
        let session = try TestSupport.session(field)
        let pit = try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        session.stock(kiln, with: "log", count: 5)
        session.advance(ticks: 60)
        XCTAssertEqual(session.pickUp(from: pit), .ok)
        XCTAssertEqual(session.world.hand, ItemStack(item: "clay", count: 2))
        XCTAssertEqual(session.drop(into: kiln), .ok)
        XCTAssertNil(session.world.hand)
        XCTAssertTrue(session.drainEvents().contains(.itemDelivered(kiln, "clay", via: .hand)))
        session.advance(ticks: 50)
        XCTAssertEqual(session.world.building(kiln)?.output.count(of: "brick"), 1, "The first brick pops out")
    }

    func testKilnRefusesWhatItDoesNotUse() throws {
        let session = try TestSupport.session(field)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(3, 1), in: session)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        session.stock(crate, with: "plank", count: 3)
        session.pickUp(from: crate)
        guard case .rejected(.hands) = session.drop(into: kiln) else { return XCTFail("Kilns do not take planks") }
        XCTAssertEqual(session.world.hand?.count, 3)
    }

    func testKilnInputHasRoomForEachIngredient() throws {
        let session = try TestSupport.session(field)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(3, 1), in: session)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        session.stock(crate, with: "clay", count: 20)
        session.pickUp(from: crate)
        session.drop(into: kiln)
        session.pickUp(from: crate)
        session.drop(into: kiln)
        XCTAssertEqual(session.world.building(kiln)?.input.count(of: "clay"), 10, "10 clay at most")
        XCTAssertEqual(session.world.hand?.count, 10)
        session.stock(crate, with: "log", count: 1)
        session.drop(into: crate)
        session.pickUp(from: crate, item: "log")
        XCTAssertEqual(session.drop(into: kiln), .ok, "Full of clay still leaves room for fuel")
    }

    // MARK: Undo

    func testUndoPlaceAndRemove() throws {
        let session = try TestSupport.session(field)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        XCTAssertEqual(session.undo(), .ok)
        XCTAssertNil(session.world.building(kiln))
        XCTAssertTrue(session.world.isFree(GridPoint(6, 1)))

        let again = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        session.stock(again, with: "clay", count: 3)
        XCTAssertEqual(session.remove(again), .ok)
        XCTAssertNil(session.world.building(again))
        XCTAssertEqual(session.undo(), .ok)
        XCTAssertEqual(session.world.building(again)?.input.count(of: "clay"), 3, "Undo brings back its contents")
        XCTAssertEqual(session.world.building(at: GridPoint(7, 2))?.id, again)
    }

    func testUndoWithNothingToUndo() throws {
        let session = try TestSupport.session(field)
        XCTAssertEqual(session.undo(), .rejected(.nothingToUndo))
    }

    func testUndoRemoveFailsIfTheSpotIsTaken() throws {
        let session = try TestSupport.session(field)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(3, 1), in: session)
        session.remove(crate)
        session.place("brick_kiln", at: GridPoint(3, 1))
        session.undo() // removes the kiln
        XCTAssertEqual(session.undo(), .ok, "Now the crate's spot is free again")
        XCTAssertNotNil(session.world.building(crate))
    }
}
