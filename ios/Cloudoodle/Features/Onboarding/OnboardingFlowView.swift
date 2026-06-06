import SwiftUI

/// Root onboarding container. Renders the appropriate page for the
/// current step, layers the back-button + progress-bar chrome on top
/// where it belongs, and calls `onComplete` once the user hits the
/// final CTA. The chrome is intentionally an overlay rather than
/// padding so the welcome/demo/finished pages can paint edge-to-edge.
struct OnboardingFlowView: View {
    @Bindable var store: OnboardingStore
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            currentPage
                // Soft cross-fade with a barely-visible zoom-in instead
                // of a hard edge-slide. The directional slide felt good
                // for a 3-step wizard but at 8 steps it gets repetitive,
                // and the welcome→howItWorks and demo→finished bookends
                // (which cross palette boundaries) read better as a
                // dissolve than a swipe.
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .center)),
                    removal: .opacity.combined(with: .scale(scale: 1.02, anchor: .center))
                ))
                .id(store.step)
                .animation(transitionSpring, value: store.step)

            if store.step.showsProgressBar {
                VStack {
                    OnboardingChrome(store: store, onSkip: onComplete)
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Per-transition spring tuning. Finished page reveals a sunset
    /// gradient — give it a slightly longer dissolve so the palette
    /// shift feels like a sunrise instead of a jump-cut.
    private var transitionSpring: Animation {
        if store.step == .finished {
            return .spring(response: 0.65, dampingFraction: 0.9)
        }
        return .spring(response: 0.45, dampingFraction: 0.85)
    }

    @ViewBuilder
    private var currentPage: some View {
        switch store.step {
        case .welcome:
            WelcomePage(onContinue: store.advance)
        case .howItWorks:
            HowItWorksPage(onContinue: store.advance)
                .padding(.top, 48)   // clear the chrome
        case .camera:
            CameraPermissionPage(onAdvance: store.advance)
                .padding(.top, 48)
        case .location:
            LocationPermissionPage(onAdvance: store.advance)
                .padding(.top, 48)
        case .notifications:
            NotificationPermissionPage(onAdvance: store.advance)
                .padding(.top, 48)
        case .username:
            UsernamePage(store: store, onContinue: store.advance)
                .padding(.top, 48)
        case .demo:
            DemoPage(onContinue: store.advance)
        case .finished:
            FinishedPage(onEnter: onComplete)
        }
    }
}
