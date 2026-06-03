import SwiftUI

/// 5-segment progress bar matching the mocks: filled bars for completed
/// steps + the current one, hollow outlines for the steps still to come.
struct OnboardingProgressBar: View {
    let current: Int   // 1-indexed
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? CV.Color.textPrimary : CV.Color.textPrimary.opacity(0.15))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: current)
            }
        }
    }
}
