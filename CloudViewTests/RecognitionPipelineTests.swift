import XCTest
import CoreGraphics
@testable import CloudView

/// The pure parts of the perception path: the cloud crop geometry, the
/// label matcher's ranking/floor/meta, and the label → drawing seam.
final class RecognitionPipelineTests: XCTestCase {

    // MARK: - Crop geometry

    func testCropIsSquareWithMarginAroundTheCloud() {
        let frame = CGSize(width: 1440, height: 1920)
        let box = CGRect(x: 500, y: 600, width: 400, height: 200)
        let rect = CloudCropRenderer.cropRect(for: box, in: frame)
        // Longest side 400 × (1 + 2·0.15) = 520, centered on the box.
        XCTAssertEqual(rect.width, rect.height)
        XCTAssertEqual(rect.width, 520, accuracy: 1)
        XCTAssertEqual(rect.midX, 700, accuracy: 1)
        XCTAssertEqual(rect.midY, 700, accuracy: 1)
    }

    func testCropSlidesInsideTheFrameAtTheEdge() {
        let frame = CGSize(width: 1440, height: 1920)
        let box = CGRect(x: 1300, y: 10, width: 300, height: 300) // hugging top-right
        let rect = CloudCropRenderer.cropRect(for: box, in: frame)
        XCTAssertGreaterThanOrEqual(rect.minX, 0)
        XCTAssertGreaterThanOrEqual(rect.minY, 0)
        XCTAssertLessThanOrEqual(rect.maxX, frame.width)
        XCTAssertLessThanOrEqual(rect.maxY, frame.height)
        XCTAssertEqual(rect.width, 390, accuracy: 1)
    }

    func testCropShrinksWhenTheCloudIsBiggerThanTheFrame() {
        let frame = CGSize(width: 1440, height: 1920)
        let box = CGRect(x: 0, y: 200, width: 1440, height: 900)
        let rect = CloudCropRenderer.cropRect(for: box, in: frame)
        XCTAssertEqual(rect.width, 1440, accuracy: 1)
        XCTAssertEqual(rect.height, 1440, accuracy: 1)
        XCTAssertEqual(rect.minX, 0, accuracy: 1)
        XCTAssertEqual(CloudCropRenderer.cropRect(for: .zero, in: frame), .zero)
    }

    // MARK: - Matcher

    private func unit(_ v: [Float]) -> [Float] { ImageEmbeddingEncoder.normalize(v) }

    func testMatcherRanksByCosineAndHonorsTheFloor() {
        let matcher = LabelEmbeddingMatcher(
            embeddings: [
                "bear":   unit([1, 0, 0, 0]),
                "rabbit": unit([0, 1, 0, 0]),
                "whale":  unit([0.7, 0.7, 0, 0]),
            ],
            confidenceFloor: 0.5
        )
        let ranked = matcher.ranked(imageEmbedding: unit([0.9, 0.1, 0, 0]))
        XCTAssertEqual(ranked.map(\.label), ["bear", "whale", "rabbit"])
        XCTAssertEqual(ranked[0].score, 0.994, accuracy: 0.01)

        // Clearly a bear: the sampled picks include it and nothing exceeds 5.
        let picks = matcher.match(imageEmbedding: unit([1, 0, 0, 0]))
        XCTAssertFalse(picks.isEmpty)
        XCTAssertLessThanOrEqual(picks.count, 5)
        XCTAssertTrue(picks.contains { $0.label == "bear" })

        // Nothing like any label → below the floor → [] ("Cool cloud!").
        XCTAssertTrue(matcher.match(imageEmbedding: unit([0, 0, 0, 1])).isEmpty)
        // Wrong dimensionality is refused, not crashed.
        XCTAssertTrue(matcher.match(imageEmbedding: [1, 0]).isEmpty)
    }

    func testNormalizeProducesUnitVectors() {
        let v = ImageEmbeddingEncoder.normalize([3, 4])
        XCTAssertEqual(v[0], 0.6, accuracy: 1e-6)
        XCTAssertEqual(v[1], 0.8, accuracy: 1e-6)
        XCTAssertEqual(ImageEmbeddingEncoder.normalize([0, 0]), [0, 0]) // no NaN
    }

    // MARK: - Label → drawing

    private let cloud = [
        CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.8, y: 0.3),
        CGPoint(x: 0.8, y: 0.7), CGPoint(x: 0.2, y: 0.7),
    ]

    func testLibraryDrawsANamedCreatureWithTheCloudAsBody() {
        let bear = CreatureSpec(
            label: "bear", category: "animals",
            silhouette: [Pt(x: 0, y: 0), Pt(x: 1, y: 0), Pt(x: 1, y: 1), Pt(x: 0, y: 1)],
            slots: ["ears": SlotSpec(required: true, probability: nil)]
        )
        let ears = DrawingPart(
            id: "bear-ears", kind: "ears", creatures: ["bear"], anchor: .top, scale: 0.3, display: nil,
            strokes: [DrawingTemplate.Stroke(role: "ear", order: 1, closed: false,
                                             points: [Pt(x: 0.3, y: 0.5), Pt(x: 0.7, y: 0.5)])]
        )
        let library = DrawingTemplateLibrary(creatures: [bear], parts: [ears])
        XCTAssertEqual(library.labels, ["bear"])

        let seed = VariationSeed(cloudShapeKey: "c", regionKey: "r", timeBucket: 1, deviceSalt: 7)
        let concept = library.makeDrawing(forLabel: "Bear ", cloudContour: cloud, variation: seed)
        XCTAssertNotNil(concept)
        XCTAssertEqual(concept?.name, "Bear")
        XCTAssertEqual(concept?.subject, "bear")
        // Body is the cloud's own contour (perception pick → cloud-as-body).
        let body = concept?.paths.first { $0.order == 0 }
        XCTAssertEqual(body?.points.count, cloud.count)
        XCTAssertEqual(concept?.paths.count, 2)

        // A label the library can't draw → nil (caller falls back).
        XCTAssertNil(library.makeDrawing(forLabel: "narwhal", cloudContour: cloud, variation: seed))
    }
}
