import XCTest
@testable import CloudView

final class DrawingCategoryTests: XCTestCase {

    func testAnimalKeywordsMapToAnimalsCategory() {
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Happy Cat Surfing"), .animals)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Excited Dog Playing"), .animals)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Polar Bear Skating"), .animals)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Silly Penguin Dancing"), .animals)
    }

    func testMythicalKeywordsMapToMythicalCategory() {
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Cool Dragon Flying"), .mythical)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Joyful Unicorn Dancing"), .mythical)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Phoenix Casting Spells"), .mythical)
    }

    func testLandmarkKeywordsMapToLandmarksCategory() {
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Eiffel Tower"), .landmarks)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Pyramid"), .landmarks)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Statue of Liberty"), .landmarks)
    }

    func testVehicleKeywordsMapToVehiclesCategory() {
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Cool Car Racing"), .vehicles)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Rocket Soaring"), .vehicles)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Helicopter"), .vehicles)
    }

    func testFoodKeywordsMapToFoodCategory() {
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Pizza Eating Snacks"), .food)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Donut Floating"), .food)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Ice Cream Melting"), .food)
    }

    func testCategorizationIsCaseInsensitive() {
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "DRAGON"), .mythical)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "dragon"), .mythical)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Dragon"), .mythical)
    }

    func testUnknownSubjectsFallBackToNature() {
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Sunset"), .nature)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: "Mystery Object"), .nature)
        XCTAssertEqual(DrawingCategory.categorize(drawingName: ""), .nature)
    }

    func testFirstMatchWinsWhenMultipleKeywordsPresent() {
        // The classifier checks categories in order. Animals are checked before
        // mythical, so a name with both should land in animals — a known property
        // of the current implementation we want to preserve.
        XCTAssertEqual(
            DrawingCategory.categorize(drawingName: "Dragon-cat hybrid"),
            .animals
        )
    }
}
