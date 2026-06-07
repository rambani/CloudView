import SwiftUI

/// App-wide state that doesn't belong to a specific feature. Kept
/// small on purpose — most app state lives in the singletons that
/// own a domain (JournalStore, SubscriptionService, LocationService).
@Observable
final class AppState {
    static let shared = AppState()

    /// Toast banner shown at the top of the root view. Currently
    /// driven by the daily reminder notification tap (the user taps
    /// the push and lands in the app — we surface a brief banner
    /// linking back to today's view or the gallery). Nil = no toast.
    var incomingNotification: NotificationAlert?

    struct NotificationAlert: Equatable {
        let title: String
        let body: String
    }
}
