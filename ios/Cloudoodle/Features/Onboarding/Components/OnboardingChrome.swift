import SwiftUI

/// Top-of-page strip: circular back button on the left, progress bar
/// in the middle, and a small "Skip" link on the right for users who
/// already know the app and don't want to walk the full flow. Shown
/// on every step except welcome and the trailing demo/finished steps.
/// The back button hides on the first chrome-visible step (HowItWorks)
/// so users don't accidentally pop back into the welcome screen.
struct OnboardingChrome: View {
    @Bindable var store: OnboardingStore
    var onSkip: () -> Void

    var showsBack: Bool {
        store.step != .howItWorks
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CV.Color.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
            .opacity(showsBack ? 1 : 0)
            .disabled(!showsBack)
            .accessibilityLabel("Back")

            if let idx = store.step.progressIndex {
                OnboardingProgressBar(current: idx, total: OnboardingStore.Step.progressTotal)
                    .accessibilityLabel("Step \(idx) of \(OnboardingStore.Step.progressTotal)")
            } else {
                Spacer()
            }

            Button("Skip", action: onSkip)
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textTertiary)
                .accessibilityLabel("Skip onboarding")
                .accessibilityHint("Jumps straight to the app — you can grant permissions later")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}
