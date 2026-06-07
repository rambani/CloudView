import SwiftUI

/// Wraps content in a pinch-to-zoom + pan-to-explore container.
///
/// Designed to be drop-in safe: when the user hasn't started zooming
/// (scale ~ 1.0), no drag gestures are attached so ancestor gestures
/// like the gallery's TabView paging and TodaysPolaroidView's swipe-
/// to-gallery continue to work. Once zoomed, a one-finger drag is
/// captured for panning.
///
/// Gestures:
///   • Pinch (2-finger)  → zoom between 1.0 and `maxScale`
///   • Double-tap        → toggle between 1.0 and `doubleTapScale`
///   • Drag (1-finger)   → pan, but only when zoomed
///   • Release < 1.05    → snap back to 1.0 (and reset offset)
struct ZoomableView<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var maxScale: CGFloat = 4.0
    var doubleTapScale: CGFloat = 2.0

    @State private var committedScale: CGFloat = 1.0
    @State private var committedOffset: CGSize = .zero
    @GestureState private var gesturePinch: CGFloat = 1.0
    @GestureState private var gestureDrag: CGSize = .zero

    private var liveScale: CGFloat { committedScale * gesturePinch }
    private var liveOffset: CGSize {
        CGSize(
            width: committedOffset.width + gestureDrag.width,
            height: committedOffset.height + gestureDrag.height
        )
    }
    /// We use a small dead-band above 1.0 so the "is the user zoomed"
    /// check doesn't flicker on tiny gesture residuals.
    private var isZoomed: Bool { committedScale > 1.01 }

    var body: some View {
        let core = content()
            .scaleEffect(liveScale, anchor: .center)
            .offset(liveOffset)
            .gesture(pinchGesture)
            .onTapGesture(count: 2) { toggleZoom() }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: committedScale)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: committedOffset)

        // Only attach the pan gesture when we're zoomed, so when at
        // rest scale ancestor drag gestures (swipe-to-gallery,
        // TabView paging) still fire normally.
        if isZoomed {
            core.simultaneousGesture(panGesture)
        } else {
            core
        }
    }

    // MARK: - Gestures

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .updating($gesturePinch) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let new = max(1.0, min(maxScale, committedScale * value))
                if new < 1.05 {
                    committedScale = 1.0
                    committedOffset = .zero
                } else {
                    committedScale = new
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($gestureDrag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                committedOffset.width += value.translation.width
                committedOffset.height += value.translation.height
            }
    }

    private func toggleZoom() {
        if isZoomed {
            committedScale = 1.0
            committedOffset = .zero
        } else {
            committedScale = doubleTapScale
        }
    }
}
