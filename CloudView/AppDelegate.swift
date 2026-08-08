import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // On a cold launch from a notification tap, didReceive can fire before
    // ContentView wires the service in — buffer the tap and deliver it as
    // soon as the service arrives.
    var notificationService: NotificationService? {
        didSet {
            if let pending = pendingNotificationTap {
                notificationService?.handleNotificationTap(userInfo: pending)
                pendingNotificationTap = nil
            }
        }
    }
    private var pendingNotificationTap: [AnyHashable: Any]?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Start MetricKit subscription so we get crash / hang / energy
        // payloads from iOS. Payloads are persisted locally; nothing is
        // uploaded. See DiagnosticsService for retention + access details.
        DiagnosticsService.shared.start()

        return true
    }

    // MARK: - Remote Notification Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Forward to NotificationService
        notificationService?.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Forward to NotificationService
        notificationService?.didFailToRegisterForRemoteNotifications(error: error)
    }

    // MARK: - Handle Incoming Notifications

    // Called when notification arrives while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Greet the arrival in-app so the tap connects to the sky above
        // instead of landing cold on the camera.
        if let service = notificationService {
            service.handleNotificationTap(userInfo: userInfo)
        } else {
            pendingNotificationTap = userInfo
        }

        completionHandler()
    }
}
