import Foundation

/// One template — either a SUBJECT (whale, penguin, dragon...) or a
/// PROP (skateboard, hat, sunglasses...). Loaded from JSON files in
/// the Library/ resource directory at startup.
///
/// Coordinates are normalized 0–1 in the template's own bounding box;
/// composition fits the box onto the cloud silhouette at render time.
struct CreatureTemplate: Decodable, Identifiable {
    let id: String
    let category: String
    let tags: [String]?
    let anchors: [String: [Double]]?
    let strokes: [TemplateStroke]

    /// Prop-only — name of the subject anchor this prop hooks onto
    /// (e.g. "feet_center" for a skateboard, "head_top" for a hat).
    let attachesTo: String?

    /// Prop-only — point on the prop (in prop-local coords) that
    /// meets the subject's `attachesTo` anchor.
    let anchorOnSelf: [Double]?

    /// Prop-only — multiplier applied to the prop's width during
    /// composition. 1.0 = same width as the subject; 0.85 = slightly
    /// narrower; 1.1 = slightly wider.
    let sizeRelativeToSubject: Double?

    enum CodingKeys: String, CodingKey {
        case id, category, tags, anchors, strokes
        case attachesTo = "attaches_to"
        case anchorOnSelf = "anchor_on_self"
        case sizeRelativeToSubject = "size_relative_to_subject"
    }

    /// True when this template is a prop (declares an attach point).
    var isProp: Bool { attachesTo != nil }
}

struct TemplateStroke: Decodable {
    let label: String
    let width: Double
    let points: [[Double]]
}
