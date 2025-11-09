import Foundation
import CoreLocation

/// Privacy-preserving scan reporting service
/// Reports ONLY: region, date, and drawing category
/// NO user IDs, device IDs, or exact locations
class ScanReportingService {
    static let shared = ScanReportingService()

    // Backend API endpoint (configured with Vercel deployment)
    private var backendURL = "https://cloud-view-backend.vercel.app/api/report-scan"
    private var isEnabled = true // Backend is now live!

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

        // Get region from location (city level, not exact coordinates)
        let region = extractRegion(from: location)

        // Categorize the drawing
        let category = DrawingCategory.categorize(drawingName: drawingName)

        // Create anonymous report
        let report = AnonymousScanReport(
            region: region,
            category: category.rawValue,
            timestamp: Date()
        )

        // Send to backend
        sendReportToBackend(report)
    }

    // MARK: - Privacy-Preserving Location

    private func extractRegion(from location: CLLocation?) -> String {
        guard let location = location else {
            return "Unknown"
        }

        // Convert coordinates to city/region name using reverse geocoding
        // This ensures we only send city-level data, not exact coordinates
        let geocoder = CLGeocoder()

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let city = placemarks?.first?.locality {
                // Have city name, could update report if needed
                print("Region detected: \(city)")
            }
        }

        // For now, return a placeholder
        // In production, this would wait for geocoding result
        return "Unknown"
    }

    // MARK: - Backend Communication

    private func sendReportToBackend(_ report: AnonymousScanReport) {
        guard let url = URL(string: backendURL) else {
            print("Invalid backend URL")
            return
        }

        var request = URLRequest(url: url)
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

    /// Enable scan reporting (when backend is deployed)
    func enable(withBackendURL url: String) {
        backendURL = url
        isEnabled = true
        print("Scan reporting enabled with backend: \(url)")
    }

    /// Disable scan reporting
    func disable() {
        isEnabled = false
        print("Scan reporting disabled")
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
