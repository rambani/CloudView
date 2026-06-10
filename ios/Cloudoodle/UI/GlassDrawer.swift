import SwiftUI

// Frosted glass bottom drawer — peek / half / full snap positions.
// Gesture-aware: when fully open and content is scrolled down, drag is
// handed to the ScrollView rather than collapsing the drawer.
struct GlassDrawer<Content: View>: View {
    @Binding var position: DrawerPosition

    let peekHeight: CGFloat
    let halfFraction: CGFloat
    let content: Content

    enum DrawerPosition: Equatable {
        case peek, half, full
    }

    @GestureState private var dragOffset: CGFloat = 0
    @State private var contentScrollAtTop = true

    init(
        position: Binding<DrawerPosition>,
        peekHeight: CGFloat = 120,
        halfFraction: CGFloat = 0.52,
        @ViewBuilder content: () -> Content
    ) {
        _position = position
        self.peekHeight = peekHeight
        self.halfFraction = halfFraction
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let screenH = geo.size.height
            let fullOffset: CGFloat = 0
            let halfOffset = screenH * (1 - halfFraction)
            let peekOffset = screenH - peekHeight

            let targetOffset: CGFloat = {
                switch position {
                case .peek: return peekOffset
                case .half: return halfOffset
                case .full: return fullOffset
                }
            }()

            let currentOffset = targetOffset + dragOffset
            let clampedOffset = max(fullOffset, min(peekOffset, currentOffset))

            let drawerFraction = 1 - (clampedOffset - fullOffset) / (peekOffset - fullOffset)
            let expandedOpacity = min(1, drawerFraction * 2)

            VStack(spacing: 0) {
                // Handle — always responds to drag. Also the drawer's
                // VoiceOver element: a drag-only control is invisible
                // to screen readers, so the handle exposes explicit
                // expand/collapse actions (and adjustable up/down).
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityElement()
                    .accessibilityLabel("Weather drawer")
                    .accessibilityValue(accessibilityPositionName)
                    .accessibilityHint("Swipe up or down with one finger, or use the actions, to show more or less weather detail")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(named: "Expand") {
                        position = nextUp(from: position)
                    }
                    .accessibilityAction(named: "Collapse") {
                        position = nextDown(from: position)
                    }
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: position = nextUp(from: position)
                        case .decrement: position = nextDown(from: position)
                        @unknown default: break
                        }
                    }

                content
                    .environment(\.drawerFraction, drawerFraction)
                    .environment(\.drawerExpandedOpacity, expandedOpacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .offset(y: clampedOffset)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: position)
            .animation(dragOffset == 0 ? .spring(response: 0.38, dampingFraction: 0.82) : .none, value: dragOffset)
            // Disable drag when at full position and user has scrolled into the content —
            // let the ScrollView take over. Re-enable when scrolled back to top.
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            position = snap(
                                current: targetOffset + value.translation.height,
                                velocity: velocity,
                                peek: peekOffset, half: halfOffset, full: fullOffset
                            )
                        }
                    },
                including: (position == .full && !contentScrollAtTop) ? .none : .all
            )
            .onPreferenceChange(DrawerScrollAtTopKey.self) { atTop in
                contentScrollAtTop = atTop
            }
            // One selection tick whenever the drawer settles into a
            // new position — drag snap, accessibility action, or a
            // programmatic change all read the same to the hand.
            .onChange(of: position) { _, _ in
                Haptics.selection()
            }
        }
    }

    // MARK: - Accessibility helpers

    private var accessibilityPositionName: String {
        switch position {
        case .peek: return "Collapsed"
        case .half: return "Half open"
        case .full: return "Fully open"
        }
    }

    private func nextUp(from p: DrawerPosition) -> DrawerPosition {
        switch p {
        case .peek: return .half
        case .half, .full: return .full
        }
    }

    private func nextDown(from p: DrawerPosition) -> DrawerPosition {
        switch p {
        case .full: return .half
        case .half, .peek: return .peek
        }
    }

    private func snap(
        current: CGFloat, velocity: CGFloat,
        peek: CGFloat, half: CGFloat, full: CGFloat
    ) -> DrawerPosition {
        // Fast flick overrides proximity
        if velocity > 500 { return current < half ? .half : .peek }
        if velocity < -500 { return current > half ? .half : .full }

        let adjusted = current + velocity * 0.18
        return [(abs(adjusted - peek), DrawerPosition.peek),
                (abs(adjusted - half), .half),
                (abs(adjusted - full), .full)]
            .min(by: { $0.0 < $1.0 })!.1
    }
}

// MARK: - Preference key for scroll position reporting

struct DrawerScrollAtTopKey: PreferenceKey {
    static let defaultValue = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value && nextValue()
    }
}

// MARK: - Environment values

private struct DrawerFractionKey: EnvironmentKey {
    static let defaultValue: Double = 0
}
private struct DrawerExpandedOpacityKey: EnvironmentKey {
    static let defaultValue: Double = 0
}

extension EnvironmentValues {
    var drawerFraction: Double {
        get { self[DrawerFractionKey.self] }
        set { self[DrawerFractionKey.self] = newValue }
    }
    var drawerExpandedOpacity: Double {
        get { self[DrawerExpandedOpacityKey.self] }
        set { self[DrawerExpandedOpacityKey.self] = newValue }
    }
}
