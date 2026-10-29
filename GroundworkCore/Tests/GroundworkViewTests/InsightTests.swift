import XCTest
@testable import GroundworkCore
@testable import GroundworkView

/// The Trace panel, status bubbles and rate labels: ways to see a
/// bottleneck without opening anything.
final class InsightTests: XCTestCase {
    private func kilnWithoutLogs() throws -> (GameSession, EntityID) {
        let session = try ViewTestSupport.session(["..........", "..........", ".........."])
        session.place("brick_kiln", at: GridPoint(4, 0))
        let kiln = try XCTUnwrap(session.world.building(at: GridPoint(4, 0))).id
        session.stock(kiln, with: "clay", count: 6)
        session.advance(ticks: 30)
        return (session, kiln)
    }

    // MARK: Trace panel

    func testTracePanelListsTheChainAndMarksTheStepToFix() throws {
        let (session, kiln) = try kilnWithoutLogs()
        var input = InputController()
        input.use(.trace)
        _ = input.tap(GridPoint(4, 0), session: session)
        let rows = HUDModel(session: session, input: input).tracePanel
        XCTAssertEqual(rows.first?.label, "Brick Kiln")
        XCTAssertEqual(rows.first?.reason, "Waiting for logs")
        XCTAssertTrue(rows.first?.isBroken ?? false)
        let fix = try XCTUnwrap(rows.last { $0.isBroken })
        XCTAssertEqual(fix.label, "Lumber Camp")
        XCTAssertEqual(fix.reason, "Build a Lumber Camp")
        XCTAssertEqual(fix.target, kiln, "Tapping the missing step jumps to the kiln that needs it")
        XCTAssertEqual(rows.map(\.depth).first, 0)
        XCTAssertTrue(zip(rows, rows.dropFirst()).allSatisfy { $1.depth <= $0.depth + 1 }, "Depth only steps one at a time")
    }

    func testTracePanelFitsOnScreenForATown() throws {
        let town = try ViewTestSupport.town(ticks: 6000)
        var input = InputController()
        input.use(.trace)
        let cottage = try XCTUnwrap(town.world.buildings.first { $0.type == "cottage" })
        _ = input.tap(cottage.origin, session: town)
        let rows = HUDModel(session: town, input: input).tracePanel
        XCTAssertLessThanOrEqual(rows.count, HUDModel.traceRowLimit)
        XCTAssertEqual(rows.first?.label, "Cottage")
        XCTAssertTrue(rows.contains { $0.label == "Clay deposit" || $0.label == "Forest" } || rows.count == HUDModel.traceRowLimit)
    }

    // MARK: Status bubbles

    func testBubblesSayWhatIsWrong() throws {
        let builder = try ViewTestSupport.builder()
        let (session, kiln) = try kilnWithoutLogs()
        XCTAssertEqual(builder.statusIcon(for: session.world.building(kiln)!, world: session.world), "item_log")

        let full = try ViewTestSupport.session([".c....", "......"])
        full.place("clay_pit", at: GridPoint(1, 0))
        full.advance(ticks: 400)
        XCTAssertEqual(builder.statusIcon(for: full.world.building(at: GridPoint(1, 0))!, world: full.world), "status_full")

        let content = builder.content
        let map = TileMap(width: 4, height: 2, terrain: Array(repeating: .grass, count: 8),
                          deposits: [SourceDeposit(point: GridPoint(1, 0), source: "clay_deposit", remaining: 1)])
        let empty = GameSession(content: content, map: map, seed: 1)
        empty.place("clay_pit", at: GridPoint(1, 0))
        empty.advance(ticks: 60)
        XCTAssertEqual(builder.statusIcon(for: empty.world.building(at: GridPoint(1, 0))!, world: empty.world), "status_empty")

        for icon in ["item_log", "status_full", "status_empty", "status_slow", "ui_status_bubble"] {
            XCTAssertTrue(builder.atlas.has(icon), icon)
        }
        let sprites = builder.dynamicLayer(session.world, time: RenderTime())
        XCTAssertTrue(sprites.contains { $0.id == "sti:\(kiln)" && $0.name == "item_log" && $0.z > Layer.tint },
                      "The bubble is drawn above the night wash")
    }

    func testSlowKilnGetsAnHourglass() throws {
        let builder = try ViewTestSupport.builder()
        let session = try ViewTestSupport.session([
            "....................", ".c..................", "....................", ".T..................",
        ])
        session.place("clay_pit", at: GridPoint(1, 1))
        session.place("lumber_camp", at: GridPoint(1, 3))
        session.place("brick_kiln", at: GridPoint(8, 1))
        session.place("storage_crate", at: GridPoint(14, 1))
        XCTAssertEqual(session.layBelt(from: GridPoint(1, 1), to: GridPoint(8, 1)), .ok)
        XCTAssertEqual(session.layBelt(from: GridPoint(1, 3), to: GridPoint(8, 1)), .ok)
        XCTAssertEqual(session.layBelt(from: GridPoint(8, 1), to: GridPoint(14, 1)), .ok)
        session.advance(ticks: 2400)
        let kiln = try XCTUnwrap(session.world.building(at: GridPoint(8, 1)))
        XCTAssertEqual(builder.statusIcon(for: kiln, world: session.world), "status_slow")
    }

    // MARK: Rate labels

    func testRateLabelsShowMadeUsedAndWarnings() throws {
        let builder = try ViewTestSupport.builder()
        let session = try ViewTestSupport.session([".c........", ".........."])
        session.place("clay_pit", at: GridPoint(1, 0))
        session.place("brick_kiln", at: GridPoint(5, 0))
        let kiln = try XCTUnwrap(session.world.building(at: GridPoint(5, 0))).id
        session.stock(kiln, with: "clay", count: 20)
        session.stock(kiln, with: "log", count: 7)
        session.advance(ticks: 300)          // the pit makes exactly 10 clay; the kiln burns 6 logs
        let labels = builder.rateLabels(session.world)
        let pit = try XCTUnwrap(labels.first { $0.id == "rate:\(session.world.building(at: GridPoint(1, 0))!.id)" })
        XCTAssertEqual(pit.lines.first, "+20 clay/min")
        let kilnLabel = try XCTUnwrap(labels.first { $0.id == "rate:\(kiln)" })
        XCTAssertTrue(kilnLabel.lines.contains { $0.hasPrefix("-") && $0.hasSuffix("logs") }, "\(kilnLabel.lines)")
        XCTAssertEqual(kilnLabel.warning?.hasPrefix("logs out in"), true, "\(kilnLabel)")
    }

    func testNeighbouringLabelsNeverOverlap() {
        let a = RateLabel(id: "a", x: 100, y: 50, lines: ["+15 logs/min"], warning: nil)
        let b = RateLabel(id: "b", x: 112, y: 50, lines: ["+15 logs/min"], warning: "logs out in 9s")
        let far = RateLabel(id: "c", x: 300, y: 50, lines: ["+1 clay/min"], warning: nil)
        let out = SceneBuilder.separate([a, b, far])
        let moved = out.filter { $0.y != 50 }
        XCTAssertEqual(moved.count, 1, "One of the pair moves down")
        XCTAssertEqual(out.first { $0.id == "c" }?.y, 50, "Labels with room stay put")
        let lower = moved[0]
        XCTAssertLessThanOrEqual(lower.y, 50 - SceneBuilder.labelLineHeight, "Below the other label's text")
    }

    func testRatesTabAppearsAfterTheTutorial() throws {
        let session = try GameSession(content: try ViewTestSupport.content())
        XCTAssertFalse(HUDModel(session: session, input: InputController()).tabs.contains(.rates))
        session.skipTutorial()
        XCTAssertTrue(HUDModel(session: session, input: InputController()).tabs.contains(.rates))
        var input = InputController()
        input.toggleRates()
        XCTAssertTrue(input.showRates)
    }
}
