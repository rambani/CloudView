import SwiftUI

/// Page 07 — "Here's what tomorrow looks like". A staged Polaroid in
/// the actual format the user will get after their first scan,
/// pre-populated with today's date so the framing feels personal.
/// The "photo" is a procedural SkyBackdrop (no bundled imagery) and
/// the bottom-border weather is a believable stand-in.
///
/// Tap the card to cycle through a couple of shape names + palettes
/// so the user understands the variety without us having to ship a
/// library of demo photos.
struct DemoPage: View {
    var onContinue: () -> Void

    private struct Demo {
        let shapeName: String
        let palette: SkyBackdrop.Palette
        let conditions: String
        let temperatureF: Int
        /// Sample weather-aware quip — previews the voice the real
        /// AI quips use (shape + actual conditions in one line).
        let quip: String
    }

    private let demos: [Demo] = [
        Demo(shapeName: "a whale, drifting", palette: .day,
             conditions: "scattered cumulus", temperatureF: 72,
             quip: "Smooth sailing for this whale — not a ripple in the sky till sundown."),
        Demo(shapeName: "a sleeping dragon", palette: .sunset,
             conditions: "broken cloud", temperatureF: 65,
             quip: "Let the dragon sleep — rain rolls in within the hour."),
        Demo(shapeName: "a cotton-tailed rabbit", palette: .day,
             conditions: "clear sky", temperatureF: 78,
             quip: "78° and not a cloud to hide in — bold move, rabbit."),
        Demo(shapeName: "a sailboat, far horizon", palette: .day,
             conditions: "scattered cumulus", temperatureF: 70,
             quip: "A 12 mph westerly — perfect sailing weather, as it happens.")
    ]

    @State private var index = 0
    @State private var tilt: Double = -2.6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("HERE'S WHAT YOU'LL GET")
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.accentBlue)
                    .tracking(1.5)
                (Text("One frame. ") + Text("Stamped with the moment.").italic())
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Each Polaroid carries the date, the weather, the shape the AI noticed — and a line about how the two are getting along.")
                    .font(.system(size: 14))
                    .foregroundStyle(CV.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            polaroid
                .padding(.horizontal, 60)
                .padding(.top, 28)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sample Polaroid: \(currentDemo.shapeName)")
                .accessibilityHint("Double-tap to see another sample")
                .accessibilityAddTraits(.isButton)
                .onTapGesture { cycle() }

            Text("tap the Polaroid to see another sample")
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)

            Spacer(minLength: 0)

            PrimaryCTA(title: "Take my first sky", systemImage: "camera.fill", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Polaroid render

    /// Same visual language as `PolaroidCard` but rendered locally
    /// against synthetic data — we can't construct a real
    /// JournalEntry without an originalImageData payload, and we
    /// don't ship bundled cloud photos.
    private var polaroid: some View {
        let demo = currentDemo
        return VStack(spacing: 0) {
            // Top border — same date/time stamp pattern
            HStack(alignment: .firstTextBaseline) {
                Text(dayOfWeek)
                    .font(.system(size: 10, weight: .regular, design: .serif))
                    .italic()
                    .tracking(1.5)
                    .foregroundStyle(.black.opacity(0.55))
                Spacer(minLength: 6)
                Text(dateStamp)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.6))
                Text("·")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.3))
                Text(timeStamp)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Photo stage
            ZStack {
                SkyBackdrop(palette: demo.palette, cornerRadius: 0)
                RadialGradient(
                    colors: [.black.opacity(0), .black.opacity(0.18)],
                    center: .center, startRadius: 80, endRadius: 220
                )
                VStack {
                    Spacer()
                    HStack {
                        Text(demo.shapeName)
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.55), radius: 6, y: 1)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()

            // Bottom border — temp + conditions + weather-aware quip
            // (same three-line layout as the real PolaroidCard)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(demo.temperatureF)°")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(.black.opacity(0.78))
                    Text("\(demo.conditions) · sample")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.black.opacity(0.55))
                    Text(demo.quip)
                        .font(.system(size: 12.5, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.black.opacity(0.68))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .frame(minHeight: 64)
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
        .shadow(color: .black.opacity(0.30), radius: 8, y: 4)
        .rotationEffect(.degrees(tilt))
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: index)
    }

    private var currentDemo: Demo { demos[index % demos.count] }

    private var dayOfWeek: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return f.string(from: Date()).uppercased()
    }

    private var dateStamp: String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date()).uppercased()
    }

    private var timeStamp: String {
        let f = DateFormatter(); f.dateFormat = "h:mma"
        return f.string(from: Date()).lowercased()
    }

    private func cycle() {
        index = (index + 1) % demos.count
        // Mild tilt swap so each tap feels physical
        let amplitudes: [Double] = [-2.6, -1.2, -3.2, 0.8]
        tilt = amplitudes[index % amplitudes.count]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
