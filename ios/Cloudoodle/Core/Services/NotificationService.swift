import UserNotifications
import UIKit

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false

    private(set) var deviceToken: String?

    /// True once the current token has actually been written to the
    /// signed-in user's profile row. DailyReminderService checks this
    /// before suppressing the local notification — until the server
    /// can deliver a push, the local reminder stays canonical.
    private(set) var hasSyncedDeviceToken = false

    private static let promptShownKey = "cv_notification_prompt_shown"

    // Whether the user has already seen our in-app prompt (not the system dialog)
    var hasSeenPrompt: Bool {
        get { UserDefaults.standard.bool(forKey: Self.promptShownKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.promptShownKey) }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    @discardableResult
    func requestPermission() async -> Bool {
        hasSeenPrompt = true
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            Telemetry.notificationsGranted(granted)
            return granted
        } catch {
            Telemetry.notificationsGranted(false)
            return false
        }
    }

    func setDeviceToken(_ data: Data) {
        let fresh = data.map { String(format: "%02x", $0) }.joined()
        if fresh != deviceToken { hasSyncedDeviceToken = false }
        deviceToken = fresh
    }

    /// Called when the profile's device_token is cleared (sign-out)
    /// so the next session knows the server can't push yet.
    func invalidateTokenSync() {
        hasSyncedDeviceToken = false
    }

    // Store token in Supabase after auth — called from AppDelegate
    func syncDeviceToken() async {
        guard let token = deviceToken else { return }
        if await SupabaseService.shared.updateDeviceToken(token) {
            hasSyncedDeviceToken = true
        }
    }
}
