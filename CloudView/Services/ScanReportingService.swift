import Foundation
import CoreLocation

/// Privacy-preserving scan reporting service
/// Reports ONLY: region, date, and drawing category
/// NO user IDs, device IDs, or exact locations
///
/// Disabled by default — kids' / 4+ apps cannot send telemetry without
/// explicit consent. The user enables this from the consent flow at first
/// launch; the preference is persisted in UserDefaults so it survives
/// reinstalls within the same iCloud account.
class ScanReportingService {
    static let shared = ScanReportingService()

    private static let consentKey = "ScanReporting.userConsented"

    // Backend API endpoint — points at BackendConfig by default.
    private var backendURL: URL = BackendConfig.reportScanURL

    /// Whether the user has explicitly opted in to anonymous community
    /// scan-reporting. Defaults to false; persists across app launches.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.consentKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.consentKey) }
    }

    private init() {}

    // MARK: - Anonymous Scan Reporting

    /// Reports a drawing scan anonymously to the backend
    /// - Parameters:
    ///   - drawingName: Name of the drawing created
    ///   - location: User's approximate location (will be converted to city/region)
    func reportScan(drawingName: String, location: CLLocation?) {
        guard isEnabled else {
            print("Scan reporting disabled (backend not configured)")
            return
        }

        let category = DrawingCategory.categorize(drawingName: drawingName)

        Task {
            let region = await extractRegion(from: location)

            let report = AnonymousScanReport(
                region: region,
                category: category.rawValue,
                timestamp: Date()
            )

            sendReportToBackend(report)
        }
    }

    // MARK: - Privacy-Preserving Location

    // Cache geocoded region briefly so we don't hammer CLGeocoder (it's rate-limited).
    private var cachedRegion: (location: CLLocation, region: String, expiresAt: Date)?
    private let regionCacheTTL: TimeInterval = 600 // 10 minutes

    private func extractRegion(from location: CLLocation?) async -> String {
        guard let location = location else {
            return "Unknown"
        }

        // Serve from cache if the user hasn't moved much and the entry is fresh.
        if let cached = cachedRegion,
           cached.expiresAt > Date(),
           cached.location.distance(from: location) < 5_000 {
            return cached.region
        }

        let region = await reverseGeocode(location)
        cachedRegion = (location, region, Date().addingTimeInterval(regionCacheTTL))
        return region
    }

    private func reverseGeocode(_ location: CLLocation) async -> String {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            // Prefer city, fall back to admin area (state/region), then country.
            if let placemark = placemarks.first {
                return placemark.locality
                    ?? placemark.administrativeArea
                    ?? placemark.country
                    ?? "Unknown"
            }
        } catch {
            print("Reverse geocoding failed: \(error.localizedDescription)")
        }
        return "Unknown"
    }

    // MARK: - Backend Communication

    private func sendReportToBackend(_ report: AnonymousScanReport) {
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(report)
            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error sending scan report: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("Scan report sent successfully")
                    } else {
                        print("Scan report failed with status: \(httpResponse.statusCode)")
                    }
                }
            }

            task.resume()

        } catch {
            print("Error encoding scan report: \(error.localizedDescription)")
        }
    }

    // MARK: - Configuration

    /// Override the default backend URL (useful for tests / staging). The
    /// per-user consent flag is independent of which backend we talk to.
    func setBackendURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Ignoring invalid backend URL: \(urlString)")
            return
        }
        backendURL = url
    }

}

// MARK: - Data Models

/// Anonymous scan report sent to backend
/// Contains ONLY non-identifying information
struct AnonymousScanReport: Codable {
    let region: String           // City/region name (e.g., "San Francisco")
    let category: String         // Drawing category (e.g., "animals")
    let timestamp: Date          // When the scan occurred

    // NO user ID
    // NO device ID
    // NO exact coordinates
    // NO personal information
}

/// Regional activity summary (what backend returns)
struct RegionalActivity: Codable {
    let region: String
    let date: String
    let categories: [String: Int]  // e.g., {"animals": 23, "mythical": 15}
    let totalScans: Int
}

// MARK: - Backend Requirements Documentation

/*
 Backend API Requirements:

 1. POST /api/scans/report
    - Receives AnonymousScanReport
    - Aggregates by region + date
    - Returns 200 OK

 2. GET /api/scans/regional-activity?region=<city>
    - Returns RegionalActivity for given region
    - Used to determine if notifications should be sent

 3. Push Notification Service:
    - Monitors regional activity
    - When thresholds met (e.g., >20 animals in region today):
      * Sends push notification to users in that region
      * Message: "Lots of animals spotted in clouds near you today! 🦁☁️"

 4. Data Storage:
    - Store only: region, date, category, count
    - NO user identifiable information
    - Aggregate data daily
    - Delete detailed records after 24 hours

 5. Privacy Guarantees:
    - No user tracking
    - No cross-session correlation
    - City-level granularity only
    - Fully anonymous

 Example Backend Stack:
    - Firebase Cloud Functions
    - Firestore (aggregated data only)
    - Firebase Cloud Messaging (push notifications)
    - Privacy-first design

 Alternative: AWS Lambda + DynamoDB + SNS
 Alternative: Custom Node.js API + MongoDB + APNs
*/
