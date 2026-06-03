import SwiftUI

/// Page 01 — first impression. Sky backdrop fills the top half, the
/// brand mark sits in serif italic ("Cloud_oodle_"), the doodled creature
/// peeks out of the clouds with its caption pill, and the CTA pushes
/// users into the rest of the flow.
struct WelcomePage: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                SkyBackdrop(palette: .day, cornerRadius: 0)
                    .frame(maxHeight: .infinity)

                // Floating doodle + caption — gives the same "AI saw a
                // whale" preview the welcome mock leads with.
                VStack(spacing: 16) {
                    WhaleDoodle()
                        .frame(width: 220, height: 110)

                    Text("I think I see a whale")
                        .font(CV.Font.mono)
                        .foregroundStyle(CV.Color.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(.ultraThinMaterial))
                }
                .padding(.bottom, 40)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 14) {
                Text("WEATHER, WITH IMAGINATION")
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.textTertiary)
                    .tracking(2)

                (Text("Cloud") + Text("oodle").italic())
                    .font(.system(size: 44, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)

                Text("Today's forecast — plus whatever's drifting overhead.")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(CV.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                PrimaryCTA(title: "Start doodling", systemImage: "arrow.right", action: onContinue)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }
            .padding(.bottom, 36)
            .background(Color.black)
        }
        .ignoresSafeArea(edges: .top)
    }
}

/// Simple stroked-whale silhouette — same hand-drawn aesthetic as the
/// real AI doodles, rendered as a static SwiftUI Path so it ships
/// without any image assets.
private struct WhaleDoodle: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { path in
                // Body — a tilted oblong
                path.move(to: CGPoint(x: w * 0.10, y: h * 0.55))
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.80, y: h * 0.45),
                    control: CGPoint(x: w * 0.45, y: h * 0.10)
                )
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.10, y: h * 0.55),
                    control: CGPoint(x: w * 0.45, y: h * 0.80)
                )
                // Tail flick
                path.move(to: CGPoint(x: w * 0.78, y: h * 0.45))
                path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.30))
                path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.55))
                // Eye dot
                path.move(to: CGPoint(x: w * 0.20, y: h * 0.45))
                path.addArc(
                    center: CGPoint(x: w * 0.20, y: h * 0.45),
                    radius: 1.6,
                    startAngle: .zero,
                    endAngle: .degrees(360),
                    clockwise: false
                )
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .shadow(color: .white.opacity(0.6), radius: 4)
        }
    }
}
