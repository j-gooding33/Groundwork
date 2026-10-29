import XCTest
@testable import GroundworkCore

final class TraceTests: XCTestCase {
    private let field = [
        "....................",
        ".cc.................",
        "....................",
        "....................",
        ".TT.................",
        "....................",
        "....................",
    ]

    private func sources(in result: TraceResult) -> Set<SourceID> {
        Set(result.allNodes.compactMap { node in
            if case let .source(id) = node.subject { return id }
            return nil
        })
    }

    func testBrickTracesBackToClayAndForestWithNothingBuilt() throws {
        let session = try TestSupport.session(field)
        let result = session.trace(.item("brick"))
        XCTAssertEqual(result.root.state, .notBuilt)
        XCTAssertEqual(result.root.reason, "No Brick Kiln built yet")
        XCTAssertEqual(result.root.children.map(\.subject), [.missingBuilding("brick_kiln")])
        let kilnStep = result.root.children[0]
        XCTAssertEqual(kilnStep.children.map(\.subject), [.item("clay"), .item("log")])
        XCTAssertEqual(sources(in: result), ["clay_deposit", "forest"])
        XCTAssertEqual(result.firstBroken?.subject, .missingBuilding("brick_kiln"))
        XCTAssertNil(result.jumpTarget)
    }

    func testEveryItemTracesToASource() throws {
        let session = try TestSupport.session(field)
        for item in session.content.items {
            let result = session.trace(.item(item.id))
            XCTAssertFalse(sources(in: result).isEmpty, "\(item.id) must trace back to nature")
        }
    }

    func testBlockedKilnPointsAtTheMissingLumberCamp() throws {
        let session = try TestSupport.session(field)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(8, 1), in: session)
        session.stock(kiln, with: "clay", count: 6)
        session.advance(ticks: 30)

        let result = session.trace(.building(kiln))
        XCTAssertEqual(result.root.state, .blocked)
        XCTAssertEqual(result.root.reason, "Waiting for logs")
        XCTAssertEqual(result.firstBroken?.subject, .missingBuilding("lumber_camp"))
        XCTAssertEqual(result.firstBroken?.reason, "Build a Lumber Camp")
        XCTAssertEqual(result.jumpTarget, kiln, "Tapping jumps to the kiln that needs logs")
    }

    func testUnconnectedProducerIsCalledOut() throws {
        let session = try TestSupport.session(field)
        try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(8, 1), in: session)
        session.stock(kiln, with: "log", count: 5)
        session.advance(ticks: 30)

        let result = session.trace(.building(kiln))
        XCTAssertEqual(result.root.reason, "Waiting for clay")
        let clay = try XCTUnwrap(result.root.children.first { $0.subject == .item("clay") })
        XCTAssertEqual(clay.state, .blocked)
        XCTAssertEqual(clay.reason, "No belt brings clay from the Clay Pit to the Brick Kiln")
        XCTAssertEqual(result.firstBroken?.subject, .item("clay"))
        XCTAssertEqual(result.jumpTarget, kiln)
    }

    func testSlowInputIsFlagged() throws {
        let session = try TestSupport.session(field)
        let pit = try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        let camp = try TestSupport.place("lumber_camp", at: GridPoint(1, 4), in: session)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(1, 1), to: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(1, 4), to: GridPoint(8, 2), in: session)
        try TestSupport.place("storage_crate", at: GridPoint(14, 2), in: session)
        TestSupport.layBelt(from: GridPoint(8, 2), to: GridPoint(14, 2), in: session)
        session.advance(ticks: 1200)
        _ = (pit, camp)

        // One pit makes 20 clay a minute; the kiln uses 24.
        let result = session.trace(.building(kiln))
        XCTAssertEqual(result.root.state, .slow)
        XCTAssertTrue(result.root.reason.hasPrefix("Clay delivery is too slow"), result.root.reason)
        XCTAssertEqual(result.firstBroken?.subject, .building(kiln, "brick_kiln"),
                       "The clay pit is fine; the kiln is the step that is short")
        XCTAssertEqual(session.trace(.item("brick")).root.state, .slow)
    }

    func testHealthyChainHasNoBrokenStep() throws {
        let session = try TestSupport.session(field)
        try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        try TestSupport.place("clay_pit", at: GridPoint(2, 1), in: session)
        try TestSupport.place("lumber_camp", at: GridPoint(1, 4), in: session)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(1, 1), to: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(2, 1), to: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(1, 4), to: GridPoint(8, 2), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(14, 2), in: session)
        TestSupport.layBelt(from: GridPoint(8, 2), to: GridPoint(14, 2), in: session)
        session.advance(ticks: 1200)

        let result = session.trace(.item("brick"))
        XCTAssertEqual(result.root.state, .running, "\(result.allNodes.map { "\($0.label): \($0.reason)" })")
        XCTAssertTrue(result.brokenPath.isEmpty)
        XCTAssertTrue(result.root.reason.hasPrefix("Made at"), result.root.reason)
        let kilnNode = try XCTUnwrap(result.root.children.first)
        XCTAssertEqual(kilnNode.entity, kiln)
        XCTAssertGreaterThan(session.world.building(crate)?.input.count(of: "brick") ?? 0, 10)
    }

    func testUsedUpDepositIsTheBrokenStep() throws {
        let content = try TestSupport.content()
        let map = TileMap(width: 4, height: 2, terrain: Array(repeating: .grass, count: 8),
                          deposits: [SourceDeposit(point: GridPoint(1, 0), source: "clay_deposit", remaining: 1)])
        let session = GameSession(content: content, map: map, seed: 1)
        let pit = try TestSupport.place("clay_pit", at: GridPoint(1, 0), in: session)
        session.advance(ticks: 60)

        let result = session.trace(.building(pit))
        XCTAssertEqual(result.root.reason, "The clay deposit here is used up")
        XCTAssertEqual(result.firstBroken?.subject, .source("clay_deposit"))
        XCTAssertEqual(result.firstBroken?.reason, "The clay deposit here is used up")
        XCTAssertEqual(result.jumpTarget, pit)
    }

    func testTraceIsPureAndRepeatable() throws {
        let session = try TestSupport.session(field)
        try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        session.advance(ticks: 100)
        let before = session.world
        let first = session.trace(.item("brick"))
        XCTAssertEqual(session.world, before, "Trace never changes the world")
        XCTAssertEqual(session.trace(.item("brick")), first)
    }
}
