import SwiftUI

/// Routes between the camera viewfinder and the daily home view
/// (TodaysPolaroidView). Presented inside ContentView's fullScreen
/// cover whenever the Capture tab is active.
///
/// Mode is an explicit `@State` rather than a derived `todaysEntry`
/// check so the body doesn't swap out from under an in-flight
/// PolaroidDevelopView. Transitions happen on explicit signals:
///   • CaptureFlowView completes a capture → mode = .today
///   • Subscriber taps "Capture another" → mode = .camera
///   • User taps X anywhere → dismiss the whole cover
struct CaptureRootView: View {
    @State private var store = JournalStore.shared
    @State private var subscriptions = SubscriptionService.shared
    @State private var mode: Mode = .resolving
    @State private var showUpgrade = false
    @Environment(\.scenePhase) private var scenePhase

    enum Mode {
        case resolving        // initial state until JournalStore loads
        case camera           // viewfinder + scan + develop
        case today            // today's Polaroid is the home view
    }

    var body: some View {
        Group {
            switch mode {
            case .resolving:
                resolvingView
                    .transition(.opacity)
            case .camera:
                // Only offer a cancel path when there's something to
                // cancel back to (i.e., a subscriber who already has
                // today's Polaroid and tapped "Capture another").
                CaptureFlowView(
                    onCompleted: { mode = .today },
                    onCancel: store.todaysEntry != nil ? { mode = .today } : nil
                )
                .transition(modeTransition)
            case .today:
                if let today = store.todaysEntry {
                    TodaysPolaroidView(
                        entry: today,
                        onCaptureRequested: handleCaptureRequest
                    )
                    .transition(modeTransition)
                } else if subscriptions.hasQuotaToday {
                    // No today's entry, but quota is available — either
                    // a fresh day rolled in while the view was alive,
                    // or the user deleted today's entry. Either way,
                    // back to the camera. (Quota + reminder reschedule
                    // are now handled inside CaptureFlowView on save.)
                    CaptureFlowView(
                        onCompleted: { mode = .today },
                        onCancel: nil
                    )
                    .transition(modeTransition)
                } else {
                    // No quota, no today's entry — usually a free user
                    // who deleted their Polaroid from the gallery.
                    quotaSpentEmptyState
                        .transition(modeTransition)
                }
            }
        }
        // Camera ↔ today's view used to hard-cut. The same soft
        // dissolve-with-settle the onboarding pager uses — the new
        // surface breathes in rather than snapping into place.
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: mode)
        .task {
            await store.loadIfNeeded()
            await subscriptions.refreshEntitlements()
            if mode == .resolving {
                mode = store.todaysEntry != nil ? .today : .camera
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Catch the midnight rollover: if the user has the app
            // open past 00:00 local, the cached `mode` would keep
            // showing yesterday's Polaroid as TODAY forever. Each
            // foreground tick, ask the store fresh and re-route.
            guard newPhase == .active else { return }
            let hasToday = store.todaysEntry != nil
            if mode == .today && !hasToday {
                mode = subscriptions.hasQuotaToday ? .camera : .today
            } else if mode == .camera && hasToday {
                mode = .today
            }
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeSheetView()
        }
    }

    /// Soft dissolve + barely-there scale settle. Matches the
    /// onboarding pager's transition so the whole app changes
    /// surfaces with one consistent motion.
    private var modeTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .center)),
            removal: .opacity.combined(with: .scale(scale: 1.02, anchor: .center))
        )
    }

    // MARK: - States

    private var resolvingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .tint(.white.opacity(0.6))
        }
    }

    /// User has deleted today's entry but still has no quota. Rare
    /// path, but the alternative (blank screen or silent re-open of
    /// camera) is worse.
    private var quotaSpentEmptyState: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.07, blue: 0.09),
                         Color(red: 0.04, green: 0.02, blue: 0.03)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 18) {
                Text("☁︎")
                    .scaledFont(size: 52)
                    .foregroundStyle(.white.opacity(0.55))
                Text("Today's sky is already developed.")
                    .scaledFont(size: 17, weight: .regular, design: .serif)
                    .foregroundStyle(.white.opacity(0.85))
                Text(subscriptions.nextResetMessage)
                    .scaledFont(size: 12, design: .monospaced)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                Button {
                    showUpgrade = true
                } label: {
                    Text("Unlock unlimited Polaroids")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Capsule().fill(CV.Color.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 36)
        }
    }

    // MARK: - Capture request handling

    /// Subscriber taps "Capture another sky" → go straight to camera.
    /// Free user shouldn't reach this path (TodaysPolaroidView routes
    /// them to the upgrade sheet instead) but if they do, we gate.
    private func handleCaptureRequest() {
        if subscriptions.isSubscribed {
            mode = .camera
        } else {
            showUpgrade = true
        }
    }
}
