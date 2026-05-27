import UserNotifications
import UIKit

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false

    private(set) var deviceToken: String?

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
            return granted
        } catch {
            return false
        }
    }

    func setDeviceToken(_ data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
    }

    // Store token in Supabase after auth — called from AppDelegate
    func syncDeviceToken() async {
        guard let token = deviceToken else { return }
        await SupabaseService.shared.updateDeviceToken(token)
    }
}
