import SwiftUI
import AVFoundation

/// One-shot capture-to-Polaroid flow. Single beat now:
///   viewfinder → shutter → developing Polaroid → save → done.
///
/// The old hand-drawn reveal path (HandDrawingView, ScanLayer beam,
/// AI-drawn doodle) has been retired — every scan now goes straight
/// into the server-side develop call and produces a Polaroid. Gemini
/// still runs in the background to populate the shape name + cloud
/// type + weather mood metadata that the Polaroid + journal use.
///
/// Quota gating happens one level up in CaptureRootView; if we're
/// presented here, the user is allowed to scan.
struct CaptureFlowView: View {
    @EnvironmentObject private var location: LocationService

    /// Fires once after the develop completes AND its JournalEntry is
    /// persisted AND the user has tapped through the develop view.
    /// CaptureRootView uses this to swap to TodaysPolaroidView.
    var onCompleted: () -> Void = {}
    /// Optional cancel handler. Only set when the user is a subscriber
    /// who reached the camera via "Capture another sky" — they need a
    /// way back to today's view if they decide not to capture. When
    /// nil, the viewfinder doesn't show a cancel button (first-of-day
    /// capture has nowhere to cancel to).
    var onCancel: (() -> Void)? = nil

    @StateObject private var camera = CameraService()
    @State private var subscriptions = SubscriptionService.shared
    @State private var phase: CapturePhase = .viewfinder
    @State private var capturedWeather: WeatherSnapshot?
    // scanError used to surface Gemini-call failures during the
    // pre-develop beat. With the server-side proxy, every failure
    // comes from the develop step and shows up in polaroidError.
    @State private var viewfinderWeather: WeatherSnapshot?
    @State private var showSettings = false
    @State private var viewfinderDrawerPosition: GlassDrawer<WeatherDrawerContent<EmptyView>>.DrawerPosition = .peek

    /// First-launch capture hint. Stays true until the user's first
    /// interaction with the viewfinder (a tap on the hint card or a
    /// shutter press), then never appears again.
    @AppStorage("seen_first_capture_guide") private var seenFirstCaptureGuide = false

    // Polaroid develop state
    @State private var showPolaroid = false
    @State private var polaroidOriginal: UIImage?
    @State private var polaroidDeveloped: UIImage?
    @State private var polaroidProgress: Double = 0
    @State private var polaroidError: String?
    @State private var polaroidJournalEntryId: UUID?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            phaseContent
        }
        .ignoresSafeArea()
        .task {
            try? await camera.requestPermissionAndSetup()
            await loadViewfinderWeather()
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showPolaroid, onDismiss: {
            // User tapped through the developed Polaroid.
            // Only signal completion if the develop actually
            // succeeded (entry id present) — if an error happened
            // mid-flight we just want them back at the viewfinder.
            if polaroidJournalEntryId != nil {
                onCompleted()
            }
        }) {
            if let original = polaroidOriginal {
                PolaroidDevelopView(
                    original: original,
                    developed: polaroidDeveloped,
                    progress: polaroidProgress,
                    onTap: { showPolaroid = false },
                    journalEntryId: polaroidJournalEntryId
                )
                .onAppear { driveDevelopAnimation() }
            }
        }
        .alert("Couldn't develop", isPresented: Binding(
            get: { polaroidError != nil },
            set: { if !$0 { polaroidError = nil } }
        )) {
            // Most develop failures the user can act on involve the
            // backend configuration — surface Settings right from the
            // alert so they don't have to hunt for the gear icon.
            Button("Open Settings") { showSettings = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text(polaroidError ?? "")
        }
    }

    // MARK: - Develop flow

    /// Kicks off the AI develop via the server-side `develop-polaroid`
    /// edge function. One round trip returns both the shape metadata
    /// and the developed PNG with ink overlay (all Gemini). The
    /// previous client-side direct calls to those APIs — and the
    /// associated user-supplied API keys — are gone.
    private func startDevelop(originalImage: UIImage, crop: SmartCrop.Result) {
        polaroidOriginal = originalImage
        polaroidDeveloped = nil
        polaroidProgress = 0
        polaroidJournalEntryId = nil
        showPolaroid = true

        Task {
            do {
                let result = try await SupabaseService.shared.developPolaroid(
                    crop: crop.cropped,
                    city: location.currentCity,
                    recentShapes: await JournalStore.shared.recentShapeNames()
                )

                guard let developedData = Data(base64Encoded: result.developedImageBase64),
                      let developedImage = UIImage(data: developedData) else {
                    throw SupabaseError.uploadFailed(URLError(.cannotParseResponse))
                }

                // Composite developed crop back into the original
                // frame so the surrounding photo stays intact — the
                // viewer sees the full sky with ink in the right spot.
                let composited = await Self.composite(
                    base: originalImage,
                    overlay: developedImage,
                    in: crop.normalizedRect
                )

                let quip = await QuipGenerationService.shared.generateQuip(
                    shapeName: result.shapeName,
                    cloudType: result.cloudType
                )

                let entry = JournalEntry(
                    originalImageData: originalImage.jpegData(compressionQuality: 0.85) ?? Data(),
                    developedImageData: composited.jpegData(compressionQuality: 0.88),
                    shapeName: result.shapeName,
                    quip: quip,
                    cloudType: result.cloudType,
                    weatherMood: result.weatherMood,
                    city: location.currentCity,
                    country: location.currentCountry,
                    temperatureF: capturedWeather?.temperature,
                    cloudCoverPct: capturedWeather?.cloudCoverPct
                )
                let saved = await JournalStore.shared.add(entry)

                await MainActor.run {
                    subscriptions.recordScan()
                    polaroidDeveloped = composited
                    polaroidProgress = 1.0
                    polaroidJournalEntryId = saved.id
                }
                await DailyReminderService.shared.notifyDidScan()
                // The edge function inserts sighting_metadata + updates
                // profiles.city on the server side, so no separate
                // recordSightingMetadata call is needed here.
                Telemetry.scanSuccess(shapeName: result.shapeName)
            } catch {
                Telemetry.scanFailure(error: error)
                await MainActor.run {
                    polaroidError = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    showPolaroid = false
                    phase = .viewfinder
                    Task { try? await camera.requestPermissionAndSetup() }
                }
            }
        }
    }

    /// While the API call is pending, march `polaroidProgress` up
    /// toward 0.92 on a sigmoid curve so the photo "develops" in
    /// step with user expectation. When the API actually returns,
    /// startDevelop flips it to 1.0 with a hard cut.
    private func driveDevelopAnimation() {
        Task {
            let totalSteps = 90
            let stepDelay: Duration = .milliseconds(180)
            for step in 0..<totalSteps {
                if polaroidDeveloped != nil { break }
                let x = Double(step) / Double(totalSteps)
                let curve = 0.92 / (1 + exp(-6 * (x - 0.45)))
                await MainActor.run { polaroidProgress = curve }
                try? await Task.sleep(for: stepDelay)
            }
        }
    }

    private static func composite(
        base: UIImage,
        overlay: UIImage,
        in normalizedRect: CGRect
    ) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            let size = base.size
            let format = UIGraphicsImageRendererFormat()
            format.scale = base.scale
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            return renderer.image { _ in
                base.draw(in: CGRect(origin: .zero, size: size))
                let destRect = CGRect(
                    x: normalizedRect.minX * size.width,
                    y: normalizedRect.minY * size.height,
                    width: normalizedRect.width * size.width,
                    height: normalizedRect.height * size.height
                )
                overlay.draw(in: destRect)
            }
        }.value
    }

    // MARK: - Phase routing

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .viewfinder:
            if camera.authorizationStatus == .denied
                || camera.authorizationStatus == .restricted {
                // Don't leave the user staring at a black viewfinder
                // when iOS has blocked camera access — explain
                // what's needed and offer a one-tap jump to Settings.
                CameraPermissionDeniedView(
                    onOpenSettings: { openSystemSettings() },
                    onSettings: { showSettings = true },
                    onCancel: onCancel
                )
            } else {
                ZStack {
                    ViewfinderLayer(
                        camera: camera,
                        onSettings: { showSettings = true },
                        onCancel: onCancel,
                        onCapture: { Task { await capture() } }
                    )
                    GlassDrawer(
                        position: $viewfinderDrawerPosition,
                        peekHeight: 160,
                        halfFraction: 0.55
                    ) {
                        WeatherDrawerContent(weather: viewfinderWeather) {
                            EmptyView()
                        }
                    }
                    if !seenFirstCaptureGuide {
                        FirstCaptureGuide(onDismiss: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                seenFirstCaptureGuide = true
                            }
                        })
                    }
                }
            }

        case .captured(let image):
            photoBackground(image)
                .overlay(scanningOverlay(progress: 0))

        case .scanning(let image, let progress):
            ZStack {
                photoBackground(image)
                scanningOverlay(progress: progress)
            }
        }
    }

    /// Deep-links into iOS Settings → Cloudoodle. The only reliable
    /// way to recover camera-permission-denied without uninstalling.
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Pulls weather for the viewfinder drawer. Separate from
    /// `capturedWeather` (which is the snapshot frozen at capture
    /// time and persisted on the JournalEntry) — this one is just
    /// for the "should I scan now?" decision support.
    private func loadViewfinderWeather() async {
        guard viewfinderWeather == nil else { return }
        viewfinderWeather = await WeatherService.shared.fetch(for: location.currentLocation)
    }

    @ViewBuilder
    private func photoBackground(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }

    /// Replaces the old ScanLayer beam. We just want a brief "thinking"
    /// indicator while Gemini + Vision run, then the camera flow hands
    /// off to PolaroidDevelopView which carries its own developing
    /// animation. Two layers of dramatic scan beam felt redundant.
    private func scanningOverlay(progress: Double) -> some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white.opacity(0.8))
                    .scaleEffect(1.1)
                Text(scanningCaption(progress))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .ignoresSafeArea()
    }

    private func scanningCaption(_ p: Double) -> String {
        switch p {
        case ..<0.4:  return "READING THE SKY"
        case ..<0.8:  return "FINDING A SHAPE"
        default:      return "PREPARING THE FILM"
        }
    }

    // MARK: - Capture flow

    private func capture() async {
        // Tapping the shutter also dismisses the first-capture hint
        // — the user clearly knows what to do; no reason to keep the
        // tooltip floating during their first shot.
        if !seenFirstCaptureGuide {
            seenFirstCaptureGuide = true
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        do {
            let image = try await camera.capturePhoto()
            camera.stop()
            withAnimation(.easeIn(duration: 0.06)) { phase = .captured(image) }
            try? await Task.sleep(for: .milliseconds(100))
            await scan(image: image)
        } catch {
            // Capture failed — phase is still .viewfinder, so the
            // user is already back at the camera and can just try
            // again. (The old behavior was to dismiss the cover,
            // but we don't have one anymore.)
        }
    }

    private func scan(image: UIImage) async {
        Telemetry.scanAttempt()
        let captureLocation = location.currentLocation

        async let weatherTask = WeatherService.shared.fetch(for: captureLocation)

        // Smart-crop client-side: Vision is free + on-device, and the
        // tighter crop halves the upload size to the AI proxy.
        let candidates = await CloudVisionService.shared.findCandidateRegions(in: image, topK: 1)
        let crop = SmartCrop.crop(photo: image, around: candidates.first)

        // Brief "reading the sky" beat for visual continuity with the
        // shutter tap. The actual AI work happens in startDevelop;
        // this overlap just absorbs the moment of "did anything
        // happen?" while the develop call gets going.
        let scanDuration: Double = 1.0
        let start = Date()
        withAnimation(.easeOut(duration: 0.12)) { phase = .scanning(image, 0) }
        repeat {
            let elapsed = Date().timeIntervalSince(start)
            let p = min(elapsed / scanDuration, 1.0)
            if case .scanning = phase { phase = .scanning(image, p) }
            try? await Task.sleep(for: .milliseconds(16))
        } while Date().timeIntervalSince(start) < scanDuration

        capturedWeather = await weatherTask
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        startDevelop(originalImage: image, crop: crop)
    }

}

// MARK: - Phase enum

private enum CapturePhase {
    case viewfinder
    case captured(UIImage)
    case scanning(UIImage, Double)
}

// MARK: - Viewfinder layer

private struct ViewfinderLayer: View {
    let camera: CameraService
    let onSettings: () -> Void
    /// nil when the user has no fallback — first-of-day capture.
    /// Set only when they came from "Capture another" on today's view.
    let onCancel: (() -> Void)?
    let onCapture: () -> Void
    @EnvironmentObject private var location: LocationService

    var body: some View {
        ZStack {
            CameraPreviewLayer(session: camera.session)
                .ignoresSafeArea()

            // Bottom fade so shutter sits on something — and the
            // peek of the weather drawer reads as a separate layer.
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.5)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 240)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                HStack {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.black.opacity(0.35)))
                    }
                    .accessibilityLabel("Settings")
                    Spacer()
                    if let city = location.currentCity {
                        LocationChip(city: city)
                    }
                    if let onCancel {
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(.black.opacity(0.35)))
                        }
                        .accessibilityLabel("Back to today's Polaroid")
                        .padding(.leading, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                Text("Point at the sky")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 18)

                ShutterButton(action: onCapture)
                    .padding(.bottom, 180)   // clear of the drawer peek
            }
        }
    }
}

// MARK: - Permission-denied overlay

/// Shown in place of the viewfinder when iOS has blocked camera
/// access (denied or restricted). The user can't recover from
/// inside the app — they have to flip the toggle in iOS Settings
/// — so the only useful CTA is a deep-link there.
private struct CameraPermissionDeniedView: View {
    let onOpenSettings: () -> Void
    let onSettings: () -> Void
    let onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.10, blue: 0.16),
                         Color(red: 0.02, green: 0.03, blue: 0.06)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.black.opacity(0.35)))
                    }
                    .accessibilityLabel("Settings")
                    Spacer()
                    if let onCancel {
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(.black.opacity(0.35)))
                        }
                        .accessibilityLabel("Back to today's Polaroid")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                Spacer()
            }

            VStack(spacing: 20) {
                Image(systemName: "camera.slash")
                    .font(.system(size: 42))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.85))

                VStack(spacing: 10) {
                    Text("Camera access needed")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                    Text("Cloudoodle needs the camera to capture the sky. Enable it in iOS Settings → Cloudoodle → Camera, then come back.")
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onOpenSettings) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open iOS Settings")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22).padding(.vertical, 13)
                    .background(Capsule().fill(CV.Color.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Small UI components

private struct LocationChip: View {
    let city: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "location.fill").font(.system(size: 10, weight: .medium))
            Text(city).font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(.black.opacity(0.35)))
    }
}

private struct ShutterButton: View {
    let action: () -> Void
    @State private var pressed = false
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(.white.opacity(0.8), lineWidth: 3).frame(width: 76, height: 76)
                Circle().fill(.white).frame(width: 63, height: 63)
                    .scaleEffect(pressed ? 0.88 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.65), value: pressed)
            }
        }
        .scaleEffect(pressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: pressed)
        .buttonStyle(.plain)
        .accessibilityLabel("Capture sky")
        .accessibilityHint("Take a photo of the clouds overhead so Cloudoodle can find a shape")
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }
        )
    }
}
