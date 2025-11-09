import SwiftUI
import RealityKit

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    @StateObject private var weatherService = WeatherService()
    @State private var showInstructions = true
    @State private var hasShownInstructions = false

    var body: some View {
        ZStack {
            // AR Camera View (full screen)
            ARViewContainer(viewModel: arViewModel)
                .edgesIgnoringSafeArea(.all)

            // Overlay UI
            VStack {
                // Top: App title and info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CloudView")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                        Text("AI Cloud Drawings")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 50)

                    Spacer()

                    // Info button
                    Button(action: {
                        withAnimation(.spring()) {
                            showInstructions.toggle()
                        }
                    }) {
                        Image(systemName: showInstructions ? "xmark.circle.fill" : "info.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 20)
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

                // Bottom: Weather info
                WeatherView(weatherService: weatherService)
                    .padding(.bottom, 40)
            }

            // Processing indicator
            if arViewModel.isProcessing {
                VStack {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text("Detecting clouds...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        BlurView(style: .systemUltraThinMaterialDark)
                            .clipShape(Capsule())
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                    Spacer()
                }
                .padding(.top, 120)
            }

            // Current drawing indicator
            if let drawingName = arViewModel.currentDrawingName {
                VStack {
                    Spacer()
                        .frame(height: 120)

                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)

                        Text(drawingName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        BlurView(style: .systemUltraThinMaterialDark)
                            .clipShape(Capsule())
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
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

    var body: some View {
        VStack(spacing: 24) {
            // Title
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow)

                Text("How to Use")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 20) {
                InstructionRow(
                    icon: "camera.fill",
                    iconColor: .blue,
                    title: "Point at the Sky",
                    description: "Aim your camera at clouds in the sky"
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
                    description: "AI will create a fun drawing from the cloud shape"
                )

                InstructionRow(
                    icon: "sparkles",
                    iconColor: .orange,
                    title: "Explore",
                    description: "Pan around to discover more clouds and drawings"
                )
            }
            .padding(.horizontal, 24)

            // Dismiss button
            Button(action: onDismiss) {
                Text("Got it!")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
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
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
