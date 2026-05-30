import SwiftUI
import AVFoundation

// The complete capture-to-result flow in one unbroken view.
// Four beats: viewfinder → freeze → scan (searching) → hand-drawing (revealing) → result.
struct CaptureFlowView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = CameraService()
    @State private var phase: CapturePhase = .viewfinder
    @State private var drawerPosition: GlassDrawer<DrawerBody>.DrawerPosition = .peek
    @State private var drawerInteractive = false
    @State private var capturedWeather: WeatherSnapshot?
    @State private var showNotificationPrompt = false
    @State private var scanError: String?

    @EnvironmentObject private var notifications: NotificationService

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
    }

    // MARK: - Phase routing

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .viewfinder:
            ViewfinderLayer(camera: camera) { Task { await capture() } }

        case .captured(let image):
            photoBackground(image)

        case .scanning(let image, let progress):
            ZStack {
                photoBackground(image)
                ScanLayer(progress: progress)
            }

        case .revealing(let sighting):
            ZStack {
                photoBackground(sighting)

                // THE moment: pen draws the cloud outline
                HandDrawingView(
                    elements: sighting.drawingElements,
                    shapeName: sighting.shapeName,
                    labelPosition: CGPoint(x: sighting.drawingLabelX, y: sighting.drawingLabelY)
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        drawerInteractive = true
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                overlayControls(sighting: sighting)
                quipCaption(sighting.quip)
                drawerLayer(sighting: sighting)

                if showNotificationPrompt {
                    notificationPrompt
                }
            }
            .onChange(of: drawerPosition) { _, newPosition in
                // Prompt after the user has already engaged with the drawer —
                // they've felt the value, so the ask feels earned rather than intrusive
                guard newPosition != .peek,
                      !notifications.hasSeenPrompt,
                      !notifications.isAuthorized,
                      !showNotificationPrompt else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    showNotificationPrompt = true
                }
            }
            .transition(.opacity)

        case .result(let sighting):
            ZStack {
                photoBackground(sighting)
                CloudOverlayView(sighting: sighting, animationProgress: 1.0).ignoresSafeArea()
                overlayControls(sighting: sighting)
                quipCaption(sighting.quip)
                drawerLayer(sighting: sighting)
            }
        }
    }

    // MARK: - Shared UI layers

    @ViewBuilder
    private func photoBackground(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }

    @ViewBuilder
    private func photoBackground(_ sighting: CloudSighting) -> some View {
        if let data = sighting.localImageData, let img = UIImage(data: data) {
            photoBackground(img)
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    private func overlayControls(sighting: CloudSighting) -> some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.35)))
                }
                Spacer()
                ShareButton(sighting: sighting)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Notification prompt

    private var notificationPrompt: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(CV.Color.accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(CV.Color.accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Know when to look up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CV.Color.textPrimary)
                        Text("We'll tell you when people near you spot something worth seeing.")
                            .font(.system(size: 13))
                            .foregroundStyle(CV.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button("Not Now") {
                        notifications.hasSeenPrompt = true
                        withAnimation(.spring(response: 0.35)) {
                            showNotificationPrompt = false
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CV.Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CV.Radius.sm))

                    Button("Turn On") {
                        withAnimation(.spring(response: 0.35)) {
                            showNotificationPrompt = false
                        }
                        Task { await notifications.requestPermission() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CV.Color.accent, in: RoundedRectangle(cornerRadius: CV.Radius.sm))
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CV.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CV.Radius.lg, style: .continuous)
                    .strokeBorder(CV.Color.glassBorder, lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 220)
            .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .ignoresSafeArea(edges: .bottom)
    }

    private func quipCaption(_ quip: String) -> some View {
        VStack {
            Spacer()
            Text(quip)
                .font(.custom("Georgia-Italic", size: 17))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 10)
                .padding(.horizontal, 36)
                .padding(.bottom, 212)
                .opacity(drawerPosition == .full ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: drawerPosition)
        }
    }

    private func drawerLayer(sighting: CloudSighting) -> some View {
        GlassDrawer(position: $drawerPosition, peekHeight: 192, halfFraction: 0.56) {
            DrawerBody(sighting: sighting, weather: capturedWeather)
        }
        .allowsHitTesting(drawerInteractive)
        .opacity(drawerInteractive ? 1.0 : 0.92)  // slightly muted during drawing
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
        // Capture location before going async (LocationService is @MainActor-bound)
        let captureLocation = location.currentLocation

        // All three run in parallel during the 2s scan animation
        async let visionTask = CloudVisionService.shared.analyzeCloudImage(image)
        async let geminiTask = GeminiService.shared.analyzeCloud(image: image)
        async let weatherTask = WeatherService.shared.fetch(for: captureLocation)

        // Scan sweeps the screen
        let scanDuration: Double = 2.0
        let start = Date()
        withAnimation(.easeOut(duration: 0.15)) { phase = .scanning(image, 0) }

        repeat {
            let elapsed = Date().timeIntervalSince(start)
            let p = min(elapsed / scanDuration, 1.0)
            if case .scanning = phase { phase = .scanning(image, p) }
            try? await Task.sleep(for: .milliseconds(16))
        } while Date().timeIntervalSince(start) < scanDuration

        // Collect results (almost certainly ready since scan took 2s)
        capturedWeather = await weatherTask
        do {
            let (visionResult, geminiResult) = try await (visionTask, geminiTask)
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

            // Label sits just above the visually interesting region (from saliency),
            // or above the centroid of Gemini's drawing if Vision found nothing.
            let labelX: Double
            let labelY: Double
            if !visionResult.salientRegion.isNull {
                labelX = visionResult.salientRegion.midX
                labelY = max(0.06, visionResult.salientRegion.minY - 0.07)
            } else {
                let pts = geminiResult.drawingElements.flatMap { $0.points }
                labelX = pts.isEmpty ? 0.5 : pts.map { $0[0] }.reduce(0, +) / Double(pts.count)
                labelY = max(0.06, (pts.isEmpty ? 0.22 : pts.map { $0[1] }.min() ?? 0.22) - 0.07)
            }

            // Gemini draws the shape it identified — not cloud-edge tracing, but artistic interpretation
            let drawingElements = geminiResult.drawingElements.map { $0.toDrawingElement() }

            let loc = location.currentLocation
            // Argument order matches the CloudSighting initializer declaration —
            // Swift requires labeled arguments to appear in declaration order, and
            // localImageData (init position 4) sits before analysis (position 5).
            // The previous form had it tucked in after `country`, which compiles
            // only because the parameter happens to allow that under some Swift
            // compiler versions; explicit declaration-order is safer and avoids
            // a future compile break when the rules tighten.
            let sighting = CloudSighting(
                localImageData: image.preparedForAnalysis(),
                analysis: analysis,
                drawingElements: drawingElements,
                drawingLabelX: labelX,
                drawingLabelY: labelY,
                latitude: loc?.coordinate.latitude,
                longitude: loc?.coordinate.longitude,
                city: location.currentCity,
                country: location.currentCountry
            )

            appState.pendingSighting = sighting

            // Success haptic — "found something"
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Transition to hand-drawing phase — drawer peeks immediately
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                drawerPosition = .peek
                phase = .revealing(sighting)
            }
        } catch {
            scanError = "AI couldn't identify a shape this time. Try an area of sky with more distinct cloud formations."
            withAnimation { phase = .viewfinder }
            try? await camera.requestPermissionAndSetup()
        }
    }
}

// MARK: - Phase enum

private enum CapturePhase {
    case viewfinder
    case captured(UIImage)
    case scanning(UIImage, Double)      // scan-line progress 0..1
    case revealing(CloudSighting)       // hand-drawing animation
    case result(CloudSighting)          // fully interactive (unused for now — revealing IS result)
}

// MARK: - Viewfinder layer

private struct ViewfinderLayer: View {
    let camera: CameraService
    let onCapture: () -> Void
    @EnvironmentObject private var location: LocationService

    var body: some View {
        ZStack {
            CameraPreviewLayer(session: camera.session)
                .ignoresSafeArea()

            // Bottom fade so shutter sits on something
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                // Top bar
                HStack {
                    // No dismiss here — user came here intentionally, back is the tab bar
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

// MARK: - Scan layer (pure searching — no contours yet)

private struct ScanLayer: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let y = progress * h

            ZStack {
                // Darken what hasn't been scanned yet
                Rectangle()
                    .fill(.black.opacity(0.18 * (1 - progress)))
                    .frame(height: max(0, h - y))
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // The scan beam — subtle frosted white line, Apple-style
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 60)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.0), .white.opacity(0.7), .white.opacity(0.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                    LinearGradient(
                        colors: [.white.opacity(0.04), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 20)
                }
                .frame(width: w)
                .offset(y: y - 60)

                // "Analysing" pill — fades out as scan completes
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white.opacity(0.5))
                        Text("Analysing")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .opacity(progress < 0.85 ? 1 : 1 - (progress - 0.85) / 0.15)
                    .padding(.bottom, 60)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Drawer body

private struct DrawerBody: View {
    let sighting: CloudSighting
    let weather: WeatherSnapshot?

    @State private var isSaving = false
    @State private var isSaved = false
    @State private var saveError: String?
    @State private var nearbySightings: [CloudSighting] = []
    @State private var isScrollAtTop = true

    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.drawerExpandedOpacity) private var expandedOpacity

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                peekStrip
                expandedContent
                    .opacity(expandedOpacity)
            }
            .preference(key: DrawerScrollAtTopKey.self, value: isScrollAtTop)
        }
        .trackScrollAtTop($isScrollAtTop)
        .task { await loadNearby() }
        .alert("Couldn't share sighting", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Peek (always visible)

    private var peekStrip: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                Text(sighting.shapeName)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text("\(sighting.watchabilityScore)/10")
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.accent)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(CV.Color.accent.opacity(0.15)))
            }

            Text(sighting.quip)
                .font(.custom("Georgia-Italic", size: 13))
                .foregroundStyle(CV.Color.textSecondary)
                .lineLimit(1)

            Text(conditionsContext(weather))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(CV.Color.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func conditionsContext(_ w: WeatherSnapshot?) -> String {
        guard let w else {
            if let city = sighting.city { return "captured in \(city)" }
            return "captured just now"
        }
        let cloudDesc = w.cloudCoverPct < 20 ? "clear sky" :
                        w.cloudCoverPct < 50 ? "scattered clouds" :
                        w.cloudCoverPct < 80 ? "broken cloud" : "overcast"
        let quality   = w.cloudCoverPct >= 20 && w.cloudCoverPct <= 65 ? "ideal for shapes" :
                        w.cloudCoverPct > 65 ? "closing in fast" : "few clouds to find"
        return "\(w.temperature)° · \(cloudDesc) · \(quality)"
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            DrawerDivider()

            if let w = weather {
                // Conditions overview bridges the drawing to the weather
                conditionsCard(w)
                DrawerDivider()
                // Watchability chart first — most actionable: when is the best time today?
                watchabilityChart(w)
                DrawerDivider()
                weatherStatsGrid(w)
                DrawerDivider()
                skyDetailsCard(w)
                DrawerDivider()
                sunBar(w)
                DrawerDivider()
            }

            aiDetectionCard
            DrawerDivider()
            nearbySection

            if let w = weather {
                DrawerDivider()
                weekAheadCard(w)
            }

            DrawerDivider()
            shareButton

            Color.clear.frame(height: 32)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Conditions overview

    private func conditionsCard(_ w: WeatherSnapshot) -> some View {
        let cloudDesc: String
        let cloudQual: String
        if w.cloudCoverPct < 20 {
            cloudDesc = "Clear sky"; cloudQual = "few shapes to find"
        } else if w.cloudCoverPct < 50 {
            cloudDesc = "Scattered cumulus"; cloudQual = "ideal for shapes"
        } else if w.cloudCoverPct < 80 {
            cloudDesc = "Broken cloud"; cloudQual = "good canvas overhead"
        } else {
            cloudDesc = "Overcast"; cloudQual = "catch it quick"
        }

        return DrawerCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(cloudDesc) at \(w.cloudCoverPct)% cover — \(cloudQual).")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let alert = w.precipAlert {
                    HStack(spacing: 6) {
                        Image(systemName: "cloud.rain").font(.system(size: 12))
                        Text(alert)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(CV.Color.accentBlue)
                }
            }
        }
    }

    // MARK: - AI detection card

    private var aiDetectionCard: some View {
        DrawerCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("AI Detection", systemImage: "sparkles")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(CV.Color.textTertiary)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline) {
                    Text(sighting.shapeName)
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .foregroundStyle(CV.Color.textPrimary)
                    Spacer()
                    Text(sighting.weatherMood.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(CV.Color.accent)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(CV.Color.accent.opacity(0.15)))
                }
                Text("painted on \(sighting.cloudType.lowercased())")
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textSecondary)

                WatchabilityBar(score: sighting.watchabilityScore)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Weather stats 2×2 grid

    private func weatherStatsGrid(_ w: WeatherSnapshot) -> some View {
        let stats = [
            ("feels", "\(w.feelsLike)°"),
            ("wind", "\(w.windSpeed) \(w.windDirection)"),
            ("humid", "\(w.humidity)%"),
            ("UV", "\(w.uvIndex)")
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(stats, id: \.0) { label, value in
                DrawerCard(padding: EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 12)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(label.uppercased())
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(CV.Color.textTertiary)
                        Text(value)
                            .font(.system(size: 26, weight: .regular, design: .serif))
                            .foregroundStyle(CV.Color.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Sky details

    private func skyDetailsCard(_ w: WeatherSnapshot) -> some View {
        let visStr = String(format: "%.1f mi", w.visibilityMiles)
        let visQual = w.visibilityMiles > 8 ? "crystalline" : w.visibilityMiles > 4 ? "clear" : "reduced"
        let cloudQual = w.cloudCoverPct < 20 ? "sparse" : w.cloudCoverPct < 50 ? "scattered" : w.cloudCoverPct < 80 ? "broken" : "overcast"
        let dewQual = w.dewPoint < 50 ? "dry" : w.dewPoint < 60 ? "comfortable" : "humid"

        let rows = [
            ("Cloud cover", "\(w.cloudCoverPct)%", cloudQual),
            ("Visibility",  visStr,                visQual),
            ("Dewpoint",    "\(w.dewPoint)°",       dewQual)
        ]

        return DrawerCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Sky details".uppercased())
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(CV.Color.textTertiary)
                    .padding(.bottom, 10)

                ForEach(Array(rows.enumerated()), id: \.0) { i, row in
                    if i > 0 { Divider().overlay(Color.white.opacity(0.07)).padding(.vertical, 0) }
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.0).font(.system(size: 14.5, weight: .medium)).foregroundStyle(CV.Color.textPrimary)
                        Spacer()
                        Text(row.2).font(CV.Font.caption).foregroundStyle(CV.Color.textTertiary)
                        Text(row.1)
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .foregroundStyle(CV.Color.textPrimary)
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 9)
                }
            }
        }
    }

    // MARK: - Sunrise / sunset bar

    private func sunBar(_ w: WeatherSnapshot) -> some View {
        let now = Date()
        let total = w.sunset.timeIntervalSince(w.sunrise)
        let elapsed = now.timeIntervalSince(w.sunrise)
        let progress = max(0, min(1, elapsed / total))
        let goldenFraction = 3600.0 / total   // 1h window as fraction

        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"

        let sunriseStr = fmt.string(from: w.sunrise).lowercased()
        let sunsetStr  = fmt.string(from: w.sunset).lowercased()
        let goldenStr  = fmt.string(from: w.sunset.addingTimeInterval(-3600)).lowercased()

        let daylightLeft = max(0, w.sunset.timeIntervalSince(now))
        let hoursLeft = Int(daylightLeft / 3600)
        let minsLeft  = Int((daylightLeft.truncatingRemainder(dividingBy: 3600)) / 60)
        let leftStr = hoursLeft > 0 ? "\(hoursLeft)h \(minsLeft)m" : "\(minsLeft)m"

        return DrawerCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Light today".uppercased())
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(CV.Color.textTertiary)
                    Spacer()
                    Text("golden hour at \(goldenStr)")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 8)

                        // Golden hour zone (last ~1h before sunset)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [CV.Color.accent.opacity(0.5), CV.Color.accent],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * goldenFraction, height: 8)
                            .offset(x: geo.size.width * (1 - goldenFraction))

                        // Sun position dot
                        Circle()
                            .fill(.white)
                            .frame(width: 18, height: 18)
                            .shadow(color: CV.Color.accent.opacity(0.6), radius: 6)
                            .offset(x: geo.size.width * progress - 9)
                    }
                }
                .frame(height: 18)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sunrise".uppercased()).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(CV.Color.textTertiary)
                        Text(sunriseStr).font(.system(size: 18, weight: .regular, design: .serif)).foregroundStyle(CV.Color.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 2) {
                        Text("Daylight left".uppercased()).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(CV.Color.textTertiary)
                        Text(leftStr).font(.system(size: 18, weight: .regular, design: .serif)).foregroundStyle(CV.Color.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Sunset".uppercased()).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(CV.Color.textTertiary)
                        Text(sunsetStr).font(.system(size: 18, weight: .regular, design: .serif)).foregroundStyle(CV.Color.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Watchability next 8h chart

    private func watchabilityChart(_ w: WeatherSnapshot) -> some View {
        let hours = w.hourlyWatchability
        let peak = hours.max(by: { $0.score < $1.score })

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Watchability · next 8h".uppercased())
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(CV.Color.textTertiary)
                Spacer()
                if let p = peak {
                    Text("peak \(p.label)")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textSecondary)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(hours.enumerated()), id: \.0) { i, h in
                    let isPeak = h.label == peak?.label
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 52)
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isPeak ? CV.Color.accent : Color.white.opacity(0.3))
                                .frame(height: max(4, 52 * h.score))
                        }
                        Text(h.label)
                            .font(.system(size: 10, weight: isPeak ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(isPeak ? CV.Color.textPrimary : CV.Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Seen nearby

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seen nearby".uppercased())
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(CV.Color.textTertiary)

            if nearbySightings.isEmpty {
                Text("Nothing spotted nearby yet — you might be first.")
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textTertiary)
                    .padding(.vertical, 4)
            } else {
                // Horizontal gallery: the quip is the art, not the person
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(nearbySightings.prefix(8)) { s in
                            NearbyQuipCard(sighting: s)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, -20)   // bleed to screen edges past the outer padding
            }
        }
    }

    // MARK: - Week ahead

    private func weekAheadCard(_ w: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The week ahead".uppercased())
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(CV.Color.textTertiary)

            DrawerCard {
                VStack(spacing: 0) {
                    ForEach(Array(w.weekAhead.enumerated()), id: \.0) { i, day in
                        if i > 0 { Divider().overlay(Color.white.opacity(0.07)) }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(day.dayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CV.Color.textPrimary)
                                .frame(width: 90, alignment: .leading)
                            Text(day.skyDescription)
                                .font(.system(size: 13.5))
                                .foregroundStyle(CV.Color.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            if day.bestWindow != "—" {
                                Text(day.bestWindow)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(CV.Color.accent)
                            }
                            Text("\(day.highTemp)°")
                                .font(.system(size: 19, weight: .regular, design: .serif))
                                .foregroundStyle(CV.Color.textPrimary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    // MARK: - Share / save button

    private var shareButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.black).scaleEffect(0.75)
                } else {
                    Image(systemName: isSaved ? "checkmark" : "arrow.up.circle.fill")
                }
                Text(isSaving ? "Saving…" : isSaved ? "Shared with Community" : "Share with Community")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(isSaved ? CV.Color.textSecondary : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: CV.Radius.md)
                    .fill(isSaved ? Color.white.opacity(0.1) : CV.Color.accent)
            )
        }
        .disabled(isSaving || isSaved)
    }

    // MARK: - Data

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        guard let data = sighting.localImageData else {
            saveError = "Photo data unavailable — try capturing again."
            return
        }
        do {
            _ = try await supabase.uploadSighting(sighting, imageData: data)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isSaved = true
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func loadNearby() async {
        guard let lat = sighting.latitude, let lon = sighting.longitude else { return }
        guard let nearby = try? await supabase.fetchNearbySightings(latitude: lat, longitude: lon, radiusKm: 50) else { return }
        // Exclude the sighting just captured
        nearbySightings = nearby.filter { $0.id != sighting.id }
    }
}

// MARK: - Drawer sub-components

private struct DrawerDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.vertical, 14)
    }
}

private struct DrawerCard<Content: View>: View {
    let padding: EdgeInsets
    let content: Content

    init(padding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16), @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: CV.Radius.md)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: CV.Radius.md).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            )
    }
}

// MARK: - Nearby quip card

private struct NearbyQuipCard: View {
    let sighting: CloudSighting

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The quip is the centrepiece — it IS the art
            Text(sighting.quip)
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundStyle(CV.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(sighting.shapeName)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(CV.Color.accent)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let city = sighting.city {
                        Text(city)
                            .lineLimit(1)
                    }
                    Text("·")
                    Text(sighting.createdAt, style: .relative)
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(CV.Color.textTertiary)
            }
        }
        .padding(14)
        .frame(width: 168, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CV.Radius.md)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: CV.Radius.md).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        )
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

private struct ShareButton: View {
    let sighting: CloudSighting
    @State private var showSheet = false
    @State private var artworkImage: UIImage?
    @State private var isRendering = false

    var body: some View {
        Button {
            guard !isRendering else { return }
            Task { await prepareAndShare() }
        } label: {
            ZStack {
                Circle().fill(.black.opacity(0.35)).frame(width: 44, height: 44)
                if isRendering {
                    ProgressView().tint(.white).scaleEffect(0.7)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            if let img = artworkImage {
                ShareSheet(items: [img, sighting.quip])
            }
        }
    }

    @MainActor
    private func prepareAndShare() async {
        isRendering = true
        artworkImage = renderArtwork()
        isRendering = false
        showSheet = true
    }

    // Composites the photo and the AI drawing into a single shareable image.
    // The result is what users actually want to share — not the raw photo.
    @MainActor
    private func renderArtwork() -> UIImage? {
        guard let data = sighting.localImageData,
              let bg = UIImage(data: data) else { return nil }

        let size = CGSize(width: 1080, height: 1920)
        let composite = ZStack {
            Image(uiImage: bg)
                .resizable()
                .scaledToFill()
            CloudOverlayView(sighting: sighting, animationProgress: 1.0)
        }
        .frame(width: size.width, height: size.height)
        .clipped()

        let renderer = ImageRenderer(content: composite)
        renderer.scale = 1.0
        return renderer.uiImage
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
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }
        )
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// onScrollGeometryChange is iOS 18+ but the deployment target is 17.
// Gate it so iOS 17 simply doesn't refine the gesture-vs-scroll handoff;
// the drawer still functions, the scroll-at-top state just stays at its
// initial value (true) and GlassDrawer treats the drag as a drawer drag
// when the scroll position can't be measured. Acceptable graceful
// degradation until we can bump the deployment floor to 18.
private extension View {
    @ViewBuilder
    func trackScrollAtTop(_ isAtTop: Binding<Bool>) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y <= 2
            } action: { _, atTop in
                isAtTop.wrappedValue = atTop
            }
        } else {
            self
        }
    }
}
