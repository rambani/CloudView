import Foundation
import CoreGraphics

/// Schema v2 for `DrawingTemplates.json`: instead of whole-creature drawings,
/// art ships as a **parts library** — tagged heads, eyes, crests, mouths,
/// tails, accessories, companion elements — that `DrawingAssembler` combines
/// per scan. A modest curated pool yields ~10⁶ distinct assemblies per
/// creature, which (multiplied by never-repeating cloud bodies and seeded
/// style variation) is where "effectively endless" comes from without any
/// runtime generation. See docs/GENERATIVE_DRAWING_DESIGN.md.
///
/// Schema v1 (`DrawingTemplateFile`) stays valid — the library loader accepts
/// either — so migration to parts is incremental.

/// Top-level shape of a v2 `DrawingTemplates.json`.
struct PartsLibraryFile: Codable, Equatable {
    let version: Int
    let creatures: [CreatureSpec]
    let parts: [DrawingPart]
}

/// A creature the shape matcher can pick: a silhouette prototype for
/// Hu-moment retrieval plus the set of part slots its drawings are
/// assembled from.
struct CreatureSpec: Codable, Equatable {
    let label: String
    let category: String

    /// Closed prototype outline in normalized 0–1 space. Drives Hu-moment
    /// retrieval, and is the warped body in full-creature mode (weak match).
    let silhouette: [Pt]

    /// Slot kind (e.g. "head", "eye", "crest") → how the assembler fills it.
    let slots: [String: SlotSpec]
}

/// How one slot of a creature is filled.
struct SlotSpec: Codable, Equatable {
    /// Required slots are always filled (when any candidate part exists).
    let required: Bool
    /// For optional slots, inclusion probability per scan (default applied by
    /// the assembler when nil). Ignored for required slots.
    let probability: Double?
}

/// One reusable piece of art: a few strokes in their own local 0–1 space
/// (top-left origin, y-down), placed at a named cloud landmark.
struct DrawingPart: Codable, Equatable {
    let id: String
    /// Which slot kind this part can fill ("head", "eye", …).
    let kind: String
    /// Creature labels this part suits, or ["*"] for any (shared eyes,
    /// accessories) — sharing multiplies combinations across the library.
    let creatures: [String]
    /// Cloud landmark the part attaches at.
    let anchor: PartAnchor
    /// Part extent as a fraction of the cloud's shorter bounding-box side.
    /// The assembler applies a default when nil.
    let scale: Double?
    let strokes: [DrawingTemplate.Stroke]

    func suits(_ creatureLabel: String) -> Bool {
        creatures.contains("*") || creatures.contains(creatureLabel)
    }
}

/// Named attachment points on a cloud, resolved against
/// `CloudLandmarks.richReferencePoints` (order: centroid, top, bottom, left,
/// right, bottomRight, topLeft, topRight, bottomLeft — y-down, so "top" is
/// the visually highest point).
enum PartAnchor: String, Codable, Equatable {
    case centroid
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    /// Index into `CloudLandmarks.richReferencePoints`' fixed ordering.
    /// (maxSum = bottom-right, minSum = top-left, maxDiff = top-right,
    /// maxNegDiff = bottom-left, in y-down coordinates.)
    var richLandmarkIndex: Int {
        switch self {
        case .centroid:    return 0
        case .top:         return 1
        case .bottom:      return 2
        case .left:        return 3
        case .right:       return 4
        case .bottomRight: return 5
        case .topLeft:     return 6
        case .topRight:    return 7
        case .bottomLeft:  return 8
        }
    }

    func point(in richLandmarks: [CGPoint]) -> CGPoint {
        let i = richLandmarkIndex
        guard i < richLandmarks.count else { return .zero }
        return richLandmarks[i]
    }

    /// Left/right mirror, used when an assembly is horizontally flipped so a
    /// tail authored for the right side attaches on the left.
    var mirrored: PartAnchor {
        switch self {
        case .left:        return .right
        case .right:       return .left
        case .topLeft:     return .topRight
        case .topRight:    return .topLeft
        case .bottomLeft:  return .bottomRight
        case .bottomRight: return .bottomLeft
        default:           return self
        }
    }
}
