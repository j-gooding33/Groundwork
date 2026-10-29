import XCTest
import GroundworkCore
@testable import GroundworkView

/// Laying belts should be forgiving, and what a belt connects should be visible.
final class BeltFeedbackTests: XCTestCase {
    /// The start of the world with the pit and kiln down and belts in hand.
    private func pitAndKiln() throws -> GameSession {
        let session = try GameSession(content: try ViewTestSupport.content())
        session.skipTutorial()
        XCTAssertEqual(session.place("clay_pit", at: GridPoint(37, 29)), .ok)
        XCTAssertEqual(session.place("brick_kiln", at: GridPoint(40, 28)), .ok)
        return session
    }

    func testLettingGoOnTheTopOfAKilnStillReachesIt() throws {
        let session = try pitAndKiln()
        var input = InputController()
        input.use(.belt)
        input.dragBegan(GridPoint(37, 29), session: session)
        // The kiln is drawn a tile taller than its footprint: (41, 27) is its roof.
        let feedback = input.dragEnded(GridPoint(41, 27), session: session)
        XCTAssertNil(feedback.toast)
        XCTAssertTrue(SceneBuilder.deadEnds(session.world).isEmpty, "The belt reaches the kiln, not the grass beside it")
        XCTAssertTrue(session.world.belts.contains { session.world.building(at: $0.next)?.type == "brick_kiln" })
    }

    func testTapOneBuildingThenAnother() throws {
        let session = try pitAndKiln()
        var input = InputController()
        input.use(.belt)
        XCTAssertEqual(input.tap(GridPoint(37, 29), session: session).toast, "Now tap where the belt should go")
        let overlay = try ViewTestSupport.builder().overlayLayer(session.world, input: input,
                                                                 hud: HUDModel(session: session, input: input),
                                                                 time: RenderTime())
        XCTAssertTrue(overlay.contains { $0.id == "beltstart" }, "The chosen building is outlined")
        _ = input.tap(GridPoint(40, 28), session: session)
        XCTAssertTrue(session.world.belts.contains { session.world.building(at: $0.next)?.type == "brick_kiln" })
        XCTAssertNil(input.dragStart)
    }

    func testABeltIntoNothingIsMarkedAndExplained() throws {
        let session = try pitAndKiln()
        var input = InputController()
        input.use(.belt)
        input.dragBegan(GridPoint(37, 29), session: session)
        let feedback = input.dragEnded(GridPoint(37, 25), session: session)
        XCTAssertEqual(feedback.toast, "That belt doesn't reach anything yet")
        XCTAssertEqual(SceneBuilder.deadEnds(session.world), [GridPoint(37, 25)])
        let builder = try ViewTestSupport.builder()
        let sprites = builder.dynamicLayer(session.world, time: RenderTime())
        XCTAssertTrue(sprites.contains { $0.name == "status_dead_end" })
        XCTAssertTrue(sprites.contains { $0.id.hasPrefix("port:out:") }, "An arrow shows where items leave the pit")
    }

    func testPortsAndJoinsAreDrawn() throws {
        let session = try pitAndKiln()
        XCTAssertEqual(session.layBelt(from: GridPoint(37, 29), to: GridPoint(40, 28)), .ok)
        XCTAssertEqual(session.place("clay_pit", at: GridPoint(37, 31)), .ok)
        let first = try XCTUnwrap(session.world.belts.first { $0.pullsFrom != nil })
        XCTAssertEqual(session.layBelt(from: GridPoint(37, 31), to: first.next), .ok)
        let sprites = try ViewTestSupport.builder().dynamicLayer(session.world, time: RenderTime())
        XCTAssertTrue(sprites.contains { $0.id.hasPrefix("port:in:") }, "An arrow shows where items go into the kiln")
        XCTAssertTrue(sprites.contains { $0.name.hasPrefix("belt_join") }, "A merge looks like a junction")
    }

    func testBeltToolShowsWhatEachBuildingTakesAndMakes() throws {
        let session = try pitAndKiln()
        let builder = try ViewTestSupport.builder()
        let io = SceneBuilder.io(of: "brick_kiln", content: session.content)
        XCTAssertEqual(io.takes, ["clay", "log"])
        XCTAssertEqual(io.gives, ["brick"])
        var input = InputController()
        input.use(.belt)
        let overlay = builder.overlayLayer(session.world, input: input, hud: HUDModel(session: session, input: input),
                                           time: RenderTime())
        XCTAssertTrue(overlay.contains { $0.id.hasPrefix("io:") && $0.name == "item_brick" })
        let kiln = try XCTUnwrap(session.world.buildings.first { $0.type == "brick_kiln" })
        input.cancel()
        _ = input.longPress(kiln.origin, session: session)
        let panel = try XCTUnwrap(HUDModel(session: session, input: input).selection)
        XCTAssertTrue(panel.lines.contains("Takes clay, logs"))
        XCTAssertTrue(panel.lines.contains("Makes bricks"))
    }

    // MARK: Gestures

    func testOneFingerMovesTheMapOnTheFirstStep() throws {
        let session = try GameSession(content: try ViewTestSupport.content())
        var input = InputController()
        var camera = Camera(mapWidth: 64, mapHeight: 64, focus: session.level?.focus, zoom: 1.5)
        let before = camera.center
        _ = GestureRouter.apply(.pan(dx: 60, dy: 0), input: &input, camera: &camera,
                                mapping: ViewMapping(width: 852, height: 393), session: session)
        XCTAssertNotEqual(camera.center, before)
    }

    func testTwoFingersMoveTheMapEvenWithTheBeltTool() throws {
        let session = try pitAndKiln()
        var input = InputController()
        input.use(.belt)
        var camera = Camera(mapWidth: 64, mapHeight: 64, focus: GridPoint(37, 29), zoom: 1.5)
        let mapping = ViewMapping(width: 852, height: 393)
        let before = camera.center
        _ = GestureRouter.apply(.pan(dx: 60, dy: 0), input: &input, camera: &camera, mapping: mapping, session: session)
        XCTAssertEqual(camera.center, before, "One finger lays a belt instead")
        _ = GestureRouter.apply(.twoFingerPan(dx: 60, dy: 0), input: &input, camera: &camera, mapping: mapping,
                                session: session)
        XCTAssertNotEqual(camera.center, before)
    }

    func testPinchingSendsATwoFingerPan() {
        var t = TouchTracker()
        _ = t.began(1, ViewPoint(0, 0), time: 0)
        _ = t.began(2, ViewPoint(100, 0), time: 0)
        let gestures = t.moved(1, ViewPoint(20, 10), time: 0.1)
        XCTAssertTrue(gestures.contains { if case .twoFingerPan = $0 { return true }; return false })
    }
}
