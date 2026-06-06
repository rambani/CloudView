import Foundation

/// One character mark to add to the cloud silhouette. Eye, mouth,
/// ear-tip, tail-flick, teeth, spike-row, whisker, claw, or fin —
/// each anchored to one or more silhouette waypoints.
///
/// Single struct with optional fields rather than an enum-with-
/// associated-values, because Codable interop with Gemini is much
/// cleaner this way (the wire shape is just key/value JSON, and
/// each mark type pulls the fields it cares about).
struct CharacterMark: Codable {

    enum MarkType: String, Codable {
        case eye
        case mouthArc    = "mouth_arc"
        case teethZigzag = "teeth_zigzag"
        case earTip      = "ear_tip"
        case tailFlick   = "tail_flick"
        case spikeRow    = "spike_row"
        case whisker
        case claw
        case fin
    }

    let type: MarkType

    // Anchor — every mark needs at least one
    let nearWaypoint: Int?
    let fromWaypoint: Int?
    let toWaypoint: Int?

    // Geometry parameters — meaning varies by type (see MarkRenderer)
    let inset: Double?
    let length: Double?
    let height: Double?
    let baseWidth: Double?
    let amplitude: Double?
    let count: Int?
    let curve: Double?     // -1 or 1 for tail flick direction
    let angle: Double?     // degrees off the outward normal
    let size: Double?

    enum CodingKeys: String, CodingKey {
        case type
        case nearWaypoint = "near_waypoint"
        case fromWaypoint = "from_waypoint"
        case toWaypoint   = "to_waypoint"
        case inset
        case length
        case height
        case baseWidth    = "base_width"
        case amplitude
        case count
        case curve
        case angle
        case size
    }
}
