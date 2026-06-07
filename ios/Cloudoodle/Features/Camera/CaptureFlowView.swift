import SwiftUI
import AVFoundation

/// One-shot capture-to-Polaroid flow. Single beat now:
///   viewfinder → shutter → developing Polaroid → save → done.
///
/// The old hand-drawn reveal path (HandDrawingView, ScanLayer beam,
/// AI-drawn doodle) has been retired — every scan now goes straight
/// into the OpenAI "Develop" call and produces a Polaroid. Gemini
/// still runs in the background to populate the shape name + cloud
/// type + weather mood metadata that the Polaroid + journal use.
///
/// Quota gating happens one level up in CaptureRootView; if we're
/// presented here, the user is allowed to scan.
struct CaptureFlowView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss

    /// Fires once after the develop completes AND its JournalEntry is
    /// persisted AND the user has tapped through the develop view.
    /// CaptureRootView uses this to swap to TodaysPolaroidView.
    var onCompleted: () -> Void = {}

    @StateObject private var camera = CameraService()
    @State private var phase: CapturePhase = .viewfinder
    @State private var capturedWeather: WeatherSnapshot?
    @State private var capturedSighting: CloudSighting?
    @State private var scanError: String?

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
        .task { try? await camera.requestPermissionAndSetup() }
        .alert("Couldn't read that sky", isPresented: Binding(
            get: { scanError != nil },
            set: { if !$0 { scanError = nil } }
        )) {
            Button("Try Again") { scanError = nil }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text(scanError ?? "")
        }
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
            Button("OK", role: .cancel) {}
        } message: {
            Text(polaroidError ?? "")
        }
    }

    // MARK: - Develop flow

    /// Kicks off the AI develop using the captured photo. Runs as
    /// soon as the scan completes so the Polaroid reveal feels like
    /// one continuous moment instead of "scan, then tap a second
    /// button to actually get the thing."
    private func startDevelop(originalImage: UIImage, sighting: CloudSighting) {
        polaroidOriginal = originalImage
        polaroidDeveloped = nil
        polaroidProgress = 0
        polaroidJournalEntryId = nil
        showPolaroid = true

        let originalData = sighting.localImageData ?? Data()

        Task {
            do {
                // Smart-crop around the top Vision candidate — the
                // crop is what we actually send to the API, saving
                // ~40% on the image-token cost.
                let candidates = await CloudVisionService.shared.findCandidateRegions(in: originalImage, topK: 1)
                let crop = SmartCrop.crop(photo: originalImage, around: candidates.first)
                let pngData = try await ImageGenerationService.shared.develop(crop: crop.cropped)
                guard let img = UIImage(data: pngData) else {
                    throw ImageGenerationError.parseError("Empty image bytes")
                }
                // Composite developed crop back into the original
                // frame so the surrounding photo stays intact — the
                // viewer sees the full sky with ink in the right spot.
                let composited = await Self.composite(
                    base: originalImage,
                    overlay: img,
                    in: crop.normalizedRect
                )
                let entry = JournalEntry(
                    originalImageData: originalImage.jpegData(compressionQuality: 0.85) ?? originalData,
                    developedImageData: composited.jpegData(compressionQuality: 0.88),
                    shapeName: sighting.shapeName,
                    quip: sighting.quip,
                    cloudType: sighting.cloudType,
                    weatherMood: sighting.weatherMood,
                    city: sighting.city,
                    country: sighting.country,
                    temperatureF: capturedWeather?.temperature,
                    cloudCoverPct: capturedWeather?.cloudCoverPct
                )
                let saved = await JournalStore.shared.add(entry)
                await MainActor.run {
                    polaroidDeveloped = composited
                    polaroidProgress = 1.0
                    polaroidJournalEntryId = saved.id
                }
            } catch {
                await MainActor.run {
                    polaroidError = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    showPolaroid = false
                    // Reset to viewfinder so the user can try again
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
            ViewfinderLayer(camera: camera, onClose: { dismiss() }) {
                Task { await capture() }
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        do {
            let image = try await camera.capturePhoto()
            camera.stop()
            withAnimation(.easeIn(duration: 0.06)) { phase = .captured(image) }
            try? await Task.sleep(for: .milliseconds(100))
            await scan(image: image)
        } catch {
            dismiss()
        }
    }

    private func scan(image: UIImage) async {
        Telemetry.scanAttempt()
        let captureLocation = location.currentLocation

        async let weatherTask = WeatherService.shared.fetch(for: captureLocation)

        // Vision extracts cloud-edge waypoints + salient region.
        let visionResultEarly: CloudVisionService.Result =
            (try? await CloudVisionService.shared.analyzeCloudImage(image))
            ?? CloudVisionService.Result(salientRegion: .null, waypoints: [], drawingElements: [])

        // Gemini gives us the shape name + cloud type + weather mood
        // metadata. We don't render its strokes anymore — the
        // doodle reveal was retired — but the text fields are still
        // used by the Polaroid + journal.
        async let geminiTask = GeminiService.shared.analyzeCloud(
            image: image,
            cloudWaypoints: visionResultEarly.waypoints
        )

        // Brief "reading the sky" beat — short enough to feel
        // responsive, long enough that the Gemini call (~1-2 s) has
        // almost always returned by the time we transition.
        let scanDuration: Double = 1.6
        let start = Date()
        withAnimation(.easeOut(duration: 0.12)) { phase = .scanning(image, 0) }
        repeat {
            let elapsed = Date().timeIntervalSince(start)
            let p = min(elapsed / scanDuration, 1.0)
            if case .scanning = phase { phase = .scanning(image, p) }
            try? await Task.sleep(for: .milliseconds(16))
        } while Date().timeIntervalSince(start) < scanDuration

        capturedWeather = await weatherTask
        do {
            let geminiResult = try await geminiTask
            let quip = await QuipGenerationService.shared.generateQuip(
                shapeName: geminiResult.shapeName,
                cloudType: geminiResult.cloudType
            )
            let analysis = CloudAnalysis(
                shapeName: geminiResult.shapeName,
                quip: quip,
                cloudType: geminiResult.cloudType,
                weatherMood: geminiResult.weatherMood,
                watchabilityScore: geminiResult.watchabilityScore
            )
            // Drawing elements stay in the data model for backwards
            // compat with serialised sightings, but nothing renders
            // them anymore.
            let sighting = CloudSighting(
                localImageData: image.preparedForAnalysis(),
                analysis: analysis,
                drawingElements: [],
                drawingLabelX: 0.5,
                drawingLabelY: 0.2,
                latitude: captureLocation?.coordinate.latitude,
                longitude: captureLocation?.coordinate.longitude,
                city: location.currentCity,
                country: location.currentCountry
            )
            capturedSighting = sighting
            appState.pendingSighting = sighting
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Telemetry.scanSuccess(shapeName: geminiResult.shapeName)

            // Straight into developing — no intermediate reveal.
            startDevelop(originalImage: image, sighting: sighting)
        } catch {
            Telemetry.scanFailure(error: error)
            scanError = Self.scanErrorMessage(for: error)
            withAnimation { phase = .viewfinder }
            try? await camera.requestPermissionAndSetup()
        }
    }

    private static func scanErrorMessage(for error: Error) -> String {
        if let gemini = error as? GeminiError {
            switch gemini {
            case .missingAPIKey:
                return "Add your Gemini API key in Settings to scan clouds. It's free at aistudio.google.com."
            case .imageEncodingFailed:
                return "Couldn't read that photo. Try capturing again."
            case .networkError:
                return "Network hiccup — check your connection and try again."
            case .invalidResponse(let code, _):
                switch code {
                case 401, 403: return "Gemini rejected the request — your API key may be invalid."
                case 429:      return "Too many scans this minute. Take a breath and try again."
                case 500...599: return "Gemini is having a moment. Try again in a few seconds."
                default:       return "Gemini returned an error (\(code)). Try again."
                }
            case .parseError:
                return "AI couldn't identify a shape this time. Try an area of sky with more distinct cloud formations."
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return "Network hiccup — check your connection and try again."
        }
        return "AI couldn't identify a shape this time. Try an area of sky with more distinct cloud formations."
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
    let onClose: () -> Void
    let onCapture: () -> Void
    @EnvironmentObject private var location: LocationService

    var body: some View {
        ZStack {
            CameraPreviewLayer(session: camera.session)
                .ignoresSafeArea()

            // Bottom fade so shutter sits on something
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.5)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.black.opacity(0.35)))
                    }
                    .accessibilityLabel("Close camera")
                    Spacer()
                    if let city = location.currentCity {
                        LocationChip(city: city)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                Text("Point at the sky")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 24)

                ShutterButton(action: onCapture)
                    .padding(.bottom, 52)
            }
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
