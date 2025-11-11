import SwiftUI

@main
struct CloudoodleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var notificationService = NotificationService()

    init() {
        // Wire up notification service to app delegate
        // This allows AppDelegate to forward APNs callbacks
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationService)
                .onAppear {
                    // Connect notification service to app delegate
                    appDelegate.notificationService = notificationService
                }
        }
    }
}
