import XCTest
import GroundworkCore
@testable import GroundworkView

final class ViewModelTests: XCTestCase {
    // MARK: Atlas and camera

    func testAtlasRectsFlipForSpriteKit() throws {
        let atlas = try ViewTestSupport.atlas()
        let r = try XCTUnwrap(atlas.sprites["cottage"])
        let n = try XCTUnwrap(atlas.normalizedRect("cottage"))
        XCTAssertEqual(n.y, 1 - Double(r.y + r.h) / Double(atlas.height), accuracy: 1e-9)
        XCTAssertEqual(atlas.variantCount("cottage"), 3)
        XCTAssertEqual(atlas.frames("belt_h"), ["belt_h", "belt_h_f1", "belt_h_f2", "belt_h_f3"])
    }

    func testCameraConvertsBothWays() {
        let camera = Camera(mapWidth: 64, mapHeight: 64, focus: GridPoint(30, 30))
        for p in [GridPoint(30, 30), GridPoint(0, 63), GridPoint(12, 5)] {
            XCTAssertEqual(camera.tile(at: camera.center(of: p)), p)
        }
        let middle = camera.scenePoint(fromView: ScenePoint(Camera.viewWidth / 2, Camera.viewHeight / 2))
        XCTAssertEqual(camera.tile(at: middle), GridPoint(30, 30))
    }

    func testCameraStaysOnTheMapAndPinchKeepsTheFingerPoint() {
        var camera = Camera(mapWidth: 64, mapHeight: 64, focus: GridPoint(0, 0))
        XCTAssertGreaterThanOrEqual(camera.visible.minX, -Camera.tile * 2 - 0.001)
        let finger = ScenePoint(100, 80)
        let before = camera.scenePoint(fromView: finger)
        camera.pan(byView: -200, 100)
        camera.pinch(1.5, aroundView: finger)
        XCTAssertLessThanOrEqual(camera.zoom, Camera.maxZoom)
        var still = Camera(mapWidth: 64, mapHeight: 64, focus: GridPoint(32, 32))
        let point = still.scenePoint(fromView: finger)
        still.pinch(2, aroundView: finger)
        XCTAssertEqual(still.scenePoint(fromView: finger).x, point.x, accuracy: 0.001)
        XCTAssertEqual(still.scenePoint(fromView: finger).y, point.y, accuracy: 0.001)
        _ = before
    }

    // MARK: Input

    func testBuildToolPlacesAndExplainsRefusals() throws {
        let session = try ViewTestSupport.session([".c....", "......", "......"])
        var input = InputController()
        input.choose(.build("clay_pit"))
        XCTAssertEqual(input.tap(GridPoint(1, 0), session: session), Feedback(haptic: .light))
        let refused = input.tap(GridPoint(3, 2), session: session)
        XCTAssertEqual(refused.toast, "The Clay Pit needs a clay deposit")
        XCTAssertEqual(refused.haptic, .warning)
        input.choose(.build("clay_pit"))
        XCTAssertEqual(input.tool, .none, "Tapping the selected tool again puts it down")
    }

    func testTwoByTwoBuildingsCentreUnderTheFinger() throws {
        let session = try ViewTestSupport.session(["......", "......", "......"])
        var input = InputController()
        input.use(.build("brick_kiln"))
        _ = input.tap(GridPoint(2, 1), session: session)
        XCTAssertEqual(session.world.building(at: GridPoint(2, 1))?.origin, GridPoint(2, 1))
    }

    func testTappingWithNoToolCarriesItems() throws {
        let session = try ViewTestSupport.session([".c......", "........", "........"])
        session.place("clay_pit", at: GridPoint(1, 0))
        session.place("brick_kiln", at: GridPoint(5, 0))
        session.advance(ticks: 60)
        var input = InputController()
        _ = input.tap(GridPoint(1, 0), session: session)
        XCTAssertEqual(session.world.hand?.item, "clay")
        XCTAssertNotNil(input.selection)
        _ = input.tap(GridPoint(6, 1), session: session)
        XCTAssertNil(session.world.hand)
        XCTAssertEqual(session.world.building(at: GridPoint(5, 0))?.input.count(of: "clay"), 2)
    }

    func testBeltDragShowsAGhostThenLays() throws {
        let session = try ViewTestSupport.session(["........", "........"])
        var input = InputController()
        input.use(.belt)
        XCTAssertTrue(input.dragDraws)
        input.dragBegan(GridPoint(0, 0), session: session)
        input.dragMoved(GridPoint(5, 0), session: session)
        XCTAssertEqual(input.ghost.count, 6)
        XCTAssertEqual(input.dragEnded(GridPoint(5, 0), session: session).haptic, .light)
        XCTAssertTrue(input.ghost.isEmpty)
        XCTAssertEqual(session.world.belts.count, 6)
    }

    func testDemolishAndTrace() throws {
        let session = try ViewTestSupport.session(["......", "......", "......"])
        session.place("brick_kiln", at: GridPoint(1, 0))
        let kiln = try XCTUnwrap(session.world.building(at: GridPoint(1, 0)))
        session.stock(kiln.id, with: "clay", count: 4)
        session.advance(ticks: 30)
        var input = InputController()
        input.use(.trace)
        let feedback = input.tap(GridPoint(1, 0), session: session)
        XCTAssertEqual(feedback.toast, "Build a Lumber Camp")
        XCTAssertNotNil(HUDModel(session: session, input: input).traceMarker)
        input.use(.demolish)
        _ = input.tap(GridPoint(2, 1), session: session)
        XCTAssertNil(session.world.building(kiln.id))
    }

    // MARK: Effects

    func testEffectsShowRestraint() throws {
        let session = try ViewTestSupport.session([".c....", "......"])
        var planner = EffectPlanner()
        session.place("clay_pit", at: GridPoint(1, 0))
        let placed = planner.plan(session.drainEvents(), session: session)
        XCTAssertTrue(placed.contains(.sound(.place)))
        XCTAssertTrue(placed.contains { if case .placed = $0 { return true }; return false })
        var floats = 0
        for _ in 0..<10 {
            session.advance(ticks: 30)
            for effect in planner.plan(session.drainEvents(), session: session) {
                if case .floatText = effect { floats += 1 }
            }
            let pit = session.world.buildings[0].id
            session.pickUp(from: pit)
            if let crate = session.world.buildings.first(where: { $0.type == "storage_crate" }) {
                session.drop(into: crate.id)
            }
        }
        XCTAssertEqual(floats, EffectPlanner.floatLimit, "Floating +1 only for the first few items")
    }

    func testGoalCelebrates() throws {
        let session = try GameSession(content: try ViewTestSupport.content(), level: "level1")
        var planner = EffectPlanner()
        let effects = planner.plan([.goalReached("level1")], session: session)
        XCTAssertTrue(effects.contains(.celebrate))
        XCTAssertTrue(effects.contains(.haptic(.double)))
        XCTAssertEqual(planner.musicLayers, 2)
    }

    // MARK: HUD

    func testLevel1StartsWithThreeButtonsAndOneBuilding() throws {
        let session = try GameSession(content: try ViewTestSupport.content(), level: "level1")
        let hud = HUDModel(session: session, input: InputController())
        XCTAssertEqual(hud.tabs, [.build, .trace, .undo])
        XCTAssertEqual(hud.palette.map(\.title), ["Clay Pit"])
        XCTAssertEqual(hud.tutorial?.text, "Start with the ground.")
        XCTAssertEqual(hud.tutorial?.tile, GridPoint(37, 29))
        XCTAssertEqual(hud.goal?.text, "Fill the foundation with bricks")
        XCTAssertEqual(hud.clock, "Day 1, 07:40")
        XCTAssertTrue(hud.paused)
    }

    func testBeltButtonAppearsWithItsCount() throws {
        let session = try GameSession(content: try ViewTestSupport.content(), level: "level1")
        session.setBeltsAvailable(12)
        let hud = HUDModel(session: session, input: InputController())
        XCTAssertEqual(hud.palette.last?.title, "Belt")
        XCTAssertEqual(hud.palette.last?.badge, "12")
    }

    func testSelectionPanelExplainsAStuckKiln() throws {
        let session = try ViewTestSupport.session(["......", "......"])
        session.place("brick_kiln", at: GridPoint(1, 0))
        let kiln = try XCTUnwrap(session.world.building(at: GridPoint(1, 0)))
        session.stock(kiln.id, with: "clay", count: 20)
        session.stock(kiln.id, with: "log", count: 6)
        session.advance(ticks: 140)          // 3 batches started, 3 logs left
        var input = InputController()
        _ = input.longPress(GridPoint(1, 0), session: session)
        let panel = try XCTUnwrap(HUDModel(session: session, input: input).selection)
        XCTAssertEqual(panel.title, "Brick Kiln")
        XCTAssertTrue(panel.lines.contains { $0.hasPrefix("Logs run out in") }, "\(panel.lines)")
        session.advance(ticks: 200)
        let stuck = try XCTUnwrap(HUDModel(session: session, input: input).selection)
        XCTAssertEqual(stuck.status, "Waiting for logs")
        XCTAssertTrue(stuck.isBlocked)
    }

    // MARK: Day, night, autosave

    func testDayAndNight() {
        XCTAssertFalse(DayNight(tick: 0).isNight)
        XCTAssertEqual(DayNight(tick: 0).clockText, "Day 1, 07:40")
        let noon = UInt64((0.5 - DayNight.startPhase) * Double(DayNight.dayTicks))
        XCTAssertEqual(DayNight(tick: noon).tint, .none)
        let night = UInt64((0.9 - DayNight.startPhase) * Double(DayNight.dayTicks))
        XCTAssertTrue(DayNight(tick: night).isNight)
        XCTAssertGreaterThan(DayNight(tick: night).tint.amount, 0.3)
        XCTAssertEqual(DayNight(tick: DayNight.dayTicks).day, 2)
    }

    func testAutosaveEveryThirtySeconds() {
        var policy = AutosavePolicy()
        XCTAssertFalse(policy.shouldSave(now: 100))
        XCTAssertFalse(policy.shouldSave(now: 129))
        XCTAssertTrue(policy.shouldSave(now: 130.5))
        policy.didSave(now: 130.5)
        XCTAssertFalse(policy.shouldSave(now: 140))
    }
}
