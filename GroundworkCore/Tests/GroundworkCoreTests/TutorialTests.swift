import XCTest
@testable import GroundworkCore

final class TutorialTests: XCTestCase {
    private func content() throws -> ContentDatabase { try TestSupport.content() }

    private func waitUntil(_ session: GameSession, limit: Int = 8000, _ condition: () -> Bool,
                           file: StaticString = #filePath, line: UInt = #line) {
        var n = 0
        while !condition() && n < limit {
            session.advance(ticks: 1)
            n += 1
        }
        XCTAssertTrue(condition(), "Timed out at tick \(session.world.tick) on \(session.tutorialStep?.id ?? "none")",
                      file: file, line: line)
    }

    private func id(_ type: BuildingTypeID, _ session: GameSession) throws -> EntityID {
        try XCTUnwrap(session.world.buildings.first { $0.type == type }?.id, "No \(type)")
    }

    private func origin(_ type: BuildingTypeID, _ session: GameSession) throws -> GridPoint {
        try XCTUnwrap(session.world.buildings.first { $0.type == type }?.origin, "No \(type)")
    }

    func testNewConditionsParse() {
        XCTAssertEqual(TutorialCondition("traced:brick_kiln"), .traced("brick_kiln"))
        XCTAssertEqual(TutorialCondition("ui:panned"), .ui("panned"))
        XCTAssertEqual(TutorialCondition("count:clay_pit:2"), .count("clay_pit", 2))
        XCTAssertEqual(TutorialCondition("wait"), .wait)
        XCTAssertEqual(TutorialCondition("slow:brick_kiln"), .slow("brick_kiln"))
        XCTAssertNil(TutorialCondition("count:clay_pit:zero"))
        XCTAssertNil(TutorialCondition("ui:"))
    }

    func testStepsAreShownForTheirMinimumTime() throws {
        let session = try GameSession(content: content())
        session.place("clay_pit", at: GridPoint(37, 29))
        // The first clay arrives on tick 30; l1_source must show at least 20 ticks anyway.
        waitUntil(session) { session.tutorialStep?.id == "l1_kiln" }
        XCTAssertGreaterThanOrEqual(session.world.tick, 30)
        session.place("brick_kiln", at: GridPoint(41, 28))
        let pit = try id("clay_pit", session), kiln = try id("brick_kiln", session)
        waitUntil(session) { (session.world.building(pit)?.output.count(of: "clay") ?? 0) >= 2 }
        session.pickUp(from: pit)
        session.drop(into: kiln)
        waitUntil(session) { session.tutorialStep?.id == "l1_belt" }
        session.layBelt(from: GridPoint(37, 29), to: GridPoint(41, 28))
        waitUntil(session) { session.tutorialStep?.id == "l1_look" }
        let shown = session.world.tick
        waitUntil(session) { session.tutorialStep?.id != "l1_look" }
        XCTAssertGreaterThanOrEqual(session.world.tick - shown, 100, "Tips stay up long enough to read")
    }

    func testUIActionsAreRecordedOnce() throws {
        let session = try GameSession(content: content())
        session.noteUI("panned")
        session.noteUI("panned")
        XCTAssertEqual(session.world.level?.seen.filter { $0 == "ui:panned" }.count, 1)
    }

    func testTracingABuildingIsRecorded() throws {
        let session = try GameSession(content: content())
        session.place("clay_pit", at: GridPoint(37, 29))
        session.trace(.building(try id("clay_pit", session)))
        XCTAssertTrue(session.world.level?.hasSeen("traced:clay_pit") ?? false)
        let loaded = try GameSession.load(try session.save(), content: session.content)
        XCTAssertTrue(loaded.world.level?.hasSeen("traced:clay_pit") ?? false, "Saved with the level")
    }

    func testSkipTutorialHandsOverEverything() throws {
        let session = try GameSession(content: content())
        session.skipTutorial()
        XCTAssertNil(session.tutorialStep)
        XCTAssertFalse(session.isPausedByTutorial)
        XCTAssertEqual(Set(session.world.unlocked ?? []), ["clay_pit", "brick_kiln", "lumber_camp", "storage_crate"])
        XCTAssertEqual(session.world.beltsAvailable, 18, "Every step's belt tiles")
        XCTAssertTrue(session.drainEvents().contains(.tutorialFinished("world")))
    }

    func testBadStepsAreRejected() throws {
        let base = try content()
        var tutorials = base.tutorials
        let bad = TutorialStep(id: "bad", text: "Waits forever", highlight: nil, when: "wait", grant: nil,
                               pauseSim: true, waitTicks: 10)
        tutorials["chapter1"] = [bad]
        do {
            _ = try ContentDatabase(items: base.items, sources: base.sources, buildings: base.buildings,
                                    recipes: base.recipes, rules: base.rules, legend: base.legend,
                                    levels: base.levels, tutorials: tutorials, maps: base.maps)
            XCTFail("Expected a problem")
        } catch let ContentError.invalid(problems) {
            XCTAssertTrue(problems.contains { $0.contains("pauses time") }, "\(problems)")
        }
    }

    func testTheBeltStepNeedsABeltThatIsStillThere() throws {
        let session = try GameSession(content: content())
        session.place("clay_pit", at: GridPoint(37, 29))
        waitUntil(session) { session.tutorialStep?.id == "l1_kiln" }
        session.place("brick_kiln", at: GridPoint(40, 28))
        let pit = try id("clay_pit", session), kiln = try id("brick_kiln", session)
        waitUntil(session) { (session.world.building(pit)?.output.count(of: "clay") ?? 0) >= 2 }
        session.pickUp(from: pit)
        session.drop(into: kiln)
        waitUntil(session) { session.tutorialStep?.id == "l1_belt" }
        session.advance(ticks: 300)
        XCTAssertEqual(session.tutorialStep?.id, "l1_belt", "No belt, no moving on")
        XCTAssertEqual(session.layBelt(from: GridPoint(37, 29), to: GridPoint(40, 28)), .ok)
        session.advance(ticks: 1)
        XCTAssertEqual(session.tutorialStep?.id, "l1_look")
        XCTAssertNil(session.brokenTutorialLink)

        // Undo the belt: the tutorial notices and asks for it again.
        session.undo()
        XCTAssertEqual(session.brokenTutorialLink?.from, "clay_pit")
        XCTAssertEqual(session.brokenTutorialLink?.to, "brick_kiln")
        session.layBelt(from: GridPoint(37, 29), to: GridPoint(40, 28))
        XCTAssertNil(session.brokenTutorialLink)
    }
}
