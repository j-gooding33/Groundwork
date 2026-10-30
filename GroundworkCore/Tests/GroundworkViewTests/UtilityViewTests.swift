import XCTest
import GroundworkCore
@testable import GroundworkView

final class UtilityViewTests: XCTestCase {
    private let field = [
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
        "~~~...........................",
    ]

    func testPipesJoinUpAndDryHomesShowAnIcon() throws {
        let session = try ViewTestSupport.session(field)
        let builder = try ViewTestSupport.builder()
        session.layPipe(from: GridPoint(5, 4), to: GridPoint(12, 4))
        session.layPipe(from: GridPoint(8, 1), to: GridPoint(8, 4))
        XCTAssertEqual(SceneBuilder.pipePiece(at: GridPoint(8, 4), world: session.world), "pipe_new")
        let statics = builder.staticLayer(session.world)
        XCTAssertTrue(statics.contains { $0.name == "pipe_new" })
        XCTAssertTrue(statics.allSatisfy { builder.atlas.has($0.name) })

        let pump = session.place("water_pump", at: GridPoint(3, 6))
        XCTAssertEqual(pump, .ok)
        let pumpID = try XCTUnwrap(session.world.building(at: GridPoint(3, 6))).id
        session.stock(pumpID, with: "brick", count: 8)
        session.advance(ticks: 1)
        let building = try XCTUnwrap(session.world.building(pumpID))
        XCTAssertEqual(builder.statusIcon(for: building, world: session.world), "status_no_power")
        let panel = HUDModel.panel(for: building, session: session)
        XCTAssertTrue(panel.lines.contains("No power: build a Waterwheel within 6 tiles"))
    }

    func testThePaletteOffersPipesInOpenWorlds() throws {
        let session = try GameSession.newWorld(content: try ViewTestSupport.content(),
                                               options: WorldOptions(name: "P", seed: 4))
        var input = InputController()
        input.use(.pipe)
        let hud = HUDModel(session: session, input: input)
        XCTAssertTrue(hud.palette.contains { $0.title == "Pipe" && $0.isSelected })
        XCTAssertTrue(hud.toolHint?.hasPrefix("Pipe:") ?? false)
        XCTAssertTrue(input.dragDraws)
    }
}
