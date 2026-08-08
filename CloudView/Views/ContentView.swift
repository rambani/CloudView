import SwiftUI
import RealityKit

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    @StateObject private var weatherService = WeatherService()
    @EnvironmentObject var notificationService: NotificationService
    @State private var showInstructions = false
    // Persisted so the overlay genuinely shows once per install, not once
    // per launch (the old @State reset every cold start).
    @AppStorage("hasSeenInstructions") private var hasSeenInstructions = false
    @State private var showSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // AR Camera View (full screen)
            ARViewContainer(viewModel: arViewModel)
                .edgesIgnoringSafeArea(.all)

            // Overlay UI
            VStack {
                // Top: App title and info - Enhanced glassmorphic
                HStack {
                    HStack(spacing: .spacing_sm + 2) {
                        // Magical sparkle icon with floating animation
                        Image(systemName: "cloud.sun.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(LinearGradient.cloudoodleSky)
                            .floating(duration: 2.5, distance: 3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cloudoodle")
                                .font(.cloudoodleTitle)
                                .foregroundColor(.white)

                            Text("AI Cloud Drawings")
                                .font(.cloudoodleMini)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, .spacing_md)
                    .padding(.vertical, .spacing_md - 4)
                    .background(
                        RoundedRectangle(cornerRadius: .radius_lg)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: .radius_lg)
                                    .strokeBorder(
                                        LinearGradient.glassShine,
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: Color.glassShadow, radius: 12, x: 0, y: 6)
                    .padding(.leading, .spacing_md)
                    .padding(.top, 50)

                    Spacer()

                    // Info button - Enhanced with bouncy animation
                    Button(action: {
                        withAnimation(reduceMotion ? .linear(duration: 0.15) : .bouncy) {
                            showInstructions.toggle()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient.glassShine,
                                            lineWidth: 1
                                        )
                                )

                            Image(systemName: showInstructions ? "xmark.circle.fill" : "info.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .shadow(color: Color.glassShadow, radius: 12, x: 0, y: 6)
                    .accessibilityLabel(showInstructions ? "Close instructions" : "Show instructions")
                    .padding(.top, 50)

                    // Settings — a small, visible gear (was hidden behind a
                    // long-press, which nobody finds).
                    Button(action: { showSettings = true }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient.glassShine,
                                            lineWidth: 1
                                        )
                                )

                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .shadow(color: Color.glassShadow, radius: 12, x: 0, y: 6)
                    .padding(.leading, .spacing_sm)
                    .padding(.trailing, .spacing_md)
                    .accessibilityLabel("Settings")
                    .padding(.top, 50)
                }

                Spacer()

                // Instructions overlay (appears on first launch)
                if showInstructions {
                    InstructionsView(onDismiss: {
                        withAnimation(.spring()) {
                            showInstructions = false
                            hasSeenInstructions = true
                        }
                    })
                    .transition(.opacity.combined(with: .scale))
                }

                Spacer()

                // Bottom: Swipeable Weather Panel
                SwipeableWeatherPanel(weatherService: weatherService, arViewModel: arViewModel)
                    .padding(.bottom, 40)
            }

            // Contextual status indicators - Enhanced with magical hints
            VStack {
                Spacer()
                    .frame(height: 120)

                // Show different indicators based on app state
                switch arViewModel.appState {
                case .scanning:
                    if arViewModel.isProcessing {
                        EnhancedMagicalLoadingView()
                    }

                case .permissionsNeeded:
                    CameraPermissionView()

                case .arNotSupported:
                    MagicalHintView(
                        icon: "xmark.circle.fill",
                        message: "AR not supported",
                        color: .red
                    )

                case .arSessionError:
                    MagicalHintView(
                        icon: "exclamationmark.triangle.fill",
                        message: "AR session error",
                        color: .orange
                    )

                case .pointAtSky:
                    MagicalHintView(
                        icon: "arrow.up.circle.fill",
                        message: "Point camera upward",
                        color: Color.cloudBlue
                    )

                case .nightTime:
                    MagicalHintView(
                        icon: "moon.stars.fill",
                        message: "Best in daylight",
                        color: Color.lavenderDream
                    )

                case .movingTooFast:
                    MagicalHintView(
                        icon: "hand.raised.fill",
                        message: "Hold steady",
                        color: .orange
                    )

                default:
                    EmptyView()
                }

                Spacer()
            }

            // Current drawing indicator - Enhanced with magical glow
            if let drawingName = arViewModel.currentDrawingName {
                VStack {
                    Spacer()
                        .frame(height: 120)

                    HStack(spacing: .spacing_md) {
                        // Animated sparkles with floating effect
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(LinearGradient.magicalGlow)
                            .floating(duration: 1.5, distance: 4)

                        Text(drawingName)
                            .font(.cloudoodleBody)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        // Instant share — the only way to keep a drawing.
                        // Nothing is archived; share it now or let the
                        // moment drift on.
                        if let shareable = arViewModel.latestShareable,
                           shareable.label == drawingName {
                            ShareLink(
                                item: Image(uiImage: shareable.image),
                                subject: Text(shareable.caption),
                                message: Text(shareable.caption),
                                preview: SharePreview(
                                    shareable.caption,
                                    image: Image(uiImage: shareable.image)
                                )
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .accessibilityLabel("Share this drawing")
                        }
                    }
                    .padding(.horizontal, .spacing_lg)
                    .padding(.vertical, .spacing_sm + 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.sunGlow.opacity(0.5), Color.cloudPink.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .shadow(color: Color.sunGlow.opacity(0.3), radius: 12, x: 0, y: 6)
                    .transition(.opacity.combined(with: .scale))
                    // VoiceOver users can't see the AR drawing appear; this
                    // node aggregates the visual + text into one
                    // announcement so a swipe-right after launch lands here
                    // and reads "Cloudoodle drew a Happy Penguin Surfing".
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Cloudoodle drew \(drawingName)")
                    .accessibilityAddTraits(.updatesFrequently)

                    Spacer()
                }
                // task(id:) instead of onAppear: it restarts per DRAWING,
                // not per view appearance — so a second drawing landing
                // within the window gets its own announcement and its own
                // full dismiss timer (onAppear-based timers dismissed the
                // new capsule early and cleared its share button).
                .task(id: drawingName) {
                    // VoiceOver announcement per drawing — the AR scene
                    // itself is unreachable through accessibility.
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Cloudoodle drew \(drawingName)"
                    )

                    // Long enough to notice and tap the share button; more
                    // generous when VoiceOver users need to navigate to it.
                    let seconds: UInt64 = UIAccessibility.isVoiceOverRunning ? 16 : 8
                    try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                    // A new drawing cancels this task — don't let the old
                    // timer fall through and clear the new capsule.
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        arViewModel.currentDrawingName = nil
                        arViewModel.latestShareable = nil
                    }
                }
            }

            // One-time community invite, earned after a few drawings —
            // the only discovery moment for geo notifications besides
            // digging through Settings.
            if arViewModel.showCommunityInvite {
                VStack {
                    Spacer()
                    CommunityInviteCard(
                        onAccept: {
                            ScanReportingService.shared.isEnabled = true
                            notificationService.requestNotificationPermission()
                            notificationService.registerWithBackendIfConsented()
                            withAnimation(.spring()) {
                                arViewModel.showCommunityInvite = false
                            }
                        },
                        onDecline: {
                            withAnimation(.spring()) {
                                arViewModel.showCommunityInvite = false
                            }
                        }
                    )
                    Spacer()
                        .frame(height: 160)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: scenePhase) { phase in
            // Re-check camera permission whenever the app becomes active
            // (e.g. returning from Settings after granting access).
            if phase == .active {
                arViewModel.checkPermissions()
            }
        }
        .onAppear {
            // Wire up services for privacy-preserving notifications
            arViewModel.weatherService = weatherService
            arViewModel.checkPermissions()

            // Note: notification permission is intentionally NOT requested
            // here. The system prompt fires only when the user opts in to
            // community notifications from Settings — never on first launch.

            // Fetch live weather (WeatherKit) for the user's current
            // location. WeatherService shows sample data in DEBUG and a
            // graceful placeholder in Release when unavailable.
            weatherService.requestLocationAndFetchWeather()

            // Show instructions once per install.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !hasSeenInstructions {
                    withAnimation(.spring()) {
                        showInstructions = true
                    }
                }
            }
        }
        .statusBar(hidden: false)
        .preferredColorScheme(.dark)
        // Allow Dynamic Type scaling but cap at .accessibility1 — the
        // AR overlay has fixed-position glass panels that overflow at
        // accessibility XXL. .xLarge..accessibility1 covers most users
        // with vision accommodations without breaking the layout.
        .dynamicTypeSize(.xSmall ... .accessibility1)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(notificationService)
        }
    }
}

/// Shown when camera access is denied or restricted — the one state the
/// app cannot function in at all. Friendly, actionable, no dead end.
struct CameraPermissionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(LinearGradient.cloudoodleSky)

            Text("Cloudoodle needs the camera to see the sky")
                .font(.cloudoodleBody)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Allow camera access in Settings and the cloud drawings can begin.")
                .font(.cloudoodleMini)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.cloudoodleBody)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, .spacing_lg)
                    .padding(.vertical, .spacing_sm + 4)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color.cloudBlue, Color.lavenderDream],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
            }
            .buttonStyle(BouncyButtonStyle())
        }
        .padding(.spacing_lg)
        .background(
            RoundedRectangle(cornerRadius: .radius_lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: .radius_lg)
                        .strokeBorder(LinearGradient.glassShine, lineWidth: 1)
                )
        )
        .shadow(color: Color.glassShadow, radius: 12, x: 0, y: 6)
        .padding(.horizontal, 40)
    }
}

/// One-time invite to the community notifications, shown after a few
/// drawings. Copy is kid-friendly and privacy-honest: anonymous,
/// city-level, opt-in.
struct CommunityInviteCard: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(LinearGradient.magicalGlow)
                Text("The sky has more secrets")
                    .font(.cloudoodleBody)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text("Get a friendly ping when dragons and other doodles start gathering near your city. Anonymous and city-level only — never your exact location.")
                .font(.cloudoodleMini)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: onDecline) {
                    Text("Not now")
                        .font(.cloudoodleMini)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, .spacing_md)
                        .padding(.vertical, .spacing_sm + 2)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
                .buttonStyle(BouncyButtonStyle())

                Button(action: onAccept) {
                    Text("Notify me")
                        .font(.cloudoodleMini)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, .spacing_lg)
                        .padding(.vertical, .spacing_sm + 2)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color.cloudBlue, Color.lavenderDream],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(.spacing_lg)
        .background(
            RoundedRectangle(cornerRadius: .radius_lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: .radius_lg)
                        .strokeBorder(LinearGradient.glassShine, lineWidth: 1)
                )
        )
        .shadow(color: Color.glassShadow, radius: 14, x: 0, y: 8)
        .padding(.horizontal, 32)
    }
}

struct InstructionsView: View {
    let onDismiss: () -> Void
    @State private var sparkleRotation = 0.0

    var body: some View {
        VStack(spacing: 24) {
            // Title - Enhanced with animation
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(sparkleRotation))
                    .animation(
                        Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: sparkleRotation
                    )

                Text("How to Use")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .onAppear {
                sparkleRotation = 10
            }

            VStack(alignment: .leading, spacing: 20) {
                InstructionRow(
                    icon: "sun.max.fill",
                    iconColor: .orange,
                    title: "Best in Daylight",
                    description: "Cloud drawings work best during daytime hours"
                )

                InstructionRow(
                    icon: "camera.fill",
                    iconColor: .blue,
                    title: "Point at the Sky",
                    description: "Aim your camera upward at clouds in the sky"
                )

                InstructionRow(
                    icon: "hand.raised.fill",
                    iconColor: .green,
                    title: "Hold Still",
                    description: "Keep your phone steady for a few seconds"
                )

                InstructionRow(
                    icon: "paintbrush.fill",
                    iconColor: .purple,
                    title: "Watch the Magic",
                    description: "AI creates whimsical drawings from cloud shapes"
                )

                InstructionRow(
                    icon: "sparkles",
                    iconColor: .cyan,
                    title: "Explore",
                    description: "Pan around to discover more clouds and drawings"
                )
            }
            .padding(.horizontal, 24)

            // Dismiss button - Enhanced with magical gradient and bouncy animation
            Button(action: onDismiss) {
                HStack(spacing: .spacing_sm) {
                    Text("Got it!")
                        .font(.cloudoodleBody)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.cloudoodleBody)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacing_md)
                .background(
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.cloudBlue, Color.lavenderDream]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )

                        RoundedRectangle(cornerRadius: .radius_md)
                            .fill(.ultraThinMaterial.opacity(0.3))
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: .radius_md))
                .overlay(
                    RoundedRectangle(cornerRadius: .radius_md)
                        .strokeBorder(
                            LinearGradient.glassShine,
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.cloudBlue.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(BouncyButtonStyle())
            .padding(.horizontal, .spacing_lg)
            .padding(.top, .spacing_sm)
        }
        .padding(.vertical, 32)
        .background(
            BlurView(style: .systemThickMaterialDark)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 32)
    }
}

struct InstructionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon - Enhanced glassmorphic
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.3), iconColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .strokeBorder(iconColor.opacity(0.4), lineWidth: 1.5)
                    )

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: iconColor.opacity(0.2), radius: 8, x: 0, y: 4)

            // Text — uses semantic styles so Dynamic Type scaling works.
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NotificationService())
    }
}
