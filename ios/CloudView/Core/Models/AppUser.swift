import Foundation

struct AppUser: Identifiable, Codable, Sendable {
    let id: UUID
    var username: String
    var avatarURL: String?
    var city: String?
    var totalSightings: Int
    var streakDays: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarURL = "avatar_url"
        case city
        case totalSightings = "total_sightings"
        case streakDays = "streak_days"
        case createdAt = "created_at"
    }
}

struct CityStats: Identifiable, Sendable {
    let id: String
    let city: String
    let country: String
    let count: Int
    let latitude: Double
    let longitude: Double
    let recentShapes: [String]
}
