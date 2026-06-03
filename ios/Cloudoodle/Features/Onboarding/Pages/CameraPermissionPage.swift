import SwiftUI
import AVFoundation

/// Page 03 — primes the system camera prompt with editorial framing
/// before iOS shows the harsh dialog. "Not now" still advances —
/// onboarding is allowed to finish without granting, the camera tab
/// will re-prompt the user the first time they try to capture.
struct CameraPermissionPage: View {
    var onAdvance: () -> Void

    var body: some View {
        PermissionPageLayout(
            backdrop: .day,
            backdropOverlay: AnyView(FocusReticle()),
            eyebrow: "Camera",
            headline: "Let me see the sky",
            italicWord: "sky",
            bodyText: "I read clouds straight from your camera. Nothing is saved or uploaded unless you choose to share a sighting.",
            chips: ["Private by default", "No photos stored", "Point & go"],
            primaryTitle: "Allow camera",
            primaryAction: {
                Task {
                    _ = await AVCaptureDevice.requestAccess(for: .video)
                    onAdvance()
                }
            },
            secondaryTitle: "Not now",
            secondaryAction: onAdvance
        )
    }
}

/// White viewfinder corners — telegraphs "this is what the camera page
/// looks like" without needing to mount a live AVCaptureSession in
/// onboarding.
private struct FocusReticle: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let inset: CGFloat = 28
            let tick: CGFloat = 24
            let corners: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                // For each corner: (cx, cy, dx1, dy1, dx2, dy2)
                (inset,         inset,         0,  tick,  tick, 0),     // top-left
                (w - inset,     inset,         0,  tick, -tick, 0),     // top-right
                (inset,         h - inset,     0, -tick,  tick, 0),     // bottom-left
                (w - inset,     h - inset,     0, -tick, -tick, 0),     // bottom-right
            ]
            Path { path in
                for (cx, cy, dx1, dy1, dx2, dy2) in corners {
                    path.move(to: CGPoint(x: cx, y: cy + dy1))
                    path.addLine(to: CGPoint(x: cx, y: cy))
                    path.addLine(to: CGPoint(x: cx + dx2, y: cy))
                    _ = dx1   // silence unused; symmetry kept for readability
                }
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .shadow(color: .black.opacity(0.2), radius: 4)
        }
    }
}
