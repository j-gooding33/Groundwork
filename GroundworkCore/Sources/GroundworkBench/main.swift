// Times the simulation on a world far busier than Prototype 1 needs.
// Run in release mode: swift run -c release GroundworkBench
// Linux numbers are only a rough guide to an iPhone.
import Foundation
import GroundworkCore

let dataURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("Data")
let content = try ContentDatabase.load(from: dataURL)

let lines = 20
let length = 100
let width = length + 8
let height = lines * 3 + 2
let map = TileMap(width: width, height: height, terrain: Array(repeating: .grass, count: width * height))
let session = GameSession(content: content, map: map, seed: 1)
let clock = ContinuousClock()

func ms(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
}

// Twenty long belts, each from a well-stocked crate to an empty one.
let layTime = clock.measure {
    for line in 0..<lines {
        let y = 1 + line * 3
        session.place("storage_crate", at: GridPoint(0, y))
        session.place("storage_crate", at: GridPoint(length + 2, y))
        if let source = session.world.building(at: GridPoint(0, y)) {
            session.stock(source.id, with: "clay", count: 100_000)
        }
        session.layBelt(from: GridPoint(0, y), to: GridPoint(length + 2, y))
    }
}
print("World \(width)x\(height), \(session.world.belts.count) belt tiles, \(session.world.buildings.count) buildings")
print(String(format: "Placing %d crates and laying %d belts: %.1f ms total", lines * 2, lines, ms(layTime)))

func measureTicks(_ ticks: Int, label: String) {
    let time = clock.measure { session.advance(ticks: ticks) }
    let items = session.world.belts.reduce(0) { $0 + $1.items.count }
    let perTick = ms(time) / Double(ticks)
    print(String(format: "%@: %d items on belts, %.3f ms per tick (%.0f ticks per second; the game needs 10)",
                 label, items, perTick, 1000 / perTick))
}

measureTicks(200, label: "Filling   ")
measureTicks(600, label: "Flowing   ")
measureTicks(1000, label: "Packed    ")

let traceTime = clock.measure {
    for _ in 0..<100 {
        if let sink = session.world.building(at: GridPoint(length + 2, 1)) { _ = session.trace(.building(sink.id)) }
        _ = session.trace(.item("brick"))
    }
}
print(String(format: "Trace: %.3f ms per call", ms(traceTime) / 200))

let commandTime = clock.measure {
    for k in 0..<50 {
        session.place("storage_crate", at: GridPoint(width - 3, 1 + (k % lines) * 3 + 1))
        session.undo()
    }
}
print(String(format: "Place + undo on this world: %.3f ms per command", ms(commandTime) / 100))

var saved = Data()
let saveTime = clock.measure { saved = (try? session.save()) ?? Data() }
var loaded: GameSession?
let loadTime = clock.measure { loaded = try? GameSession.load(saved, content: content) }
print(String(format: "Save: %.0f KB in %.1f ms; load in %.1f ms (%@)", Double(saved.count) / 1024, ms(saveTime),
             ms(loadTime), loaded?.world == session.world ? "identical" : "MISMATCH"))
