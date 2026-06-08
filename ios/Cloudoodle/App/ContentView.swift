import SwiftUI

/// Root view. Cloudoodle is a single-surface app — no tabs, no
/// chrome. Opening the app drops you straight at the camera (or
/// today's developed Polaroid if you've already captured). Swipe
/// right inside that surface reaches the gallery; swipe up reaches
/// the weather drawer; a gear icon opens Settings.
///
/// The only things rendered above the home surface are the
/// onboarding flow on first launch, and a brief toast banner when
/// the user opens the app from a notification.
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    /// Lives at ContentView scope so a user backing through pages keeps
    /// their draft username and progress; recreated only on first launch.
    @State private var onboardingStore = OnboardingStore()

    var body: some View {
        CaptureRootView()
            .overlay(alignment: .top) {
                if let alert = appState.incomingNotification {
                    NotificationToast(alert: alert) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            appState.incomingNotification = nil
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85),
                       value: appState.incomingNotification != nil)
            .fullScreenCover(isPresented: Binding(
                get: { !hasOnboarded },
                set: { newValue in if newValue == false { hasOnboarded = true } }
            )) {
                OnboardingFlowView(store: onboardingStore) {
                    hasOnboarded = true
                }
            }
    }
}

private struct NotificationToast: View {
    let alert: AppState.NotificationAlert
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 15))
                .foregroundStyle(CV.Color.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(CV.Color.accent.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                if !alert.title.isEmpty {
                    Text(alert.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CV.Color.textPrimary)
                }
                Text(alert.body)
                    .font(.system(size: 12))
                    .foregroundStyle(CV.Color.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CV.Color.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .accessibilityLabel("Dismiss notification")
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CV.Color.glassBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .task {
            try? await Task.sleep(for: .seconds(5))
            onDismiss()
        }
    }
}
