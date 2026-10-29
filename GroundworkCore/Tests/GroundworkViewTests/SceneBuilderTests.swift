import XCTest
import GroundworkCore
@testable import GroundworkView

final class SceneBuilderTests: XCTestCase {
    func testEverySpriteTheSceneUsesExistsInTheAtlas() throws {
        let builder = try ViewTestSupport.builder()
        let level1 = try GameSession(content: builder.content)
        let town = try ViewTestSupport.town(ticks: 7000)
        for session in [level1, town] {
            for ticks in [0, 1800, 2100] {                     // day, then into the night
                session.advance(ticks: ticks)
                let world = session.world
                var sprites = builder.staticLayer(world) + builder.dynamicLayer(world, time: RenderTime(fraction: 0.5, seconds: 1))
                var input = InputController()
                input.use(.trace)
                if let kiln = world.buildings.first(where: { $0.type == "brick_kiln" }) {
                    _ = input.tap(kiln.origin, session: session)
                }
                sprites += builder.overlayLayer(world, input: input, hud: HUDModel(session: session, input: input),
                                                time: RenderTime())
                for sprite in sprites {
                    XCTAssertTrue(builder.atlas.has(sprite.name), "\(sprite.id) asks for missing sprite \(sprite.name)")
                    for frame in sprite.frames {
                        XCTAssertTrue(builder.atlas.has(frame), "\(sprite.id) frame \(frame) is missing")
                    }
                }
                XCTAssertEqual(Set(sprites.map(\.id)).count, sprites.count, "Sprite ids must be unique")
            }
        }
    }

    func testShoreTilesGetWaterEdges() throws {
        let builder = try ViewTestSupport.builder()
        let map = try TileMap.parse("~~~\n,,,\n...", content: builder.content)
        XCTAssertEqual(builder.edgeOverlays(GridPoint(1, 1), map: map), ["edge_water_n"])
        // Grass below sand gets the sand fringe; the water is not next to it.
        XCTAssertEqual(builder.edgeOverlays(GridPoint(1, 2), map: map), ["edge_shore_n", "edge_fog_s"])
        XCTAssertEqual(builder.edgeOverlays(GridPoint(1, 0), map: map), ["edge_fog_n"], "The map edge fades to paper")
    }

    func testCornersOnlyWhenNoSideCoversThem() throws {
        let builder = try ViewTestSupport.builder()
        let map = try TileMap.parse("~....\n.....\n.....", content: builder.content)
        XCTAssertEqual(builder.edgeOverlays(GridPoint(1, 1), map: map), ["edge_water_nw"])
        XCTAssertEqual(builder.edgeOverlays(GridPoint(1, 0), map: map), ["edge_water_w", "edge_fog_n"])
    }

    func testBeltPiecesAndFlips() throws {
        let session = try ViewTestSupport.session(["..........", "..........", "..........", ".........."])
        XCTAssertEqual(session.layBelt(from: GridPoint(1, 0), to: GridPoint(5, 3)), .ok)
        let world = session.world
        let names = world.belts.map { SceneBuilder.beltPiece($0, in: world).name }
        XCTAssertEqual(names.filter { $0.count == 7 && $0.hasPrefix("belt_") && $0 != "belt_h" }.count, 1,
                       "One corner where the belt turns: \(names)")
        let west = try ViewTestSupport.session([".....", ".....", "....."])
        XCTAssertEqual(west.layBelt(from: GridPoint(4, 1), to: GridPoint(0, 1)), .ok)
        XCTAssertTrue(west.world.belts.allSatisfy { SceneBuilder.beltPiece($0, in: west.world) == ("belt_h", true, false) })
    }

    func testItemsGlideForwardWithinTheirTile() throws {
        let builder = try ViewTestSupport.builder()
        let session = try ViewTestSupport.session([".c.........", "..........."])
        let pit = try XCTUnwrap({ () -> EntityID? in
            session.place("clay_pit", at: GridPoint(1, 0))
            return session.world.building(at: GridPoint(1, 0))?.id
        }())
        session.place("storage_crate", at: GridPoint(10, 0))
        XCTAssertEqual(session.layBelt(from: GridPoint(1, 0), to: GridPoint(10, 0)), .ok)
        session.advance(ticks: 61)
        _ = pit
        func items(_ fraction: Double) -> [Sprite] {
            builder.dynamicLayer(session.world, time: RenderTime(fraction: fraction)).filter { $0.id.hasPrefix("item:") }
        }
        let before = items(0), after = items(0.9)
        XCTAssertFalse(before.isEmpty)
        for (a, b) in zip(before, after) {
            XCTAssertGreaterThanOrEqual(b.x, a.x, "Items only move the way the belt runs")
            let tile = session.world.belts.first { "item:\($0.point.x),\($0.point.y)" == a.id.split(separator: ":").prefix(2).joined(separator: ":") }
            if let tile {
                let c = Camera.center(of: tile.point, w: 1, h: 1, mapHeight: session.world.map.height)
                XCTAssertLessThanOrEqual(abs(b.x - c.x), Camera.tile / 2 + 0.01)
            }
        }
    }

    func testBuildingStagesAndNight() throws {
        let builder = try ViewTestSupport.builder()
        let session = try GameSession(content: builder.content)
        let foundation = try XCTUnwrap(session.world.buildings.first { $0.type == "foundation" })
        XCTAssertEqual(builder.spriteName(for: foundation, night: false), "foundation" + (foundation.id % 2 == 1 ? "_v1" : ""))
        session.stock(foundation.id, with: "brick", count: 4)
        XCTAssertEqual(builder.spriteName(for: session.world.building(foundation.id)!, night: false), "foundation_2")

        let town = try ViewTestSupport.town(ticks: 7000)
        let home = try XCTUnwrap(town.world.buildings.first { $0.type == "cottage" && $0.isBuilt })
        XCTAssertTrue(builder.spriteName(for: home, night: true).hasSuffix("_night"))
        let nightSprites = builder.dynamicLayer(town.world, time: RenderTime())
        let isNight = DayNight(tick: town.world.tick).isNight
        XCTAssertEqual(nightSprites.contains { $0.id == "g:\(home.id)" }, isNight, "Windows glow only at night")
    }

    func testBlockedMachinesPulseAmber() throws {
        let builder = try ViewTestSupport.builder()
        let session = try ViewTestSupport.session(["......", "......"])
        session.place("brick_kiln", at: GridPoint(1, 0))
        let kiln = try XCTUnwrap(session.world.building(at: GridPoint(1, 0)))
        session.stock(kiln.id, with: "clay", count: 4)
        session.advance(ticks: 30)
        let sprite = try XCTUnwrap(builder.dynamicLayer(session.world, time: RenderTime(seconds: 0.35)).first { $0.id == "b:\(kiln.id)" })
        XCTAssertLessThan(sprite.alpha, 1)
        XCTAssertGreaterThan(sprite.tint.amount, 0)
    }

    func testWalkersStayOffBuildings() throws {
        let builder = try ViewTestSupport.builder()
        let town = try ViewTestSupport.town(ticks: 6000)
        var seen = 0
        for _ in 0..<40 {
            town.advance(ticks: 7)
            for walker in Walkers.sprites(world: town.world, content: builder.content, atlas: builder.atlas, time: RenderTime()) {
                let camera = Camera(mapWidth: town.world.map.width, mapHeight: town.world.map.height)
                let tile = camera.tile(at: ScenePoint(walker.x, walker.y - 3))
                XCTAssertNil(town.world.building(at: tile), "\(walker.id) walked into a building at \(tile)")
                seen += 1
            }
        }
        XCTAssertGreaterThan(seen, 0, "The town has villagers")
    }

    func testFrameSelection() {
        var sprite = Sprite(id: "x", name: "a", x: 0, y: 0, z: 0)
        sprite.frames = ["a", "b", "c"]
        sprite.frameSeconds = 0.5
        XCTAssertEqual(sprite.frame(at: 0), "a")
        XCTAssertEqual(sprite.frame(at: 0.6), "b")
        XCTAssertEqual(sprite.frame(at: 1.6), "a")
    }

    func testUndrawnLandIsBlankPaper() throws {
        let builder = try ViewTestSupport.builder()
        let session = try GameSession(content: builder.content)
        let sprites = builder.staticLayer(session.world)
        func base(_ x: Int, _ y: Int) -> String? { sprites.first { $0.id == "t:\(x),\(y)" }?.name }
        XCTAssertEqual(base(37, 29), "terrain_clay_ground", "The starting clay is drawn")
        XCTAssertEqual(base(37, 50), "terrain_paper_fog", "Far land waits for a later chapter")
        XCTAssertFalse(sprites.contains { $0.id == "d:50,10" }, "No trees on blank paper")
        XCTAssertTrue(sprites.contains { $0.name.hasPrefix("edge_fog") }, "The drawn land fades softly into paper")
    }

    func testLandmarksAreNamedUntilUsed() throws {
        let builder = try ViewTestSupport.builder()
        let session = try GameSession(content: builder.content)
        XCTAssertEqual(builder.mapLabels(session.world).map(\.text), ["Clay", "Forest", "Lake", "Foundation"])
        session.place("clay_pit", at: GridPoint(37, 29))
        XCTAssertFalse(builder.mapLabels(session.world).map(\.text).contains("Clay"), "Gone once a pit is dug")
        let later = try GameSession(content: builder.content, chapter: 1)
        XCTAssertFalse(builder.mapLabels(later.world).map(\.text).contains("Lake"), "Some names are for chapter 1 only")
    }
}
