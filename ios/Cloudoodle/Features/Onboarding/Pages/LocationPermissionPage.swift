import SwiftUI

/// Page 04 — location prime. We trigger When-In-Use here since
/// nearby-sightings + per-spot weather both need it. As with camera,
/// "Maybe later" still advances; the map tab will re-prompt the user
/// the first time they open it without permission.
struct LocationPermissionPage: View {
    var onAdvance: () -> Void

    var body: some View {
        PermissionPageLayout(
            backdrop: .day,
            backdropOverlay: AnyView(LocationReticle()),
            eyebrow: "Location",
            headline: "Find the sky nearby",
            italicWord: "nearby",
            body: "See what cloud-spotters around you are finding, and get the forecast for exactly where you're standing.",
            chips: ["Local forecast", "Spotters near you", "Only while using"],
            primaryTitle: "Share location",
            primaryAction: {
                LocationService.shared.requestPermission()
                // requestPermission is fire-and-forget — iOS shows the
                // sheet, the delegate updates `authorizationStatus`. We
                // don't block onboarding on the user tapping the system
                // sheet; advance immediately.
                onAdvance()
            },
            secondaryTitle: "Maybe later",
            secondaryAction: onAdvance
        )
    }
}

/// Pulsing target dot + ring — visual cue that the page is about
/// location specifically. Matches the centered reticle in mock 04.
private struct LocationReticle: View {
    @State private var pulse: CGFloat = 0.6

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.65), lineWidth: 2)
                .frame(width: 80, height: 80)
                .scaleEffect(pulse)
                .opacity(2 - pulse)
            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .shadow(color: .black.opacity(0.15), radius: 4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = 1.6
            }
        }
    }
}
