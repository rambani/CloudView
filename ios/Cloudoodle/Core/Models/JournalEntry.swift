import Foundation

/// One entry in the user's personal cloud journal. Stored locally;
/// optional cloud sync via Supabase is a future iteration. Each
/// entry is one captured-and-developed Polaroid plus the user's
/// (optional) note about the day.
///
/// The image data is base64-encoded into the JSON store for now.
/// For users with many entries we'll move to per-entry image files
/// in Documents/journal/<id>/ — but with the typical "few moments
/// per week" usage pattern, an in-JSON store keeps things simple.
struct JournalEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let createdAt: Date

    /// The original captured photo (compressed JPEG).
    let originalImageData: Data
    /// The "developed" AI-rendered version with ink overlays. Nil
    /// if the user never tapped Develop (entry was created from a
    /// scan that wasn't developed).
    var developedImageData: Data?

    /// What the AI identified — used for the back-of-Polaroid caption.
    let shapeName: String
    let quip: String
    let cloudType: String
    let weatherMood: String

    /// Where + when the Polaroid was taken, for the gallery captions.
    let city: String?
    let country: String?
    let temperatureF: Int?

    /// The user's note — capped at 500 chars. nil = no note yet.
    var note: String?

    /// Convenience — `note ?? ""` clamped to 500.
    static let noteCharacterLimit = 500

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        originalImageData: Data,
        developedImageData: Data? = nil,
        shapeName: String,
        quip: String,
        cloudType: String,
        weatherMood: String,
        city: String? = nil,
        country: String? = nil,
        temperatureF: Int? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.originalImageData = originalImageData
        self.developedImageData = developedImageData
        self.shapeName = shapeName
        self.quip = quip
        self.cloudType = cloudType
        self.weatherMood = weatherMood
        self.city = city
        self.country = country
        self.temperatureF = temperatureF
        self.note = note
    }

    /// Caption shown at the bottom of the Polaroid (gallery + reveal):
    /// "WHALE, DRIFTING · Brooklyn · Jul 14"
    var captionLine: String {
        var parts: [String] = [shapeName.uppercased()]
        if let city, !city.isEmpty { parts.append(city) }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        parts.append(f.string(from: createdAt))
        return parts.joined(separator: " · ")
    }
}
