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
///   • Gear icon         → Settings
///   • Stack icon        → gallery (mirror of the swipe-right gesture)
///   • Subscribers see a "Capture another sky" button in the drawer
///   • Free users see "Tomorrow's sky awaits" + a soft upsell
struct TodaysPolaroidView: View {
    let entry: JournalEntry
    /// Called when the user wants to go back to the camera. Only the
    /// caller knows whether to honor it (subscriber) or present the
    /// upgrade sheet (free user) — we just forward intent.
    var onCaptureRequested: () -> Void = {}

    @State private var subscriptions = SubscriptionService.shared
    @State private var store = JournalStore.shared
    @State private var showGallery = false
    @State private var showNoteEditor = false
    @State private var showUpgrade = false
    @State private var showSettings = false
    @State private var dragOffset: CGFloat = 0
    @State private var weather: WeatherSnapshot?

    @EnvironmentObject private var location: LocationService

    @AppStorage("polaroid_show_shape_caption") private var showShapeCaption = true

    @State private var drawerPosition: GlassDrawer<WeatherDrawerContent<AnyView>>.DrawerPosition = .peek

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8)
                ZoomableView(onSingleTap: { showNoteEditor = true }) { polaroid }
                    .padding(.horizontal, 36)
                    .offset(x: dragOffset)
                    .rotationEffect(.degrees(-1.2 + dragOffset / 80))
                    .gesture(swipeToGallery)
                Spacer(minLength: 8)
                Color.clear.frame(height: 260)   // reserve space for drawer peek
            }

            GlassDrawer(position: $drawerPosition, peekHeight: 200, halfFraction: 0.55) {
                WeatherDrawerContent(weather: weather) {
                    AnyView(drawerActionRow)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadWeather() }
        .fullScreenCover(isPresented: $showGallery) {
            JournalGalleryView(focusEntryId: entry.id)
        }
        .sheet(isPresented: $showNoteEditor) { NoteEditorSheet(entry: entry) }
        .sheet(isPresented: $showUpgrade) { UpgradeSheetView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
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
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            Spacer()
            VStack(spacing: 2) {
                Text("TODAY")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                if store.currentStreak >= 2 {
                    Text("\(store.currentStreak)-DAY STREAK")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(CV.Color.accent.opacity(0.85))
                } else {
                    Text(headerDate)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.40))
                }
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

    /// The action row that sits at the top of the weather drawer.
    /// Subscribers get a primary CTA to capture another sky; free
    /// users get the gentle "tomorrow" framing with a quiet upsell.
    @ViewBuilder
    private var drawerActionRow: some View {
        if subscriptions.isSubscribed {
            Button(action: handleCaptureRequest) {
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
                Button { showUpgrade = true } label: {
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
