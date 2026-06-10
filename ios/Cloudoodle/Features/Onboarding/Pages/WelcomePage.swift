import SwiftUI

/// Page 01 — first impression. A serif title over a soft sky gradient
/// with the central artefact of the product (a Polaroid) angled into
/// view. Sells the daily-ritual framing in one screen: one moment
/// with the sky, kept as a print.
struct WelcomePage: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                SkyBackdrop(palette: .day, cornerRadius: 0)
                    .frame(maxHeight: .infinity)
                heroPolaroid
                    .padding(.bottom, 36)
                    .padding(.horizontal, 56)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 14) {
                Text("ONE FRAME OF THE SKY")
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.textTertiary)
                    .tracking(2)

                (Text("Cloud") + Text("oodle").italic())
                    .scaledFont(size: 44, weight: .regular, design: .serif)
                    .foregroundStyle(CV.Color.textPrimary)

                Text("A daily Polaroid of whatever's drifting overhead.")
                    .scaledFont(size: 16, weight: .regular, design: .serif)
                    .italic()
                    .foregroundStyle(CV.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                PrimaryCTA(title: "Begin", systemImage: "arrow.right", action: onContinue)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }
            .padding(.bottom, 36)
            .background(Color.black)
        }
        .ignoresSafeArea(edges: .top)
    }

    /// A small, tilted Polaroid floating above the sky backdrop. Made
    /// of vanilla SwiftUI shapes so no image assets are needed — the
    /// "photo" is a smaller SkyBackdrop in a warmer palette so it
    /// reads as a captured moment, not the live sky behind it.
    private var heroPolaroid: some View {
        VStack(spacing: 0) {
            HStack {
                Text("THURSDAY")
                    .scaledFont(size: 8, weight: .regular, design: .serif)
                    .italic()
                    .tracking(1.5)
                    .foregroundStyle(.black.opacity(0.55))
                Spacer()
                Text("JUN 6, 2026 · 4:18pm")
                    .scaledFont(size: 8, weight: .medium, design: .monospaced)
                    .foregroundStyle(.black.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 6)

            ZStack {
                SkyBackdrop(palette: .sunset, cornerRadius: 0)
                RadialGradient(
                    colors: [.black.opacity(0), .black.opacity(0.20)],
                    center: .center, startRadius: 30, endRadius: 110
                )
                VStack {
                    Spacer()
                    HStack {
                        Text("a whale, drifting")
                            .scaledFont(size: 11, weight: .regular, design: .serif)
                            .italic()
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("72°")
                        .scaledFont(size: 17, weight: .regular, design: .serif)
                        .foregroundStyle(.black.opacity(0.78))
                    Text("scattered cumulus · brooklyn")
                        .scaledFont(size: 9, weight: .regular, design: .serif)
                        .italic()
                        .foregroundStyle(.black.opacity(0.55))
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 7)
            .padding(.bottom, 10)
            .frame(minHeight: 48)
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.50), radius: 26, y: 16)
        .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
        .rotationEffect(.degrees(-3.2))
    }
}
