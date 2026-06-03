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
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(store.step)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: store.step)

            if store.step.showsProgressBar {
                VStack {
                    OnboardingChrome(store: store)
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
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
