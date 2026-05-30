import Foundation

// Claude's creative interpretation of a cloud photo.
// Drawing paths come from Apple Vision (CloudVisionService), not from here.
struct CloudAnalysis: Codable, Sendable {
    let shapeName: String
    let quip: String
    let cloudType: String
    let weatherMood: String
    let watchabilityScore: Int

    enum CodingKeys: String, CodingKey {
        case shapeName = "shape_name"
        case quip
        case cloudType = "cloud_type"
        case weatherMood = "weather_mood"
        case watchabilityScore = "watchability_score"
    }

    // DrawingElement lives here as a shared type used by CloudSighting and CloudVisionService.
    // Claude never produces these — Vision does.
    struct DrawingElement: Codable, Identifiable, Sendable {
        let id: UUID
        let points: [[Double]] // normalized [x, y] in SwiftUI space (top-left origin)
        let smooth: Bool
        let strokeWidth: Double
        let label: String?

        init(points: [[Double]], smooth: Bool = false, strokeWidth: Double = 2.0, label: String? = nil) {
            self.id = UUID()
            self.points = points
            self.smooth = smooth
            self.strokeWidth = strokeWidth
            self.label = label
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = UUID()
            points = try container.decode([[Double]].self, forKey: .points)
            smooth = try container.decodeIfPresent(Bool.self, forKey: .smooth) ?? false
            strokeWidth = try container.decodeIfPresent(Double.self, forKey: .strokeWidth) ?? 2.0
            label = try container.decodeIfPresent(String.self, forKey: .label)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(points, forKey: .points)
            try container.encode(smooth, forKey: .smooth)
            try container.encode(strokeWidth, forKey: .strokeWidth)
            try container.encodeIfPresent(label, forKey: .label)
        }

        enum CodingKeys: String, CodingKey {
            case points, smooth
            case strokeWidth = "stroke_width"
            case label
        }
    }
}
