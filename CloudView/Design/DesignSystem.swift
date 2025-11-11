import SwiftUI

// MARK: - Color System

extension Color {
    // Sky Blues - Soft and dreamy
    static let cloudBlue = Color(red: 0.4, green: 0.7, blue: 1.0)
    static let skyMist = Color(red: 0.6, green: 0.8, blue: 1.0)
    static let deepSky = Color(red: 0.2, green: 0.5, blue: 0.9)

    // Magical Accents - Playful and vibrant
    static let cloudPink = Color(red: 1.0, green: 0.7, blue: 0.9)
    static let sunGlow = Color(red: 1.0, green: 0.85, blue: 0.4)
    static let lavenderDream = Color(red: 0.75, green: 0.6, blue: 1.0)

    // Glass Effects - Translucent layers
    static let glassBorder = Color.white.opacity(0.25)
    static let glassHighlight = Color.white.opacity(0.15)
    static let glassShadow = Color.black.opacity(0.1)
}

// MARK: - Gradient Presets

extension LinearGradient {
    // Sky gradient - Main theme
    static let cloudoodleSky = LinearGradient(
        colors: [Color.cloudBlue, Color.skyMist],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Magical accent - For special moments
    static let magicalGlow = LinearGradient(
        colors: [Color.sunGlow, Color.cloudPink, Color.lavenderDream],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Subtle shine - For glass borders
    static let glassShine = LinearGradient(
        colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography System

extension Font {
    // Display - Large, bold statements
    static let cloudoodleDisplay = Font.system(size: 32, weight: .bold, design: .rounded)

    // Title - Section headers
    static let cloudoodleTitle = Font.system(size: 24, weight: .semibold, design: .rounded)

    // Body - Main content
    static let cloudoodleBody = Font.system(size: 16, weight: .medium, design: .rounded)

    // Caption - Supporting text
    static let cloudoodleCaption = Font.system(size: 14, weight: .regular, design: .rounded)

    // Mini - Tiny labels
    static let cloudoodleMini = Font.system(size: 12, weight: .medium, design: .rounded)
}

// MARK: - Spacing System

extension CGFloat {
    // Consistent spacing scale
    static let spacing_xs: CGFloat = 4
    static let spacing_sm: CGFloat = 8
    static let spacing_md: CGFloat = 16
    static let spacing_lg: CGFloat = 24
    static let spacing_xl: CGFloat = 32
    static let spacing_xxl: CGFloat = 48

    // Border radii
    static let radius_sm: CGFloat = 12
    static let radius_md: CGFloat = 16
    static let radius_lg: CGFloat = 20
    static let radius_xl: CGFloat = 24
    static let radius_pill: CGFloat = 999
}

// MARK: - Animation Presets

extension Animation {
    // Bouncy spring - For buttons and interactions
    static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)

    // Smooth ease - For panel transitions
    static let smooth = Animation.easeInOut(duration: 0.4)

    // Gentle float - For ambient animations
    static let gentle = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)

    // Quick snap - For immediate feedback
    static let snap = Animation.spring(response: 0.2, dampingFraction: 0.8)
}

// MARK: - Glass Card Component

struct GlassCard<Content: View>: View {
    let content: Content
    let borderGradient: LinearGradient
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat

    init(
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 12,
        borderGradient: LinearGradient = .glassShine,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.borderGradient = borderGradient
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Subtle inner glow
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                }
            )
            .overlay(
                // Glass border with gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderGradient, lineWidth: 1.5)
            )
            .shadow(color: Color.glassShadow, radius: shadowRadius, x: 0, y: shadowRadius / 2)
    }
}

// MARK: - Floating Animation

struct FloatingModifier: ViewModifier {
    @State private var isFloating = false
    let duration: Double
    let distance: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -distance : 0)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                ) {
                    isFloating = true
                }
            }
    }
}

extension View {
    func floating(duration: Double = 2.0, distance: CGFloat = 5) -> some View {
        modifier(FloatingModifier(duration: duration, distance: distance))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 400)
                .offset(x: phase - 200)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 2.0)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Bouncy Button Style

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.bouncy, value: configuration.isPressed)
    }
}

// MARK: - Enhanced Contextual Hint

struct MagicalHintView: View {
    let icon: String
    let message: String
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        GlassCard(
            cornerRadius: .radius_xl + 4,
            borderGradient: LinearGradient(
                colors: [color.opacity(0.4), color.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            HStack(spacing: .spacing_md) {
                // Pulsing icon with glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 0.5)

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isPulsing ? 1.05 : 1.0)
                }

                Text(message)
                    .font(.cloudoodleBody)
                    .foregroundColor(.white)

                // Trailing sparkle
                Image(systemName: "sparkle")
                    .font(.cloudoodleMini)
                    .foregroundColor(color.opacity(0.7))
                    .floating(duration: 1.5, distance: 3)
            }
            .padding(.horizontal, .spacing_lg)
            .padding(.vertical, .spacing_md)
        }
        .onAppear {
            withAnimation(.gentle) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Magical Loading View

struct EnhancedMagicalLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: .spacing_lg) {
            // Layered clouds animation
            ZStack {
                ForEach(0..<3) { index in
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 40 + CGFloat(index * 10)))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3 - Double(index) * 0.1),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .offset(y: isAnimating ? -20 : 20)
                        .animation(
                            Animation.easeInOut(duration: 2.0 + Double(index) * 0.3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            .frame(height: 120)

            // Shimmer text
            Text("Finding clouds...")
                .font(.cloudoodleBody)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .shimmer()

            // Sparkle particles
            HStack(spacing: .spacing_sm) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(LinearGradient.magicalGlow)
                        .frame(width: 6, height: 6)
                        .opacity(isAnimating ? 1.0 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.1),
                            value: isAnimating
                        )
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
