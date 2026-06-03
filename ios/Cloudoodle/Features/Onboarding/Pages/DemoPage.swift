import SwiftUI

/// Page 07 — "First doodle". Shows the user a real-shaped sighting card
/// before they ever lift the camera, so the first scan they do feels
/// familiar instead of cold-launch. Uses the real HandDrawingView so
/// the doodle animation matches what they'll get after a scan.
struct DemoPage: View {
    var onContinue: () -> Void

    /// Synthetic sighting that mimics what Gemini would return for a
    /// whale-shaped cumulus cloud. The drawing element coordinates are
    /// hand-tuned to read as a whale on the procedural sky backdrop.
    private static let demoSighting: CloudSighting = {
        let analysis = CloudAnalysis(
            shapeName: "Whale, drifting",
            quip: "A cumulus whale is taking the slow lane toward the horizon, tail flicking lazy as a daydream.",
            cloudType: "Cumulus",
            weatherMood: "Calm",
            watchabilityScore: 8
        )
        let elements: [CloudAnalysis.DrawingElement] = [
            .init(
                points: [
                    [0.18, 0.52], [0.28, 0.45], [0.40, 0.42], [0.55, 0.42],
                    [0.68, 0.45], [0.78, 0.50]
                ],
                smooth: true, strokeWidth: 2.6, label: "body"
            ),
            .init(
                points: [[0.78, 0.50], [0.88, 0.42], [0.92, 0.50], [0.85, 0.56]],
                smooth: true, strokeWidth: 2.2, label: "tail"
            ),
            .init(
                points: [[0.18, 0.52], [0.14, 0.58], [0.22, 0.60], [0.30, 0.56]],
                smooth: true, strokeWidth: 2.0, label: "head"
            ),
            .init(
                points: [[0.40, 0.50], [0.42, 0.56], [0.50, 0.58], [0.55, 0.54]],
                smooth: true, strokeWidth: 1.8, label: "fin"
            )
        ]
        return CloudSighting(
            analysis: analysis,
            drawingElements: elements,
            drawingLabelX: 0.50,
            drawingLabelY: 0.28
        )
    }()

    @State private var replayKey = UUID()

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

            // Sky panel + animated doodle. Tap to replay.
            ZStack(alignment: .bottom) {
                SkyBackdrop(palette: .day, cornerRadius: 20)
                HandDrawingView(
                    elements: Self.demoSighting.drawingElements,
                    shapeName: Self.demoSighting.shapeName,
                    labelPosition: CGPoint(
                        x: Self.demoSighting.drawingLabelX,
                        y: Self.demoSighting.drawingLabelY
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
            .onTapGesture {
                replayKey = UUID()
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

    private var quipBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(CV.Color.accentBlue).frame(width: 5, height: 5)
            Text("I see a whale, drifting")
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
