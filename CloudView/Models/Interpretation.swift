import Foundation
import CoreGraphics

/// One of (typically 5) alternative answers to "what does this cloud kinda
/// look like?" — returned by `CloudRecognitionService`. Each interpretation
/// includes the label and a small budget of marks to add over the cloud's
/// own outline so the suggestion becomes legible.
struct Interpretation: Codable, Equatable {
    let label: String       // From the kid-safe allowlist, e.g. "dragon"
    let confidence: Double  // 0–1, advisory only
    let annotations: [Annotation]
}

/// A single minimal mark to add over the cluster's outline. Coordinates are
/// normalized to 0–1 within the cluster's bounding box. The renderer
/// enforces a hard cap on total annotations per interpretation so the cloud
/// always stays visually dominant.
struct Annotation: Codable, Equatable {
    enum Kind: String, Codable {
        case dot       // Single point, rendered as a small filled circle
        case line      // Open polyline (e.g. mouth, flipper, antenna)
        case arc       // Two endpoints + a midpoint, rendered as a smooth curve
    }

    let kind: Kind

    /// Normalized 0–1 coordinates within the cluster bounding box. Anything
    /// outside [0,1] is clamped during rendering so annotations can't sprawl.
    let points: [CGPoint]
}
