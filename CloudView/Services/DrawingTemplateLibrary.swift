import Foundation
import CoreGraphics

/// Ranks creatures by how closely their canonical silhouette matches a
/// cloud's contour, using the Hu-moment signature the app already computes
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

/// Loads the bundled `DrawingTemplates.json` — schema v1 (whole-creature
/// templates) or v2 (creatures + parts library) — precomputes each creature's
/// Hu signature once, and turns "which creature does this cloud look like?"
/// plus a `VariationSeed` into a ready-to-animate drawing. Missing/corrupt
/// file → an empty library, so the app silently falls back to the existing
/// recognition path.
final class DrawingTemplateLibrary {
    static let shared = DrawingTemplateLibrary()

    struct Entry {
        let label: String
        let silhouette: [CGPoint]
        /// Hu moments of the silhouette, precomputed at load.
        let huMoments: [Double]
        let content: Content

        enum Content {
            /// v1: a complete authored drawing.
            case template(DrawingTemplate)
            /// v2: a creature assembled from the parts pool per scan.
            case creature(CreatureSpec)
        }
    }

    struct Match {
        let entry: Entry
        let score: Double
    }

    let entries: [Entry]
    /// The v2 parts pool (empty for a v1 library).
    let parts: [DrawingPart]

    /// Confidence floor below which we decline to claim a creature at all and
    /// let the caller fall back (or show "Cool cloud!"). Keeps us from drawing
    /// a dragon on a shapeless blob — the difference between "real" and "made
    /// up".
    let confidenceFloor: Double

    /// How often the seeded category pick strays from the best shape match to
    /// the runner-up / third place, for surprise without breaking the "cloud
    /// caused this" feel: 80% best, 15% second, 5% third.
    private static let categoryTemperature: [Double] = [0.80, 0.95]

    private init(confidenceFloor: Double = 0.30) {
        self.confidenceFloor = confidenceFloor
        let loaded = Self.loadFromBundle()
        self.entries = loaded.entries
        self.parts = loaded.parts
        if entries.isEmpty {
            print("ℹ️  DrawingTemplateLibrary: no templates loaded — " +
                  "template drawings disabled, falling back to recognition/outline path.")
        }
    }

    /// Test seam: v1 library from in-memory templates.
    init(templates: [DrawingTemplate], confidenceFloor: Double = 0.30) {
        self.confidenceFloor = confidenceFloor
        self.parts = []
        self.entries = templates.compactMap { Self.entry(label: $0.label, silhouette: $0.silhouette, content: .template($0)) }
    }

    /// Test seam: v2 library from in-memory creatures + parts.
    init(creatures: [CreatureSpec], parts: [DrawingPart], confidenceFloor: Double = 0.30) {
        self.confidenceFloor = confidenceFloor
        self.parts = parts
        self.entries = creatures.compactMap { Self.entry(label: $0.label, silhouette: $0.silhouette, content: .creature($0)) }
    }

    private static func entry(label: String, silhouette: [Pt], content: Entry.Content) -> Entry? {
        let pts = silhouette.cgPoints
        guard pts.count >= 3 else {
            print("⚠️  '\(label)' has a degenerate silhouette; skipping.")
            return nil
        }
        return Entry(
            label: label,
            silhouette: pts,
            huMoments: CloudShapeSignature.huMoments(of: pts),
            content: content
        )
    }

    private static func loadFromBundle() -> (entries: [Entry], parts: [DrawingPart]) {
        guard let url = Bundle.main.url(forResource: "DrawingTemplates", withExtension: "json") else {
            print("ℹ️  DrawingTemplates.json not in bundle.")
            return ([], [])
        }
        do {
            let data = try Data(contentsOf: url)
            struct VersionPeek: Codable { let version: Int }
            let version = (try? JSONDecoder().decode(VersionPeek.self, from: data))?.version ?? 1

            if version >= 2 {
                let file = try JSONDecoder().decode(PartsLibraryFile.self, from: data)
                let entries = file.creatures.compactMap {
                    entry(label: $0.label, silhouette: $0.silhouette, content: .creature($0))
                }
                return (entries, file.parts)
            } else {
                let file = try JSONDecoder().decode(DrawingTemplateFile.self, from: data)
                let entries = file.templates.compactMap {
                    entry(label: $0.label, silhouette: $0.silhouette, content: .template($0))
                }
                return (entries, [])
            }
        } catch {
            print("⚠️  Failed to decode DrawingTemplates.json: \(error.localizedDescription)")
            return ([], [])
        }
    }

    // MARK: - Matching

    /// All creatures whose shape similarity to the cloud clears the
    /// confidence floor, best first.
    func rankedMatches(forCloudContour contour: [CGPoint]) -> [Match] {
        guard contour.count >= 3, !entries.isEmpty else { return [] }
        let cloudHu = CloudShapeSignature.huMoments(of: contour)

        return entries
            .map { Match(entry: $0, score: ShapeMatcher.score(distance: ShapeMatcher.distance(cloudHu, $0.huMoments))) }
            .filter { $0.score >= confidenceFloor }
            .sorted { $0.score > $1.score }
    }

    /// Best-matching v1 template and its 0–1 confidence, or `nil` if nothing
    /// clears `confidenceFloor`. (Legacy surface; the variation-aware
    /// `makeDrawing` below is the production path.)
    func bestMatch(forCloudContour contour: [CGPoint]) -> (template: DrawingTemplate, score: Double)? {
        for match in rankedMatches(forCloudContour: contour) {
            if case .template(let t) = match.entry.content {
                return (t, match.score)
            }
        }
        return nil
    }

    // MARK: - Drawing

    /// Full path from a raw cloud contour + variation seed to a
    /// ready-to-animate drawing, or `nil` when no creature is a confident
    /// enough fit. The seed picks the category (with a small temperature
    /// across the top shape matches), drives part assembly for v2 creatures,
    /// and styles the strokes/animation — deterministically, so the same
    /// cloud + seed always yields the same drawing.
    func makeDrawing(forCloudContour contour: [CGPoint], variation: VariationSeed) -> DrawingConcept? {
        let ranked = rankedMatches(forCloudContour: contour)
        guard !ranked.isEmpty else { return nil }

        let u = variation.double(for: "category")
        var index = 0
        if u >= Self.categoryTemperature[0] { index = 1 }
        if u >= Self.categoryTemperature[1] { index = 2 }
        let match = ranked[min(index, ranked.count - 1)]

        switch match.entry.content {
        case .creature(let creature):
            return DrawingAssembler.assemble(
                creature: creature,
                parts: parts,
                cloudContour: contour,
                score: match.score,
                variation: variation
            )
        case .template(let template):
            var concept = TemplateDrawingComposer.compose(
                cloudContour: contour,
                template: template,
                score: match.score
            )
            concept.style = DrawingAssembler.seededStyle(variation)
            return concept
        }
    }
}
