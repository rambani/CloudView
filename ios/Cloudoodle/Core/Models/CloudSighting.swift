import Foundation
import CoreLocation

struct CloudSighting: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID?
    var imageURL: String?
    var localImageData: Data?
    /// The "developed" AI-rendered version of the photo with ink
    /// overlays. Only set when the user tapped the develop button
    /// and the OpenAI image-edit API returned successfully. When
    /// set, surfaces (capture-flow drawer, profile collection)
    /// prefer this over `localImageData`.
    var developedImageData: Data?
    let shapeName: String
    let quip: String
    let cloudType: String
    let weatherMood: String
    let watchabilityScore: Int
    // Drawing paths come from Apple Vision (CloudVisionService), not from Claude
    let drawingElements: [CloudAnalysis.DrawingElement]
    // Approximate label position: center of the salient cloud region
    let drawingLabelX: Double
    let drawingLabelY: Double
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let country: String?
    var likes: Int
    var isLikedByCurrentUser: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        imageURL: String? = nil,
        localImageData: Data? = nil,
        developedImageData: Data? = nil,
        analysis: CloudAnalysis,
        drawingElements: [CloudAnalysis.DrawingElement] = [],
        drawingLabelX: Double = 0.5,
        drawingLabelY: Double = 0.25,
        latitude: Double? = nil,
        longitude: Double? = nil,
        city: String? = nil,
        country: String? = nil,
        likes: Int = 0,
        isLikedByCurrentUser: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.imageURL = imageURL
        self.localImageData = localImageData
        self.developedImageData = developedImageData
        self.shapeName = analysis.shapeName
        self.quip = analysis.quip
        self.cloudType = analysis.cloudType
        self.weatherMood = analysis.weatherMood
        self.watchabilityScore = analysis.watchabilityScore
        self.drawingElements = drawingElements
        self.drawingLabelX = drawingLabelX
        self.drawingLabelY = drawingLabelY
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.country = country
        self.likes = likes
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.createdAt = createdAt
    }

    var analysis: CloudAnalysis {
        CloudAnalysis(
            shapeName: shapeName,
            quip: quip,
            cloudType: cloudType,
            weatherMood: weatherMood,
            watchabilityScore: watchabilityScore
        )
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", imageURL = "image_url", localImageData, developedImageData
        case shapeName = "shape_name", quip
        case cloudType = "cloud_type", weatherMood = "weather_mood"
        case watchabilityScore = "watchability_score"
        case drawingElements = "drawing_elements"
        case drawingLabelX = "drawing_label_x", drawingLabelY = "drawing_label_y"
        case latitude, longitude, city, country, likes
        case isLikedByCurrentUser = "is_liked_by_current_user"
        case createdAt = "created_at"
    }
}

// Supabase database row shape
struct SightingRow: Codable {
    let id: UUID
    let userId: UUID?
    let imageUrl: String?
    let shapeName: String
    let quip: String
    let cloudType: String
    let weatherMood: String
    let watchabilityScore: Int
    let drawingPaths: DrawingPathsJSON
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let country: String?
    let likes: Int
    let createdAt: String

    struct DrawingPathsJSON: Codable {
        let elements: [CloudAnalysis.DrawingElement]
        let labelX: Double
        let labelY: Double

        enum CodingKeys: String, CodingKey {
            case elements
            case labelX = "label_x"
            case labelY = "label_y"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", imageUrl = "image_url"
        case shapeName = "shape_name", quip
        case cloudType = "cloud_type", weatherMood = "weather_mood"
        case watchabilityScore = "watchability_score"
        case drawingPaths = "drawing_paths"
        case latitude, longitude, city, country, likes
        case createdAt = "created_at"
    }

    func toSighting(isLiked: Bool = false, localData: Data? = nil) -> CloudSighting {
        let analysis = CloudAnalysis(
            shapeName: shapeName,
            quip: quip,
            cloudType: cloudType,
            weatherMood: weatherMood,
            watchabilityScore: watchabilityScore
        )
        return CloudSighting(
            id: id,
            userId: userId,
            imageURL: imageUrl,
            localImageData: localData,
            analysis: analysis,
            drawingElements: drawingPaths.elements,
            drawingLabelX: drawingPaths.labelX,
            drawingLabelY: drawingPaths.labelY,
            latitude: latitude,
            longitude: longitude,
            city: city,
            country: country,
            likes: likes,
            isLikedByCurrentUser: isLiked,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date()
        )
    }
}
