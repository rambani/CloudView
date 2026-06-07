import SwiftUI

/// Daily home view — shown for the rest of the day after a user
/// captures their Polaroid. The whole point of Cloudoodle is one
/// considered moment with the sky per day; this is the resting view
/// that respects that ritual.
///
/// Interactions:
///   • Tap the Polaroid → open the note editor sheet
///   • Swipe right       → open the gallery of past Polaroids
///   • Swipe up (drawer) → today's weather details
///   • Subscribers see a "Capture another sky" button
///   • Free users see "Tomorrow's sky awaits" and a soft upsell
struct TodaysPolaroidView: View {
    let entry: JournalEntry
    /// Called when the user wants to go back to the camera. Only the
    /// caller knows whether to honor it (subscriber) or present the
    /// upgrade sheet (free user) — we just forward intent.
    var onCaptureRequested: () -> Void = {}
    var onDismiss: () -> Void = {}

    @State private var subscriptions = SubscriptionService.shared
    @State private var showGallery = false
    @State private var showNoteEditor = false
    @State private var showUpgrade = false
    @State private var dragOffset: CGFloat = 0
    @State private var weather: WeatherSnapshot?

    @EnvironmentObject private var location: LocationService

    @AppStorage("polaroid_show_shape_caption") private var showShapeCaption = true

    @State private var drawerPosition: GlassDrawer<TodaysWeatherPanel>.DrawerPosition = .peek

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8)
                polaroid
                    .padding(.horizontal, 36)
                    .offset(x: dragOffset)
                    .rotationEffect(.degrees(-1.2 + dragOffset / 80))
                    .gesture(swipeToGallery)
                    .onTapGesture { showNoteEditor = true }
                Spacer(minLength: 8)
                Color.clear.frame(height: 260)   // reserve space for drawer peek
            }

            GlassDrawer(position: $drawerPosition, peekHeight: 200, halfFraction: 0.55) {
                TodaysWeatherPanel(
                    entry: entry,
                    weather: weather,
                    isSubscribed: subscriptions.isSubscribed,
                    onCaptureAnother: handleCaptureRequest,
                    onUpgrade: { showUpgrade = true }
                )
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadWeather()
        }
        .fullScreenCover(isPresented: $showGallery) {
            JournalGalleryView(focusEntryId: entry.id)
        }
        .sheet(isPresented: $showNoteEditor) {
            noteEditorSheet
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeSheetView()
        }
    }

    // MARK: - Sections

    private var backdrop: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.07, blue: 0.09),
                     Color(red: 0.04, green: 0.02, blue: 0.03)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text("TODAY")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                Text(headerDate)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
            }
            Spacer()
            Button {
                showGallery = true
            } label: {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open your stack of Polaroids")
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    private var polaroid: some View {
        PolaroidCard(entry: entry, showShapeCaption: showShapeCaption, tilt: -1.2)
    }

    // MARK: - Note editor sheet

    private var noteEditorSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(entry.captionLine)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.black.opacity(0.5))
                JournalNoteEditor(entryId: entry.id, initial: entry.note)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private var headerDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: entry.createdAt).lowercased()
    }

    private func handleCaptureRequest() {
        if subscriptions.isSubscribed {
            onCaptureRequested()
        } else {
            showUpgrade = true
        }
    }

    private func loadWeather() async {
        guard weather == nil else { return }
        weather = await WeatherService.shared.fetch(for: location.currentLocation)
    }

    /// Right-swipe gesture — the cue that opens the gallery. Card
    /// follows the finger with mild resistance, springs back if the
    /// user releases below the commit threshold.
    private var swipeToGallery: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard value.translation.width > 0 else { return }
                dragOffset = value.translation.width * 0.7
            }
            .onEnded { value in
                let commit = value.translation.width > 80
                    || value.predictedEndTranslation.width > 180
                if commit {
                    withAnimation(.easeOut(duration: 0.18)) {
                        dragOffset = UIScreen.main.bounds.width
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(160))
                        showGallery = true
                        try? await Task.sleep(for: .milliseconds(50))
                        dragOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

// MARK: - Weather panel (drawer content)

/// Slim weather drawer for the daily home view. Reads as a peek
/// (action row + a couple of stats) and expands to show the
/// hourly watchability chart + sun arc when pulled higher.
struct TodaysWeatherPanel: View {
    let entry: JournalEntry
    let weather: WeatherSnapshot?
    let isSubscribed: Bool
    let onCaptureAnother: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                actionRow
                if let w = weather {
                    conditionsRow(w)
                    watchabilityChart(w)
                    sunBar(w)
                } else {
                    weatherUnavailable
                }
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            if isSubscribed {
                Button(action: onCaptureAnother) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text("Capture another sky")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: CV.Radius.md).fill(CV.Color.accent))
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .center, spacing: 6) {
                    Text("Tomorrow's sky awaits ☁︎")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.75))
                    Button(action: onUpgrade) {
                        Text("Or unlock unlimited Polaroids")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(CV.Color.accent)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: CV.Radius.md)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: CV.Radius.md)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
            }
        }
    }

    private func conditionsRow(_ w: WeatherSnapshot) -> some View {
        let cloudDesc: String
        let cloudQual: String
        switch w.cloudCoverPct {
        case ..<20:  cloudDesc = "Clear sky";         cloudQual = "few shapes to find"
        case ..<50:  cloudDesc = "Scattered cumulus"; cloudQual = "ideal for shapes"
        case ..<80:  cloudDesc = "Broken cloud";      cloudQual = "good canvas overhead"
        default:     cloudDesc = "Overcast";          cloudQual = "catch it quick"
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Right now".uppercased())
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(CV.Color.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(w.temperature)°")
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cloudDesc)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CV.Color.textPrimary)
                    Text("\(w.cloudCoverPct)% cover · \(cloudQual)")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textSecondary)
                }
                Spacer()
            }
        }
    }

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
                ForEach(Array(hours.enumerated()), id: \.0) { _, h in
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

    private func sunBar(_ w: WeatherSnapshot) -> some View {
        let now = Date()
        let total = max(1, w.sunset.timeIntervalSince(w.sunrise))
        let elapsed = now.timeIntervalSince(w.sunrise)
        let progress = max(0, min(1, elapsed / total))

        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"

        return VStack(alignment: .leading, spacing: 10) {
            Text("Light today".uppercased())
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(CV.Color.textTertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 8)
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: CV.Color.accent.opacity(0.6), radius: 6)
                        .offset(x: geo.size.width * progress - 8)
                }
            }
            .frame(height: 18)
            HStack {
                Text(fmt.string(from: w.sunrise).lowercased())
                Spacer()
                Text(fmt.string(from: w.sunset).lowercased())
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(CV.Color.textTertiary)
        }
    }

    private var weatherUnavailable: some View {
        HStack(spacing: 10) {
            Image(systemName: "cloud.slash")
                .foregroundStyle(CV.Color.textTertiary)
            Text("Weather unavailable — check location access.")
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textSecondary)
        }
        .padding(.vertical, 6)
    }
}
