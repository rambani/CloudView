import SwiftUI
import RealityKit

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    @StateObject private var weatherService = WeatherService()
    @EnvironmentObject var notificationService: NotificationService
    @State private var showInstructions = true
    @State private var hasShownInstructions = false
    @State private var showSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .padding(.trailing, .spacing_md)
                    .accessibilityLabel(showInstructions ? "Close instructions" : "Show instructions")
                    .accessibilityHint("Tap to toggle instructions. Long press for settings.")
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.6)
                            .onEnded { _ in showSettings = true }
                    )
                    .accessibilityAction(named: "Settings") {
                        showSettings = true
                    }
                    .padding(.top, 50)
                }

                Spacer()

                // Instructions overlay (appears on first launch)
                if showInstructions {
                    InstructionsView(onDismiss: {
                        withAnimation(.spring()) {
                            showInstructions = false
                            hasShownInstructions = true
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
                    MagicalHintView(
                        icon: "lock.shield.fill",
                        message: "Permissions needed",
                        color: .red
                    )

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
                .onAppear {
                    // Push a focused VoiceOver announcement so blind users
                    // know something happened — the AR scene itself is
                    // unreachable through accessibility.
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Cloudoodle drew \(drawingName)"
                    )

                    // Auto-dismiss after 4 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            arViewModel.currentDrawingName = nil
                        }
                    }
                }
            }
        }
        .onAppear {
            // Wire up services for privacy-preserving notifications
            arViewModel.weatherService = weatherService

            // Request notification permission for community features
            notificationService.requestNotificationPermission()

            // Fetch real weather for the user's current location. WeatherService
            // falls back to mock data on its own if OPEN_WEATHER_API_KEY isn't
            // configured or the user denies location, so this path is always
            // safe — no need to opt in to mock data from here.
            weatherService.requestLocationAndFetchWeather()

            // Show instructions on first launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !hasShownInstructions {
                    withAnimation(.spring()) {
                        showInstructions = true
                    }
                }
            }
        }
        .statusBar(hidden: false)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(notificationService)
        }
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

            // Text
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
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
