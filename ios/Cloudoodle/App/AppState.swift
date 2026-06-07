import SwiftUI

@Observable
final class AppState {
    static let shared = AppState()

    /// Opens to the capture tab — Cloudoodle's daily ritual starts at
    /// the camera (or today's developed Polaroid if you've already
    /// captured). The other tabs are secondary destinations.
    var selectedTab: Tab = .capture
    var pendingSighting: CloudSighting?
    var analysisError: Error?
    var incomingNotification: NotificationAlert?

    enum Tab: Hashable {
        case feed, capture, map, profile
    }

    struct NotificationAlert {
        let sightingId: UUID
        let body: String   // notification body text, e.g. "'Dragon' spotted near London just now"
    }
}
