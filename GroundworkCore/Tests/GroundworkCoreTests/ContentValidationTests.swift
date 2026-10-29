import XCTest
@testable import GroundworkCore

final class ContentValidationTests: XCTestCase {
    func testFixtureIsValid() {
        XCTAssertNoThrow(try TestSupport.fixture())
    }

    func testUnknownItemInRecipeIsRejected() {
        var recipe = TestSupport.fireBrick
        recipe.inputs.append(RecipeInput(item: "unobtainium", count: 1, role: .material))
        XCTAssertContentProblem("unknown item 'unobtainium'") {
            try TestSupport.fixture(recipes: [TestSupport.gatherClay, recipe])
        }
    }

    func testMissingDescriptionIsRejected() {
        var clay = TestSupport.clayItem
        clay.description = ""
        XCTAssertContentProblem("Item 'clay' needs a description") {
            try TestSupport.fixture(items: [clay, TestSupport.brickItem])
        }
    }

    func testDuplicateIDIsRejected() {
        XCTAssertContentProblem("Duplicate item id 'clay'") {
            try TestSupport.fixture(items: [TestSupport.clayItem, TestSupport.clayItem, TestSupport.brickItem])
        }
    }

    func testItemWithNoRecipeBreaksTheTraceRule() {
        let orphan = ItemDef(id: "glass", name: "Glass", plural: "glass", tier: .processed, description: "An item.")
        XCTAssertContentProblem("Item 'glass' cannot be traced back to a natural source") {
            try TestSupport.fixture(items: [TestSupport.clayItem, TestSupport.brickItem, orphan])
        }
    }

    func testCycleWithNoSourceBreaksTheTraceRule() {
        let a = ItemDef(id: "a", name: "A", plural: "a", tier: .processed, description: "An item.")
        let b = ItemDef(id: "b", name: "B", plural: "b", tier: .processed, description: "An item.")
        let aToB = RecipeDef(id: "a_to_b", building: "kiln", source: nil, durationTicks: 10, power: 0, level: 1,
                             inputs: [RecipeInput(item: "a", count: 1, role: .material)],
                             outputs: [ItemStack(item: "b", count: 1)])
        let bToA = RecipeDef(id: "b_to_a", building: "kiln", source: nil, durationTicks: 10, power: 0, level: 1,
                             inputs: [RecipeInput(item: "b", count: 1, role: .material)],
                             outputs: [ItemStack(item: "a", count: 1)])
        XCTAssertContentProblem("Item 'a' cannot be traced back") {
            try TestSupport.fixture(
                items: [TestSupport.clayItem, TestSupport.brickItem, a, b],
                buildings: [TestSupport.building("clay_pit", recipes: ["gather_clay"], placeOn: .source),
                            TestSupport.building("kiln", recipes: ["brick", "a_to_b", "b_to_a"])],
                recipes: [TestSupport.gatherClay, TestSupport.fireBrick, aToB, bToA])
        }
    }

    func testRecipeFromNothingIsRejected() {
        var recipe = TestSupport.gatherClay
        recipe.source = nil
        XCTAssertContentProblem("would appear from nothing") {
            try TestSupport.fixture(recipes: [recipe, TestSupport.fireBrick])
        }
    }

    func testGatherRecipeWithUnknownSourceIsRejected() {
        var recipe = TestSupport.gatherClay
        recipe.source = "volcano"
        XCTAssertContentProblem("unknown source 'volcano'") {
            try TestSupport.fixture(recipes: [recipe, TestSupport.fireBrick])
        }
    }

    func testZeroDurationIsRejected() {
        var recipe = TestSupport.fireBrick
        recipe.durationTicks = 0
        XCTAssertContentProblem("at least 1 tick") {
            try TestSupport.fixture(recipes: [TestSupport.gatherClay, recipe])
        }
    }

    func testBuildingListingAnotherBuildingsRecipeIsRejected() {
        XCTAssertContentProblem("which belongs to 'kiln'") {
            try TestSupport.fixture(buildings: [
                TestSupport.building("clay_pit", recipes: ["gather_clay", "brick"], placeOn: .source),
                TestSupport.building("kiln", recipes: ["brick"]),
            ])
        }
    }

    func testLegendWithUnknownSourceIsRejected() {
        var legend = TestSupport.legend
        legend["x"] = LegendEntry(terrain: .rock, source: "volcano")
        XCTAssertContentProblem("Map legend 'x' names unknown source 'volcano'") {
            try TestSupport.fixture(legend: legend)
        }
    }

    func testEveryProblemIsReportedAtOnce() {
        var recipe = TestSupport.fireBrick
        recipe.durationTicks = 0
        recipe.building = "nowhere"
        do {
            _ = try TestSupport.fixture(recipes: [TestSupport.gatherClay, recipe])
            XCTFail("Expected problems")
        } catch let ContentError.invalid(problems) {
            XCTAssertGreaterThanOrEqual(problems.count, 2, "\(problems)")
        } catch {
            XCTFail("\(error)")
        }
    }
}
