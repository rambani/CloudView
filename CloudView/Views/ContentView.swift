import SwiftUI
import RealityKit

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    @StateObject private var weatherService = WeatherService()
    @EnvironmentObject var notificationService: NotificationService
    @State private var showInstructions = true
    @State private var hasShownInstructions = false

    var body: some View {
        ZStack {
            // AR Camera View (full screen)
            ARViewContainer(viewModel: arViewModel)
                .edgesIgnoringSafeArea(.all)

            // Overlay UI
            VStack {
                // Top: App title and info - Glassmorphic
                HStack {
                    HStack(spacing: 10) {
                        // Magical sparkle icon
                        Image(systemName: "cloud.sun.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("CloudView")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("AI Cloud Drawings")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    .padding(.leading, 16)
                    .padding(.top, 50)

                    Spacer()

                    // Info button - Glassmorphic
                    Button(action: {
                        withAnimation(.spring()) {
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
                                            LinearGradient(
                                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )

                            Image(systemName: showInstructions ? "xmark.circle.fill" : "info.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                    }
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    .padding(.trailing, 16)
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

            // Contextual status indicators
            VStack {
                Spacer()
                    .frame(height: 120)

                // Show different indicators based on app state
                switch arViewModel.appState {
                case .scanning:
                    if arViewModel.isProcessing {
                        MagicalProcessingIndicator()
                    }

                case .permissionsNeeded:
                    ContextualHintView(
                        icon: "lock.shield.fill",
                        message: "Permissions needed",
                        color: .red
                    )

                case .arNotSupported:
                    ContextualHintView(
                        icon: "xmark.circle.fill",
                        message: "AR not supported",
                        color: .red
                    )

                case .arSessionError:
                    ContextualHintView(
                        icon: "exclamationmark.triangle.fill",
                        message: "AR session error",
                        color: .orange
                    )

                case .pointAtSky:
                    ContextualHintView(
                        icon: "arrow.up.circle.fill",
                        message: "Point camera upward",
                        color: .cyan
                    )

                case .nightTime:
                    ContextualHintView(
                        icon: "moon.stars.fill",
                        message: "Best in daylight",
                        color: .indigo
                    )

                case .movingTooFast:
                    ContextualHintView(
                        icon: "hand.raised.fill",
                        message: "Hold steady",
                        color: .orange
                    )

                default:
                    EmptyView()
                }

                Spacer()
            }

            // Current drawing indicator - Glassmorphic version
            if let drawingName = arViewModel.currentDrawingName {
                VStack {
                    Spacer()
                        .frame(height: 120)

                    HStack(spacing: 12) {
                        // Animated sparkles
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(drawingName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.yellow.opacity(0.4), .orange.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .shadow(color: .yellow.opacity(0.2), radius: 12, x: 0, y: 6)
                    .transition(.opacity.combined(with: .scale))

                    Spacer()
                }
                .onAppear {
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

            // Fetch weather when app appears
            // Use mock data for testing (users can add their own API key)
            weatherService.useMockData()

            // In production, uncomment this:
            // weatherService.requestLocationAndFetchWeather()

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

            // Dismiss button - Enhanced glassmorphic
            Button(action: onDismiss) {
                HStack(spacing: 8) {
                    Text("Got it!")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.cyan, Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )

                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial.opacity(0.3))
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
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

struct MagicalProcessingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 14) {
            // Animated ripple circles
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 28, height: 28)
                        .scaleEffect(isAnimating ? 1.8 : 0.5)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                            value: isAnimating
                        )
                }
            }
            .frame(width: 32, height: 32)

            Text("Detecting clouds...")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.cyan.opacity(0.4), .blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .cyan.opacity(0.2), radius: 12, x: 0, y: 6)
        .onAppear {
            isAnimating = true
        }
    }
}

struct ContextualHintView: View {
    let icon: String
    let message: String
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isPulsing ? 1.1 : 1.0)

            Text(message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [color.opacity(0.4), color.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: color.opacity(0.2), radius: 12, x: 0, y: 6)
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
