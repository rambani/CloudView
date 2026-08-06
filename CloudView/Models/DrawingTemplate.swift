import Foundation
import CoreGraphics

/// A single reusable creature drawing, authored once in its own normalized
/// 0–1 coordinate space (top-left origin, y-down — the same convention the
/// cloud contour and `AnimatedDrawing` use). The recognition + fitting
/// pipeline warps a template onto a real cloud so the drawing feels
/// *discovered in* the cloud rather than pasted on top.
///
/// Two pieces:
///   - `silhouette`: the creature's body outline. Used both for shape
///     retrieval (Hu-moment match against the cloud) and, in "full creature"
///     fusion mode, as the body stroke itself.
///   - `strokes`: the identifying detail marks (ears, tail, fins, eyes,
///     mouth). These are what the eye "fills in" — in "cloud-as-body" fusion
///     mode the cloud's own outline becomes the body and only these details
///     are drawn, attached to the cloud's real extremes.
///
/// The art shipped in `Resources/DrawingTemplates.json` is a small,
/// schema-conformant starter set. Production art is sourced separately
/// (permissively-licensed line-art) and drops into the same schema with no
/// code change — see docs/DRAWING_SYSTEM.md.
struct DrawingTemplate: Codable, Equatable {
    /// Label surfaced to the user, lower-case (e.g. "rabbit"). Capitalized
    /// for display by the composer.
    let label: String

    /// Coarse category, mirrors the recognition allowlist categories
    /// (animals, mythical, …). Advisory; used for scan reporting themes.
    let category: String

    /// Closed body outline in normalized 0–1 space. Drives shape retrieval
    /// and is the body path in "full creature" mode.
    let silhouette: [Pt]

    /// Detail marks layered over the body, revealed in `order` sequence.
    let strokes: [Stroke]

    struct Stroke: Codable, Equatable {
        /// Freeform tag ("ear", "tail", "fin", "eye", "mouth", …). Advisory
        /// today — every stroke is warped the same way — but kept so future
        /// fusion logic can treat, say, ears differently from eyes.
        let role: String
        /// Reveal order. Lower draws first; the body is always order 0.
        let order: Int
        /// Whether the polyline closes back to its first point.
        let closed: Bool
        let points: [Pt]
    }
}

/// A normalized 2-D point that decodes from a compact JSON array `[x, y]`
/// rather than `{"x":…,"y":…}`, so the template file stays readable when a
/// single stroke has dozens of points. Bridges to `CGPoint` for the geometry
/// and rendering code.
struct Pt: Codable, Equatable {
    let x: Double
    let y: Double

    var cg: CGPoint { CGPoint(x: x, y: y) }

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ p: CGPoint) {
        self.x = Double(p.x)
        self.y = Double(p.y)
    }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        x = try c.decode(Double.self)
        y = try c.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(x)
        try c.encode(y)
    }
}

extension Array where Element == Pt {
    /// Convenience bridge used throughout the fitting pipeline.
    var cgPoints: [CGPoint] { map(\.cg) }
}

/// Top-level shape of `DrawingTemplates.json`.
struct DrawingTemplateFile: Codable, Equatable {
    let version: Int
    let templates: [DrawingTemplate]
}
