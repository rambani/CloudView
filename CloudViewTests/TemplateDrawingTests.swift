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

    // MARK: - Linear solver

    func testLinearSolveKnownSystem() {
        // 2x + y = 3 ; x + 3y = 5  →  x = 0.8, y = 1.4
        let x = LinearSolve.solve([[2, 1], [1, 3]], [3, 5])
        XCTAssertNotNil(x)
        XCTAssertEqual(x![0], 0.8, accuracy: 1e-9)
        XCTAssertEqual(x![1], 1.4, accuracy: 1e-9)
    }

    func testLinearSolveSingularReturnsNil() {
        // Second row is 2× the first → singular.
        XCTAssertNil(LinearSolve.solve([[1, 2], [2, 4]], [3, 6]))
    }

    // MARK: - Thin-plate spline

    private let tpsControl: [CGPoint] = [
        CGPoint(x: 0.2, y: 0.1), CGPoint(x: 0.8, y: 0.15),
        CGPoint(x: 0.85, y: 0.8), CGPoint(x: 0.15, y: 0.85),
        CGPoint(x: 0.5, y: 0.5),
    ]

    func testTPSIdentityLeavesPointsPut() throws {
        let tps = try XCTUnwrap(ThinPlateSpline.fit(source: tpsControl, target: tpsControl))
        assertPointsEqual(tps.apply(CGPoint(x: 0.4, y: 0.4)), CGPoint(x: 0.4, y: 0.4), 1e-5)
        assertPointsEqual(tps.apply(CGPoint(x: 0.7, y: 0.2)), CGPoint(x: 0.7, y: 0.2), 1e-5)
    }

    func testTPSInterpolatesControlPointsAndReproducesAffine() throws {
        // Affine target: (x,y) ↦ (1.3x + 0.1, 0.7y + 0.2).
        func affine(_ p: CGPoint) -> CGPoint {
            CGPoint(x: 1.3 * p.x + 0.1, y: 0.7 * p.y + 0.2)
        }
        let dst = tpsControl.map(affine)
        let tps = try XCTUnwrap(ThinPlateSpline.fit(source: tpsControl, target: dst))

        // Exactly interpolates every control point …
        for (s, d) in zip(tpsControl, dst) { assertPointsEqual(tps.apply(s), d, 1e-5) }
        // … and, because the data is affine, reproduces it at a new point.
        let newP = CGPoint(x: 0.37, y: 0.62)
        assertPointsEqual(tps.apply(newP), affine(newP), 1e-5)
    }

    func testTPSFitRejectsTooFewPoints() {
        XCTAssertNil(ThinPlateSpline.fit(
            source: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)],
            target: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]
        ))
    }

    // MARK: - Warp selection (integration)

    func testTemplateWarpStaysBoundedOnRealisticContours() {
        // A rabbit-ish template silhouette draped onto an irregular cloud.
        let template = [
            CGPoint(x: 0.34, y: 0.04), CGPoint(x: 0.28, y: 0.22), CGPoint(x: 0.24, y: 0.40),
            CGPoint(x: 0.16, y: 0.62), CGPoint(x: 0.24, y: 0.86), CGPoint(x: 0.50, y: 0.92),
            CGPoint(x: 0.74, y: 0.86), CGPoint(x: 0.82, y: 0.62), CGPoint(x: 0.74, y: 0.40),
            CGPoint(x: 0.70, y: 0.22), CGPoint(x: 0.64, y: 0.04), CGPoint(x: 0.50, y: 0.30),
        ]
        let cloud = [
            CGPoint(x: 0.30, y: 0.10), CGPoint(x: 0.22, y: 0.28), CGPoint(x: 0.20, y: 0.45),
            CGPoint(x: 0.12, y: 0.65), CGPoint(x: 0.30, y: 0.88), CGPoint(x: 0.55, y: 0.90),
            CGPoint(x: 0.78, y: 0.82), CGPoint(x: 0.80, y: 0.60), CGPoint(x: 0.70, y: 0.42),
            CGPoint(x: 0.66, y: 0.25), CGPoint(x: 0.60, y: 0.08), CGPoint(x: 0.46, y: 0.30),
        ]
        let warp = TemplateWarp.fit(templateContour: template, cloudContour: cloud)
        let warped = warp.apply(template)
        XCTAssertEqual(warped.count, template.count)
        // No NaNs and no runaway extrapolation — the drape stays near the cloud.
        for p in warped {
            XCTAssertTrue(p.x.isFinite && p.y.isFinite)
            XCTAssertTrue(p.x > -0.5 && p.x < 1.5 && p.y > -0.5 && p.y < 1.5)
        }
    }
}
