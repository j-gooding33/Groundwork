import Foundation
import XCTest
@testable import GroundworkCore

final class SeededRNGTests: XCTestCase {
    func testMatchesPublishedSplitMix64Output() {
        var rng = SplitMix64(seed: 0)
        XCTAssertEqual(rng.next(), 0xE220_A839_7B1D_CDAF)
        XCTAssertEqual(rng.next(), 0x6E78_9E6A_A1B9_65F4)
    }

    func testSameSeedGivesSameSequence() {
        var a = SplitMix64(seed: 1028)
        var b = SplitMix64(seed: 1028)
        for _ in 0..<100 { XCTAssertEqual(a.next(), b.next()) }
    }

    func testDifferentSeedsDiffer() {
        var a = SplitMix64(seed: 1)
        var b = SplitMix64(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testSequenceContinuesAfterSaveAndLoad() throws {
        var original = SplitMix64(seed: 42)
        for _ in 0..<10 { _ = original.next() }
        var restored = try JSONDecoder().decode(SplitMix64.self, from: JSONEncoder().encode(original))
        for _ in 0..<100 { XCTAssertEqual(original.next(), restored.next()) }
    }

    func testNextIntStaysInRange() {
        var rng = SplitMix64(seed: 7)
        var seen = Set<Int>()
        for _ in 0..<1000 {
            let value = rng.nextInt(below: 6)
            XCTAssertTrue((0..<6).contains(value))
            seen.insert(value)
        }
        XCTAssertEqual(seen, Set(0..<6))
    }
}
