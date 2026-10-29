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
        let session = try GameSession(content: content(), level: "level1")
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
        let session = try GameSession(content: content(), level: "level1")
        session.noteUI("panned")
        session.noteUI("panned")
        XCTAssertEqual(session.world.level?.seen.filter { $0 == "ui:panned" }.count, 1)
    }

    func testTracingABuildingIsRecorded() throws {
        let session = try GameSession(content: content(), level: "level1")
        session.place("clay_pit", at: GridPoint(37, 29))
        session.trace(.building(try id("clay_pit", session)))
        XCTAssertTrue(session.world.level?.hasSeen("traced:clay_pit") ?? false)
        let loaded = try GameSession.load(try session.save(), content: session.content)
        XCTAssertTrue(loaded.world.level?.hasSeen("traced:clay_pit") ?? false, "Saved with the level")
    }

    func testSkipTutorialHandsOverEverything() throws {
        let session = try GameSession(content: content(), level: "level1")
        session.skipTutorial()
        XCTAssertNil(session.tutorialStep)
        XCTAssertFalse(session.isPausedByTutorial)
        XCTAssertEqual(Set(session.world.unlocked ?? []), ["clay_pit", "brick_kiln", "lumber_camp", "storage_crate"])
        XCTAssertEqual(session.world.beltsAvailable, 18, "Every step's belt tiles")
        XCTAssertTrue(session.drainEvents().contains(.tutorialFinished("level1")))
    }

    func testBadStepsAreRejected() throws {
        let base = try content()
        var tutorials = base.tutorials
        let bad = TutorialStep(id: "bad", text: "Waits forever", highlight: nil, when: "wait", grant: nil,
                               pauseSim: true, waitTicks: 10)
        tutorials["level1"] = [bad]
        do {
            _ = try ContentDatabase(items: base.items, sources: base.sources, buildings: base.buildings,
                                    recipes: base.recipes, rules: base.rules, legend: base.legend,
                                    levels: base.levels, tutorials: tutorials, maps: base.maps)
            XCTFail("Expected a problem")
        } catch let ContentError.invalid(problems) {
            XCTAssertTrue(problems.contains { $0.contains("pauses time") }, "\(problems)")
        }
    }

    // MARK: Scripted players for Levels 2 and 3

    func testScriptedPlayerCompletesLevel2() throws {
        let session = try GameSession(content: content(), level: "level2")
        XCTAssertEqual(session.tutorialStep?.id, "l2_start")
        XCTAssertEqual(session.place("brick_kiln", at: session.tutorialStep!.highlight!.tile!), .ok)
        XCTAssertEqual(session.place("clay_pit", at: session.tutorialStep!.highlight!.tile!), .ok)
        let kilnAt = try origin("brick_kiln", session)
        XCTAssertEqual(session.layBelt(from: GridPoint(13, 8), to: kilnAt), .ok)
        waitUntil(session) { session.tutorialStep?.id == "l2_logs" }
        let forest = session.tutorialStep!.highlight!.tile!
        XCTAssertEqual(session.place("lumber_camp", at: forest), .ok)
        XCTAssertEqual(session.layBelt(from: forest, to: kilnAt), .ok)
        waitUntil(session) { session.tutorialStep?.id == "l2_crate" }
        XCTAssertEqual(session.layBelt(from: kilnAt, to: try origin("storage_crate", session)), .ok)

        // Once the kiln runs short, the tutorial stops time and asks for Trace.
        waitUntil(session) { session.tutorialStep?.id == "l2_slow" }
        XCTAssertTrue(session.isPausedByTutorial)
        let trace = session.trace(.building(try id("brick_kiln", session)))
        XCTAssertEqual(trace.root.state, .slow)
        XCTAssertTrue(trace.root.reason.hasPrefix("Clay delivery is too slow"), trace.root.reason)

        let second = session.tutorialStep!.highlight!.tile!
        XCTAssertEqual(session.place("clay_pit", at: second), .ok)
        // Merge: end the second belt on the side of the first one.
        let firstBelt = try XCTUnwrap(session.world.belts.first { $0.pullsFrom == (try? self.id("clay_pit", session)) })
        XCTAssertEqual(session.layBelt(from: second, to: firstBelt.next), .ok)
        waitUntil(session) { session.isGoalReached }
        XCTAssertNil(session.tutorialStep)
    }

    func testScriptedPlayerCompletesLevel3() throws {
        let session = try GameSession(content: content(), level: "level3", seed: 3)
        XCTAssertEqual(session.tutorialStep?.id, "l3_start")
        for (type, x, y) in [("clay_pit", 36, 30), ("clay_pit", 37, 31), ("lumber_camp", 42, 23)] {
            XCTAssertEqual(session.place(BuildingTypeID(rawValue: type), at: GridPoint(x, y)), .ok, type)
        }
        XCTAssertEqual(session.place("brick_kiln", at: session.tutorialStep!.highlight!.tile!), .ok)
        XCTAssertEqual(session.place("sawmill", at: session.tutorialStep!.highlight!.tile!), .ok)
        XCTAssertEqual(session.tutorialStep?.id, "l3_saw_logs")
        let forest = session.tutorialStep!.highlight!.tile!
        XCTAssertEqual(session.place("lumber_camp", at: forest), .ok)
        XCTAssertEqual(session.layBelt(from: forest, to: GridPoint(47, 25)), .ok)
        for (a, b) in [((36, 30), (41, 28)), ((37, 31), (41, 28)), ((42, 23), (41, 28))] {
            XCTAssertEqual(session.layBelt(from: GridPoint(a.0, a.1), to: GridPoint(b.0, b.1)), .ok, "\(a)")
        }
        waitUntil(session) { session.tutorialStep?.id == "l3_yard" }
        XCTAssertEqual(session.place("builders_yard", at: session.tutorialStep!.highlight!.tile!), .ok)
        XCTAssertEqual(session.layBelt(from: GridPoint(41, 28), to: GridPoint(51, 28)), .ok)
        XCTAssertEqual(session.layBelt(from: GridPoint(47, 25), to: GridPoint(51, 28)), .ok)
        waitUntil(session) { session.tutorialStep?.id == "l3_trace" }
        let cottage = try id("cottage", session)
        session.trace(.building(cottage))
        waitUntil(session) { session.tutorialStep?.id == "l3_goal" }
        waitUntil(session, limit: 20000) { session.isGoalReached }
        XCTAssertNil(session.tutorialStep)
    }
}
