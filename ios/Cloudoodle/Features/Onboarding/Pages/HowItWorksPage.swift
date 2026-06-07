import SwiftUI

/// Page 02 — three numbered cards that explain the daily ritual.
/// Mirrors the actual loop: point, develop, keep. Each card pairs a
/// small SkyBackdrop thumbnail with one sentence so the visual rhythm
/// holds without depending on bitmap assets.
struct HowItWorksPage: View {
    var onContinue: () -> Void

    private struct Item {
        let index: String
        let title: String
        let body: String
        let palette: SkyBackdrop.Palette
    }

    private let items: [Item] = [
        .init(
            index: "01",
            title: "Look up. Take one photo.",
            body: "Aim at any patch of sky. One frame is all you need.",
            palette: .day
        ),
        .init(
            index: "02",
            title: "We develop it into a Polaroid.",
            body: "AI finds a shape in the clouds, stamps the date and weather, hands it back.",
            palette: .day
        ),
        .init(
            index: "03",
            title: "Keep your stack. One per day.",
            body: "Write a few lines if you'd like. Tomorrow brings a fresh sky.",
            palette: .sunset
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("HOW IT WORKS")
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.textTertiary)
                    .tracking(2)

                (Text("Five minutes with ") + Text("the sky.").italic())
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            VStack(spacing: 14) {
                ForEach(items.indices, id: \.self) { i in
                    card(items[i])
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "infinity")
                    .foregroundStyle(CV.Color.accentBlue)
                    .font(.system(size: 13))
                    .padding(.top, 2)
                (Text("One Polaroid a day is free. ").italic()
                    + Text("Unlimited is a small monthly thing.").italic())
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(CV.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            PrimaryCTA(title: "Got it", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
    }

    private func card(_ item: Item) -> some View {
        HStack(spacing: 14) {
            SkyBackdrop(palette: item.palette, cornerRadius: 14)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.index)
                        .font(CV.Font.mono)
                        .foregroundStyle(CV.Color.accentBlue)
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CV.Color.textPrimary)
                }
                Text(item.body)
                    .font(.system(size: 13))
                    .foregroundStyle(CV.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}
