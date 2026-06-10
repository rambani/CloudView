import SwiftUI

/// One-time onboarding overlay shown the very first time the user
/// reaches the camera viewfinder. A floating caption + animated arrow
/// points at the shutter so the moment-of-truth doesn't read as a
/// blank screen with mystery buttons.
///
/// Carefully non-blocking: the overlay only consumes touches on the
/// caption card itself. The shutter underneath still works directly,
/// so a user who already knows what to do can just press it (which
/// also dismisses the guide via `seenFirstGuide = true`).
///
/// Single-use: the @AppStorage flag is flipped on first dismissal,
/// after which this view never renders again on the device.
struct FirstCaptureGuide: View {
    let onDismiss: () -> Void

    @State private var arrowOffset: CGFloat = 0

    var body: some View {
        VStack {
            // Top half: not hit-testable. Lets the gear icon and
            // location chip in the viewfinder remain tappable.
            Spacer()

            VStack(spacing: 8) {
                Text("Tap to capture the sky")
                    .scaledFont(size: 16, weight: .regular, design: .serif)
                    .italic()
                    .foregroundStyle(.white)
                Image(systemName: "arrow.down")
                    .scaledFont(size: 22, weight: .semibold)
                    .foregroundStyle(.white.opacity(0.95))
                    .offset(y: arrowOffset)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            .onTapGesture { onDismiss() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Got it")
            .accessibilityHint("Dismisses the first-capture hint")

            // Spacer to position the card above the shutter. Sized so
            // the arrow lands just above the shutter button's top
            // edge regardless of safe-area variations.
            Color.clear
                .frame(height: 248)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                arrowOffset = 6
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
