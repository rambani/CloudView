import SwiftUI

/// Page 07 — "First doodle". Shows the user a real-shaped sighting card
/// before they ever lift the camera, so the first scan they do feels
/// familiar instead of cold-launch. Uses the real HandDrawingView so
/// the doodle animation matches what they'll get after a scan.
///
/// We rotate through a small library of synthetic sightings so users
/// who back-out + re-enter the page (or who reinstall) see something
/// fresh each time instead of the same hand-tuned whale every visit.
struct DemoPage: View {
    var onContinue: () -> Void

    /// Hand-tuned synthetic sightings. Coordinates are normalized
    /// 0–1 on the procedural sky backdrop, the same way Gemini
    /// returns them. Quips written to feel like the on-device
    /// template-quip pool — playful, one sentence.
    private static let demoLibrary: [CloudSighting] = [
        whaleDemo,
        dragonDemo,
        bunnyDemo,
        sailboatDemo,
    ]

    private static var whaleDemo: CloudSighting {
        CloudSighting(
            analysis: CloudAnalysis(
                shapeName: "Whale, drifting",
                quip: "A cumulus whale is taking the slow lane toward the horizon, tail flicking lazy as a daydream.",
                cloudType: "Cumulus",
                weatherMood: "Calm",
                watchabilityScore: 8
            ),
            drawingElements: [
                .init(points: [[0.18, 0.52], [0.28, 0.45], [0.40, 0.42], [0.55, 0.42], [0.68, 0.45], [0.78, 0.50]],
                      smooth: true, strokeWidth: 2.6, label: "body"),
                .init(points: [[0.78, 0.50], [0.88, 0.42], [0.92, 0.50], [0.85, 0.56]],
                      smooth: true, strokeWidth: 2.2, label: "tail"),
                .init(points: [[0.18, 0.52], [0.14, 0.58], [0.22, 0.60], [0.30, 0.56]],
                      smooth: true, strokeWidth: 2.0, label: "head"),
                .init(points: [[0.40, 0.50], [0.42, 0.56], [0.50, 0.58], [0.55, 0.54]],
                      smooth: true, strokeWidth: 1.8, label: "fin"),
            ],
            drawingLabelX: 0.50, drawingLabelY: 0.28
        )
    }

    private static var dragonDemo: CloudSighting {
        CloudSighting(
            analysis: CloudAnalysis(
                shapeName: "Sleeping dragon",
                quip: "Cumulus has produced a dragon, dozing in the warm air with one wing half-stretched.",
                cloudType: "Cumulus",
                weatherMood: "Dreamy",
                watchabilityScore: 9
            ),
            drawingElements: [
                .init(points: [[0.20, 0.50], [0.32, 0.44], [0.46, 0.42], [0.60, 0.45], [0.72, 0.50]],
                      smooth: true, strokeWidth: 2.6, label: "body"),
                .init(points: [[0.72, 0.50], [0.78, 0.42], [0.82, 0.38]],
                      smooth: true, strokeWidth: 2.2, label: "neck"),
                .init(points: [[0.82, 0.38], [0.86, 0.34], [0.90, 0.36], [0.87, 0.42]],
                      smooth: true, strokeWidth: 2.0, label: "head"),
                .init(points: [[0.20, 0.50], [0.10, 0.55], [0.06, 0.62], [0.08, 0.70]],
                      smooth: true, strokeWidth: 1.8, label: "tail"),
                .init(points: [[0.46, 0.42], [0.46, 0.30], [0.56, 0.26], [0.60, 0.34]],
                      smooth: true, strokeWidth: 1.6, label: "wing"),
            ],
            drawingLabelX: 0.50, drawingLabelY: 0.20
        )
    }

    private static var bunnyDemo: CloudSighting {
        CloudSighting(
            analysis: CloudAnalysis(
                shapeName: "Sleepy bunny",
                quip: "Cotton-tailed and curled into a nap, the clouds couldn't have phrased it more clearly.",
                cloudType: "Cumulus",
                weatherMood: "Gentle",
                watchabilityScore: 7
            ),
            drawingElements: [
                .init(points: [[0.28, 0.62], [0.30, 0.50], [0.42, 0.46], [0.58, 0.46], [0.68, 0.52], [0.66, 0.64], [0.50, 0.68], [0.34, 0.66]],
                      smooth: true, strokeWidth: 2.6, label: "body"),
                .init(points: [[0.38, 0.46], [0.34, 0.34], [0.40, 0.30], [0.44, 0.42]],
                      smooth: true, strokeWidth: 2.2, label: "ear-left"),
                .init(points: [[0.54, 0.46], [0.58, 0.32], [0.64, 0.30], [0.60, 0.42]],
                      smooth: true, strokeWidth: 2.2, label: "ear-right"),
                .init(points: [[0.68, 0.62], [0.74, 0.66], [0.74, 0.58], [0.70, 0.56]],
                      smooth: true, strokeWidth: 1.8, label: "tail"),
            ],
            drawingLabelX: 0.50, drawingLabelY: 0.24
        )
    }

    private static var sailboatDemo: CloudSighting {
        CloudSighting(
            analysis: CloudAnalysis(
                shapeName: "Sailboat, far horizon",
                quip: "A single mast slants across the cumulus, sails full of imaginary wind.",
                cloudType: "Cumulus",
                weatherMood: "Hopeful",
                watchabilityScore: 7
            ),
            drawingElements: [
                .init(points: [[0.30, 0.62], [0.38, 0.58], [0.62, 0.58], [0.70, 0.62], [0.58, 0.66], [0.42, 0.66]],
                      smooth: true, strokeWidth: 2.6, label: "hull"),
                .init(points: [[0.50, 0.58], [0.50, 0.30]],
                      smooth: false, strokeWidth: 2.2, label: "mast"),
                .init(points: [[0.50, 0.32], [0.36, 0.46], [0.50, 0.50]],
                      smooth: true, strokeWidth: 2.0, label: "sail-fore"),
                .init(points: [[0.50, 0.30], [0.66, 0.44], [0.50, 0.50]],
                      smooth: true, strokeWidth: 2.0, label: "sail-main"),
            ],
            drawingLabelX: 0.50, drawingLabelY: 0.18
        )
    }

    @State private var replayKey = UUID()
    @State private var sighting: CloudSighting = demoLibrary.randomElement() ?? whaleDemo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TRY IT NOW")
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.accentBlue)
                    .tracking(1.5)
                (Text("Tap a cloud. ") + Text("See what I spot.").italic())
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("I'll read the sky and hand you the weather to match.")
                    .font(.system(size: 14))
                    .foregroundStyle(CV.Color.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            // Sky panel + animated doodle. Tap to replay with a new shape.
            ZStack(alignment: .bottom) {
                SkyBackdrop(palette: .day, cornerRadius: 20)
                HandDrawingView(
                    elements: sighting.drawingElements,
                    shapeName: sighting.shapeName,
                    labelPosition: CGPoint(
                        x: sighting.drawingLabelX,
                        y: sighting.drawingLabelY
                    )
                )
                .id(replayKey)

                quipBadge
                    .padding(.bottom, 14)
            }
            .frame(height: 320)
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Demo: \(sighting.shapeName)")
            .accessibilityHint("Double-tap to draw another shape")
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
                replay()
            }

            weatherStrip
                .padding(.horizontal, 24)
                .padding(.top, 14)

            Text("72° now · light rain by 1pm · tap the sky to replay")
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textTertiary)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Spacer(minLength: 0)

            PrimaryCTA(title: "I'm hooked — finish", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
    }

    /// Pick a different demo from the library (never the same one
    /// twice in a row) and restart the drawing animation.
    private func replay() {
        let currentName = sighting.shapeName
        let candidates = Self.demoLibrary.filter { $0.shapeName != currentName }
        sighting = candidates.randomElement() ?? Self.whaleDemo
        replayKey = UUID()
    }

    private var quipBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(CV.Color.accentBlue).frame(width: 5, height: 5)
            Text("I see \(sighting.shapeName.lowercased())")
                .font(CV.Font.mono)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.55)))
    }

    private var weatherStrip: some View {
        HStack(spacing: 0) {
            cell(title: "NOW",   value: "72°")
            divider
            cell(title: "FEELS", value: "70°")
            divider
            cell(title: "WIND",  value: "6 SW")
            divider
            cell(title: "RAIN",  value: "1pm")
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private func cell(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(CV.Font.mono)
                .foregroundStyle(CV.Color.textTertiary)
                .tracking(1)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CV.Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.5, height: 32)
    }
}
