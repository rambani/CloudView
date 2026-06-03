import SwiftUI

/// Camera / Location / Notifications share the same skeleton:
/// hero image, eyebrow label, italic-serif headline, body copy,
/// chip row of feature highlights, primary CTA, optional secondary CTA.
/// Factored out so each page reads as data + handlers, not layout code.
struct PermissionPageLayout: View {
    let backdrop: SkyBackdrop.Palette
    let backdropOverlay: AnyView?
    let eyebrow: String
    let headline: String           // can contain italic via the `italicWord` arg
    let italicWord: String?        // word inside `headline` to render in serif italic
    let bodyText: String
    let chips: [String]
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                SkyBackdrop(palette: backdrop)
                if let backdropOverlay {
                    backdropOverlay
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text(eyebrow.uppercased())
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.accentBlue)
                    .tracking(1.5)

                headlineView
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(bodyText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(CV.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                FlowingChips(items: chips)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                PrimaryCTA(title: primaryTitle, action: primaryAction)
                if let secondaryTitle, let secondaryAction {
                    SecondaryCTA(title: secondaryTitle, action: secondaryAction)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    /// Headline with optional italic-serif span. The match is case-insensitive
    /// and falls back to plain rendering if the word isn't found.
    @ViewBuilder
    private var headlineView: some View {
        if let italicWord, let range = headline.range(of: italicWord, options: .caseInsensitive) {
            let prefix = String(headline[..<range.lowerBound])
            let match = String(headline[range])
            let suffix = String(headline[range.upperBound...])
            Text(prefix)
                + Text(match).italic()
                + Text(suffix)
        } else {
            Text(headline)
        }
    }
}

/// Pill chips that wrap to multiple lines. The first chip gets the
/// accent fill to mirror the "selected" state in the mocks.
struct FlowingChips: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                Text(item)
                    .font(CV.Font.caption)
                    .foregroundStyle(i == 0 ? CV.Color.accentBlue : CV.Color.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(
                            i == 0
                            ? CV.Color.accentBlue.opacity(0.12)
                            : Color.white.opacity(0.06)
                        )
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            i == 0 ? CV.Color.accentBlue.opacity(0.35) : Color.white.opacity(0.10),
                            lineWidth: 0.5
                        )
                    )
            }
        }
    }
}

/// Simple horizontal flow layout that wraps when a row runs out of width.
/// Used for the chip row on permission pages and username suggestions.
/// Pre-iOS 16 you'd need a custom GeometryReader; iOS 16+ Layout makes
/// this trivial.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxX - spacing, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
