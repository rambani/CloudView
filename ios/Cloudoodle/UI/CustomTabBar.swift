import SwiftUI

struct CustomTabBar: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var supabase: SupabaseService

    var body: some View {
        HStack(spacing: 0) {
            tabButton(icon: "cloud.fill", label: "Feed", tab: .feed)
            captureButton
            tabButton(icon: "map.fill", label: "Map", tab: .map)
            tabButton(
                icon: supabase.isAuthenticated ? "person.fill" : "person",
                label: "Profile",
                tab: .profile
            )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
        .padding(.top, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    private func tabButton(icon: String, label: String, tab: AppState.Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .symbolEffect(.bounce, value: appState.selectedTab == tab)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(appState.selectedTab == tab ? CV.Color.accent : CV.Color.textTertiary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var captureButton: some View {
        Button {
            appState.selectedTab = .capture
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CV.Color.accent, CV.Color.accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: CV.Color.accent.opacity(0.4), radius: 12, y: 4)

                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -8)
        }
        .buttonStyle(.plain)
    }
}
