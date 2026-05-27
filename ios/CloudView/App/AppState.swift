import SwiftUI

@Observable
final class AppState {
    static let shared = AppState()

    var selectedTab: Tab = .feed
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
