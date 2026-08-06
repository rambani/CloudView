import Foundation
import CoreGraphics

/// Ranks `DrawingTemplate`s by how closely their canonical silhouette matches
/// a cloud's contour, using the Hu-moment signature the app already computes
/// (`CloudShapeSignature`). This is what makes a recognition "feel real": the
/// creature is chosen *because the cloud's shape resembles it*, not sampled at
/// random.
enum ShapeMatcher {
    /// Hu moments span ~10 orders of magnitude and can be negative, so raw
    /// Euclidean distance is meaningless. The standard fix (as in OpenCV's
    /// `matchShapes`) is to compare sign-preserving log magnitudes:
    ///   m(h) = sign(h) · log₁₀|h|
    /// then take an L1 distance. Identical shapes → 0.
    static func logMoments(_ hu: [Double]) -> [Double] {
        hu.map { v in
            guard v.isFinite, abs(v) > 1e-30 else { return 0 }
            return (v < 0 ? -1.0 : 1.0) * log10(abs(v))
        }
    }

    static func distance(_ a: [Double], _ b: [Double]) -> Double {
        let la = logMoments(a), lb = logMoments(b)
        let n = min(la.count, lb.count)
        guard n > 0 else { return .infinity }
        var d = 0.0
        for i in 0..<n { d += abs(la[i] - lb[i]) }
        return d
    }

    /// Map a log-space distance to a 0–1 similarity via exponential decay.
    /// `scale` sets how quickly confidence falls off; 6 was chosen so that a
    /// good-but-imperfect silhouette match (a few log-units apart across seven
    /// moments) still clears the composer's "strong match" bar, while an
    /// unrelated shape lands near zero. Tune alongside the composer thresholds.
    static let scoreScale = 6.0
    static func score(distance: Double) -> Double {
        exp(-distance / scoreScale)
    }
}

/// Loads the bundled `DrawingTemplates.json`, precomputes each template's Hu
/// signature once, and answers "which creature does this cloud look like, and
/// how strongly?" Missing/empty/corrupt file → an empty library, so the app
/// silently falls back to the existing recognition path.
final class DrawingTemplateLibrary {
    static let shared = DrawingTemplateLibrary()

    struct Entry {
        let template: DrawingTemplate
        /// Hu moments of `template.silhouette`, precomputed at load.
        let huMoments: [Double]
    }

    let entries: [Entry]

    /// Confidence floor below which we decline to claim a creature at all and
    /// let the caller fall back (or show "Cool cloud!"). Keeps us from drawing
    /// a dragon on a shapeless blob — the difference between "real" and "made
    /// up".
    let confidenceFloor: Double

    private init(confidenceFloor: Double = 0.30) {
        self.confidenceFloor = confidenceFloor
        self.entries = Self.loadEntries()
        if entries.isEmpty {
            print("ℹ️  DrawingTemplateLibrary: no templates loaded — " +
                  "template drawings disabled, falling back to recognition/outline path.")
        }
    }

    /// Test seam: build a library from in-memory templates without touching
    /// the bundle.
    init(templates: [DrawingTemplate], confidenceFloor: Double = 0.30) {
        self.confidenceFloor = confidenceFloor
        self.entries = templates.map {
            Entry(template: $0,
                  huMoments: CloudShapeSignature.huMoments(of: $0.silhouette.cgPoints))
        }
    }

    private static func loadEntries() -> [Entry] {
        guard let url = Bundle.main.url(forResource: "DrawingTemplates", withExtension: "json") else {
            print("ℹ️  DrawingTemplates.json not in bundle.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(DrawingTemplateFile.self, from: data)
            return file.templates.compactMap { template in
                let pts = template.silhouette.cgPoints
                guard pts.count >= 3 else {
                    print("⚠️  Template '\(template.label)' has a degenerate silhouette; skipping.")
                    return nil
                }
                return Entry(template: template,
                             huMoments: CloudShapeSignature.huMoments(of: pts))
            }
        } catch {
            print("⚠️  Failed to decode DrawingTemplates.json: \(error.localizedDescription)")
            return []
        }
    }

    /// Best-matching template for a cloud contour and its 0–1 confidence, or
    /// `nil` if nothing clears `confidenceFloor`.
    func bestMatch(forCloudContour contour: [CGPoint]) -> (template: DrawingTemplate, score: Double)? {
        guard contour.count >= 3, !entries.isEmpty else { return nil }
        let cloudHu = CloudShapeSignature.huMoments(of: contour)

        var best: (template: DrawingTemplate, score: Double)?
        for entry in entries {
            let d = ShapeMatcher.distance(cloudHu, entry.huMoments)
            let s = ShapeMatcher.score(distance: d)
            if best == nil || s > best!.score {
                best = (entry.template, s)
            }
        }

        guard let match = best, match.score >= confidenceFloor else { return nil }
        return match
    }

    /// Full path from a raw cloud contour to a ready-to-animate drawing, or
    /// `nil` when no creature is a confident enough fit. Ties `bestMatch` to
    /// the hybrid composer so callers stay a one-liner.
    func makeDrawing(forCloudContour contour: [CGPoint]) -> DrawingConcept? {
        guard let match = bestMatch(forCloudContour: contour) else { return nil }
        return TemplateDrawingComposer.compose(
            cloudContour: contour,
            template: match.template,
            score: match.score,
            strongMatchThreshold: TemplateDrawingComposer.defaultStrongThreshold
        )
    }
}
