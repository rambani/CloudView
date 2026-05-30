import XCTest
import CoreGraphics
import simd
@testable import CloudView

final class RecognitionToDrawingAdapterTests: XCTestCase {

    func testCloudOutlineBecomesPathZeroClosed() {
        let cloud = sampleCloudShape()
        let interp = Interpretation(label: "cat", confidence: 0.7, annotations: [])

        let concept = RecognitionToDrawingAdapter.makeDrawingConcept(
            from: interp, cloudShape: cloud
        )

        XCTAssertEqual(concept.paths.count, 1, "Cloud outline is the only path")
        XCTAssertTrue(concept.paths[0].closed, "Cloud outline must be closed")
        XCTAssertEqual(concept.paths[0].points.count, cloud.normalizedContour.count)
        XCTAssertEqual(concept.paths[0].order, 1)
    }

    func testEmptyContourYieldsZeroPaths() {
        var cloud = sampleCloudShape()
        cloud = CloudShape(
            center: cloud.center,
            boundingBox: cloud.boundingBox,
            screenPosition: cloud.screenPosition,
            size: cloud.size,
            aspectRatio: cloud.aspectRatio,
            area: cloud.area,
            contourPoints: cloud.contourPoints,
            normalizedContour: []
        )
        let interp = Interpretation(label: "cat", confidence: 0.7, annotations: [])

        let concept = RecognitionToDrawingAdapter.makeDrawingConcept(
            from: interp, cloudShape: cloud
        )
        XCTAssertEqual(concept.paths.count, 0,
                       "Degenerate cloud (no contour) must not produce a body path")
    }

    func testAnnotationsAppendAfterCloudOutline() {
        let cloud = sampleCloudShape()
        let interp = Interpretation(
            label: "cat",
            confidence: 0.7,
            annotations: [
                Annotation(kind: .line, points: [
                    CGPoint(x: 0.4, y: 0.5), CGPoint(x: 0.5, y: 0.55), CGPoint(x: 0.6, y: 0.5)
                ]),
                Annotation(kind: .arc, points: [
                    CGPoint(x: 0.4, y: 0.6), CGPoint(x: 0.5, y: 0.65), CGPoint(x: 0.6, y: 0.6)
                ]),
            ]
        )

        let concept = RecognitionToDrawingAdapter.makeDrawingConcept(
            from: interp, cloudShape: cloud
        )
        XCTAssertEqual(concept.paths.count, 3, "1 cloud + 2 annotations")
        XCTAssertEqual(concept.paths[1].order, 2)
        XCTAssertEqual(concept.paths[2].order, 3)
        XCTAssertFalse(concept.paths[1].closed, "Line annotations stay open")
        XCTAssertFalse(concept.paths[2].closed, "Arc annotations stay open")
    }

    func testDotAnnotationExpandsToClosedPolygon() {
        let cloud = sampleCloudShape()
        let interp = Interpretation(
            label: "cat",
            confidence: 0.7,
            annotations: [
                Annotation(kind: .dot, points: [CGPoint(x: 0.4, y: 0.4)])
            ]
        )

        let concept = RecognitionToDrawingAdapter.makeDrawingConcept(
            from: interp, cloudShape: cloud
        )
        XCTAssertEqual(concept.paths.count, 2)
        let dotPath = concept.paths[1]
        XCTAssertTrue(dotPath.closed, "Dots render as closed polygons")
        XCTAssertEqual(dotPath.points.count, 6,
                       "Dot expands to a 6-point polygon for the line-mesh renderer")
        // Every expanded point should be within dotRadius of the original center.
        let radius = RecognitionToDrawingAdapter.dotRadius
        for point in dotPath.points {
            let dx = point.x - 0.4
            let dy = point.y - 0.4
            let dist = sqrt(dx * dx + dy * dy)
            XCTAssertEqual(dist, radius, accuracy: 0.001)
        }
    }

    func testAnnotationCapIsEnforced() {
        let cloud = sampleCloudShape()
        // 20 annotations — twice the cap.
        let many = (0..<20).map { i in
            Annotation(kind: .dot, points: [CGPoint(x: 0.5, y: Double(i) / 20)])
        }
        let interp = Interpretation(label: "spider", confidence: 0.6, annotations: many)

        let concept = RecognitionToDrawingAdapter.makeDrawingConcept(
            from: interp, cloudShape: cloud
        )
        XCTAssertLessThanOrEqual(
            concept.paths.count - 1, // minus the cloud outline
            RecognitionToDrawingAdapter.annotationCap,
            "Annotation cap must protect the cloud's visual dominance"
        )
    }

    func testLabelCapitalizationForUI() {
        let cloud = sampleCloudShape()
        let interp = Interpretation(label: "magic wand", confidence: 0.7, annotations: [])
        let concept = RecognitionToDrawingAdapter.makeDrawingConcept(
            from: interp, cloudShape: cloud
        )
        XCTAssertEqual(concept.name, "Magic Wand")
    }

    // MARK: - Test fixture

    private func sampleCloudShape() -> CloudShape {
        // A square-ish cloud with a 4-point contour.
        let contour: [CGPoint] = [
            CGPoint(x: 0.1, y: 0.1),
            CGPoint(x: 0.9, y: 0.1),
            CGPoint(x: 0.9, y: 0.9),
            CGPoint(x: 0.1, y: 0.9),
        ]
        return CloudShape(
            center: simd_float3(0, 0, 0),
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            screenPosition: CGPoint(x: 50, y: 50),
            size: CGSize(width: 100, height: 100),
            aspectRatio: 1.0,
            area: 10_000,
            contourPoints: contour.map { CGPoint(x: $0.x * 100, y: $0.y * 100) },
            normalizedContour: contour
        )
    }
}
