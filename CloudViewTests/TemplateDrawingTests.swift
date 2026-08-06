import XCTest
import CoreGraphics
@testable import CloudView

/// Tests for the cloud-fitted template drawing engine: JSON decode, the
/// similarity-transform fit, landmark extraction, Hu-moment shape retrieval,
/// and the hybrid composer. All pure — no bundle, no AR.
final class TemplateDrawingTests: XCTestCase {

    // MARK: - Model decode

    func testTemplateFileDecodesCompactPoints() throws {
        let json = """
        {
          "version": 1,
          "templates": [
            {
              "label": "blob",
              "category": "animals",
              "silhouette": [[0.2,0.2],[0.8,0.2],[0.8,0.8],[0.2,0.8]],
              "strokes": [
                { "role": "eye", "order": 1, "closed": false, "points": [[0.4,0.4],[0.5,0.4]] }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let file = try JSONDecoder().decode(DrawingTemplateFile.self, from: json)
        XCTAssertEqual(file.version, 1)
        XCTAssertEqual(file.templates.count, 1)
        let t = file.templates[0]
        XCTAssertEqual(t.label, "blob")
        XCTAssertEqual(t.silhouette.count, 4)
        XCTAssertEqual(t.silhouette[1].x, 0.8, accuracy: 1e-9)
        XCTAssertEqual(t.silhouette[2].y, 0.8, accuracy: 1e-9)
        XCTAssertEqual(t.strokes.count, 1)
        XCTAssertEqual(t.strokes[0].role, "eye")
        XCTAssertFalse(t.strokes[0].closed)
    }

    // MARK: - Similarity transform

    private func assertPointsEqual(_ a: CGPoint, _ b: CGPoint, _ eps: CGFloat = 1e-6, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: eps, file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: eps, file: file, line: line)
    }

    func testSimilarityFitIsIdentityWhenSourceEqualsTarget() {
        let pts = [CGPoint(x: 0.1, y: 0.2), CGPoint(x: 0.9, y: 0.3), CGPoint(x: 0.5, y: 0.8)]
        let t = SimilarityTransform.fit(source: pts, target: pts)
        for p in pts { assertPointsEqual(t.apply(p), p) }
    }

    func testSimilarityFitRecoversKnownScaleRotationTranslation() {
        // Ground-truth similarity: scale 2, rotate 90° (·i), translate (1, 0.5).
        // w = 2·i·z + (1 + 0.5i)  →  (x,y) ↦ (1 - 2y, 0.5 + 2x)
        let src = [
            CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.3, y: 0.1),
            CGPoint(x: 0.7, y: 0.4), CGPoint(x: 0.2, y: 0.9),
        ]
        let dst = src.map { CGPoint(x: 1.0 - 2.0 * $0.y, y: 0.5 + 2.0 * $0.x) }

        let t = SimilarityTransform.fit(source: src, target: dst)
        for (s, d) in zip(src, dst) { assertPointsEqual(t.apply(s), d, 1e-6) }
    }

    func testSimilarityFitDegenerateSourceFallsBackToTranslation() {
        // All source points coincide → no scale/rotation recoverable.
        let src = Array(repeating: CGPoint(x: 0.5, y: 0.5), count: 4)
        let dst = Array(repeating: CGPoint(x: 0.2, y: 0.8), count: 4)
        let t = SimilarityTransform.fit(source: src, target: dst)
        // Should translate the coincident point onto the target, not NaN.
        let mapped = t.apply(CGPoint(x: 0.5, y: 0.5))
        XCTAssertTrue(mapped.x.isFinite && mapped.y.isFinite)
        assertPointsEqual(mapped, CGPoint(x: 0.2, y: 0.8), 1e-6)
    }

    // MARK: - Landmarks

    func testReferencePointsExtremesAndCentroid() {
        // Unit square: centroid center, extremes on the edges.
        let square = [
            CGPoint(x: 0.0, y: 0.0), CGPoint(x: 1.0, y: 0.0),
            CGPoint(x: 1.0, y: 1.0), CGPoint(x: 0.0, y: 1.0),
        ]
        let lm = CloudLandmarks.referencePoints(square)
        XCTAssertEqual(lm.count, 5)
        assertPointsEqual(lm[0], CGPoint(x: 0.5, y: 0.5)) // centroid
        XCTAssertEqual(lm[1].y, 0.0, accuracy: 1e-9)      // top (min y)
        XCTAssertEqual(lm[2].y, 1.0, accuracy: 1e-9)      // bottom (max y)
        XCTAssertEqual(lm[3].x, 0.0, accuracy: 1e-9)      // left (min x)
        XCTAssertEqual(lm[4].x, 1.0, accuracy: 1e-9)      // right (max x)
    }

    // MARK: - Shape retrieval (Hu moments)

    func testShapeMatcherIdenticalShapesHaveZeroDistance() {
        let shape = [
            CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.2),
            CGPoint(x: 0.8, y: 0.8), CGPoint(x: 0.2, y: 0.8),
        ]
        let hu = CloudShapeSignature.huMoments(of: shape)
        XCTAssertEqual(ShapeMatcher.distance(hu, hu), 0.0, accuracy: 1e-9)
        XCTAssertEqual(ShapeMatcher.score(distance: 0.0), 1.0, accuracy: 1e-9)
    }

    private func rect(w: CGFloat, h: CGFloat) -> [CGPoint] {
        let cx: CGFloat = 0.5, cy: CGFloat = 0.5
        return [
            CGPoint(x: cx - w/2, y: cy - h/2),
            CGPoint(x: cx + w/2, y: cy - h/2),
            CGPoint(x: cx + w/2, y: cy + h/2),
            CGPoint(x: cx - w/2, y: cy + h/2),
        ]
    }

    func testShapeRetrievalDiscriminatesElongatedFromRound() {
        // Hu moments are rotation/reflection invariant: they key on *form*
        // (elongation) not orientation. So a "streak" template should win for
        // an elongated cloud even when that cloud is oriented the other way.
        // Mildly-elongated "round" template and a clearly-elongated "streak".
        // (A perfect square drives several Hu moments to exactly zero, which
        // makes log-space distance brittle — so give the round shape a small,
        // stable aspect ratio the round cloud can match closely.)
        let blob = DrawingTemplate(
            label: "blob", category: "test",
            silhouette: rect(w: 0.62, h: 0.50).map { Pt($0) }, strokes: []
        )
        let streak = DrawingTemplate(
            label: "streak", category: "test",
            silhouette: rect(w: 0.92, h: 0.12).map { Pt($0) }, strokes: []
        )
        let lib = DrawingTemplateLibrary(templates: [blob, streak], confidenceFloor: 0.0)

        // A tall, thin cloud: same elongation as the streak template but
        // rotated 90°. Hu moments are rotation-invariant, so it should still
        // resolve to "streak".
        let tallThinCloud = rect(w: 0.12, h: 0.92)
        XCTAssertEqual(lib.bestMatch(forCloudContour: tallThinCloud)?.template.label, "streak")

        // A cloud with nearly the same mild aspect ratio as "blob".
        let roundCloud = rect(w: 0.56, h: 0.46)
        XCTAssertEqual(lib.bestMatch(forCloudContour: roundCloud)?.template.label, "blob")
    }

    func testConfidenceFloorRejectsPoorMatches() {
        let streak = DrawingTemplate(
            label: "streak", category: "test",
            silhouette: rect(w: 0.95, h: 0.06).map { Pt($0) }, strokes: []
        )
        // An impossibly high floor → nothing qualifies → nil (caller falls back).
        let strict = DrawingTemplateLibrary(templates: [streak], confidenceFloor: 0.999999)
        XCTAssertNil(strict.bestMatch(forCloudContour: rect(w: 0.5, h: 0.5)))
    }

    // MARK: - Hybrid composer

    private func makeTemplate() -> DrawingTemplate {
        DrawingTemplate(
            label: "blob",
            category: "test",
            silhouette: rect(w: 0.6, h: 0.6).map { Pt($0) },
            strokes: [
                DrawingTemplate.Stroke(role: "ear", order: 1, closed: false,
                                       points: [Pt(x: 0.4, y: 0.2), Pt(x: 0.5, y: 0.05)])
            ]
        )
    }

    func testComposerStrongMatchUsesCloudAsBody() {
        let template = makeTemplate()
        let cloud = [
            CGPoint(x: 0.10, y: 0.30), CGPoint(x: 0.70, y: 0.22),
            CGPoint(x: 0.85, y: 0.70), CGPoint(x: 0.25, y: 0.80),
        ]
        let concept = TemplateDrawingComposer.compose(
            cloudContour: cloud, template: template, score: 0.9, strongMatchThreshold: 0.55
        )
        // Body (order 0) is the *cloud's own* contour, not the template's.
        let body = concept.paths.first { $0.order == 0 }
        XCTAssertNotNil(body)
        XCTAssertTrue(body!.closed)
        XCTAssertEqual(body!.points.count, cloud.count)
        for (a, b) in zip(body!.points, cloud) { assertPointsEqual(a, b) }
        // Plus the detail stroke, warped on top.
        XCTAssertEqual(concept.paths.count, 2)
        XCTAssertEqual(concept.name, "Blob")
    }

    func testComposerWeakMatchDrawsWarpedTemplateBody() {
        let template = makeTemplate()
        let cloud = [
            CGPoint(x: 0.10, y: 0.30), CGPoint(x: 0.70, y: 0.22),
            CGPoint(x: 0.85, y: 0.70), CGPoint(x: 0.25, y: 0.80),
        ]
        let concept = TemplateDrawingComposer.compose(
            cloudContour: cloud, template: template, score: 0.2, strongMatchThreshold: 0.55
        )
        let body = concept.paths.first { $0.order == 0 }
        XCTAssertNotNil(body)
        // Body is the template silhouette warped onto the cloud — same point
        // count as the template, and NOT equal to the raw cloud contour.
        XCTAssertEqual(body!.points.count, template.silhouette.count)
        let matchesCloudExactly = zip(body!.points, cloud).allSatisfy {
            abs($0.0.x - $0.1.x) < 1e-9 && abs($0.0.y - $0.1.y) < 1e-9
        }
        XCTAssertFalse(matchesCloudExactly)
    }
}
