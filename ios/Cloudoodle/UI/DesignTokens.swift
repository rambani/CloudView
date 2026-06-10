import SwiftUI
import UIKit

enum CV {
    // MARK: - Typography
    //
    // All tokens scale with the user's Dynamic Type setting. Fixed
    // sizes are mapped to the nearest semantic text style (caption =
    // 12pt, footnote = 13pt, title3 = 20pt at default size); the
    // quip font scales relative to body via Font.custom(relativeTo:).
    enum Font {
        static let ui = SwiftUI.Font.system(.body, design: .default, weight: .regular)
        static let quip = SwiftUI.Font.custom("Georgia-Italic", size: 17, relativeTo: .body)
        static let shapeName = SwiftUI.Font.system(.footnote, design: .monospaced, weight: .medium)
        static let headline = SwiftUI.Font.system(.title3, design: .default, weight: .semibold)
        static let caption = SwiftUI.Font.system(.caption, design: .default, weight: .regular)
        static let mono = SwiftUI.Font.system(.caption, design: .monospaced)
    }

    // MARK: - Colors
    enum Color {
        static let glassBackground = SwiftUI.Color.white.opacity(0.12)
        static let glassBorder = SwiftUI.Color.white.opacity(0.18)
        static let textPrimary = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color.white.opacity(0.65)
        static let textTertiary = SwiftUI.Color.white.opacity(0.4)
        static let accent = SwiftUI.Color(red: 0.98, green: 0.85, blue: 0.55) // warm gold
        static let accentBlue = SwiftUI.Color(red: 0.55, green: 0.78, blue: 0.98)
        static let drawingStroke = SwiftUI.Color.white
        static let scanLine = SwiftUI.Color.cyan
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 22
        static let pill: CGFloat = 100
    }

    // MARK: - Glass Material
    struct GlassModifier: ViewModifier {
        var intensity: Double = 1.0
        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: CV.Radius.lg)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: CV.Radius.lg)
                                .strokeBorder(CV.Color.glassBorder, lineWidth: 0.5)
                        )
                )
        }
    }
}

extension View {
    func glassCard() -> some View {
        modifier(CV.GlassModifier())
    }
}

// MARK: - Dynamic Type support for point-sized fonts

/// `Font.system(size:)` is FIXED — it ignores the user's Dynamic
/// Type setting entirely. This modifier wraps the same parameters
/// but scales the point size through UIFontMetrics, and reads the
/// size category from the environment so it re-renders live when
/// the user changes their text size.
///
/// UI chrome should use `.scaledFont(...)`; the Polaroid print's
/// stamp text intentionally stays fixed (it's part of the artifact,
/// like text inside a photograph — see PolaroidCard).
private struct ScaledFont: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        content.font(.system(size: scaled, weight: weight, design: design))
    }
}

extension View {
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}

// MARK: - Watchability Bar
struct WatchabilityBar: View {
    let score: Int
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 16, height: 4)
                    .foregroundStyle(i <= score ? CV.Color.accent : CV.Color.textTertiary)
            }
        }
    }
}
