import SwiftUI

/// Big dark pill button — primary CTA on every onboarding page.
/// Matches the mocks: ~52pt tall, white text, fills width.
struct PrimaryCTA: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule().fill(Color(white: 0.08))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }
}

/// Plain text secondary CTA — "Not now", "No thanks", "Maybe later".
/// Subdued enough that the primary action is obviously preferred.
struct SecondaryCTA: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CV.Color.textSecondary)
                .frame(height: 36)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}
