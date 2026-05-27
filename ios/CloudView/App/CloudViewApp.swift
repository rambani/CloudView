import SwiftUI
import Sentry

@main
struct CloudViewApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var appState = AppState.shared
    @StateObject private var supabase = SupabaseService.shared
    @StateObject private var location = LocationService.shared
    @StateObject private var notifications = NotificationService.shared

    init() {
        configureCrashReporting()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environmentObject(supabase)
                .environmentObject(location)
                .environmentObject(notifications)
                .preferredColorScheme(.dark)
                .onAppear {
                    supabase.configure()
                    location.startUpdating()
                    Task { await notifications.checkAuthorizationStatus() }
                }
        }
    }

    private func configureCrashReporting() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
              !dsn.isEmpty, !dsn.hasPrefix("$(") else { return }
        SentrySDK.start { options in
            options.dsn = dsn
            options.tracesSampleRate = 0.2   // 20% of sessions traced for performance
            options.enableAutoSessionTracking = true
        }
    }
}
