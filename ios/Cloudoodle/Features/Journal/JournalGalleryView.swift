import SwiftUI

/// The user's Polaroid stack — a vertical scroll of past Polaroids
/// arranged like a physical photo album: each card tilted a hair
/// off-axis, the next card peeking above and below, so flipping
/// through reads as leafing through a stack. Tap a card to open
/// the full-screen detail view (large Polaroid + note editor).
///
/// Reached by swiping right from today's home view. Same darkroom
/// backdrop as the develop reveal so the swipe transition feels
/// continuous, not a context switch.
struct JournalGalleryView: View {
    @State private var store = JournalStore.shared
    @State private var detailEntry: JournalEntry?
    @State private var deleteConfirmFor: JournalEntry?
    @State private var shareImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @AppStorage("polaroid_show_shape_caption") private var showShapeCaption = true

    /// When presented from today's home view or the develop reveal,
    /// the entry the gallery should scroll to on appear.
    var focusEntryId: UUID? = nil
    /// Set when the gallery is hosted as an in-hierarchy overlay
    /// (the slide-in presentation) rather than a fullScreenCover.
    /// nil falls back to the environment dismiss.
    var onClose: (() -> Void)? = nil

    var body: some View {
        ZStack {
            backdrop

            if store.entries.isEmpty && store.hasLoaded {
                emptyState
            } else if !store.hasLoaded {
                ProgressView()
                    .tint(.white.opacity(0.6))
            } else {
                gallery
            }

            VStack {
                topBar
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .task { await store.loadIfNeeded() }
        // Mirror of the entry gesture: the user swiped right to slide
        // the gallery in, so swiping left slides it back out. The
        // vertical card scroll is unaffected (horizontal threshold).
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    if horizontal < -80, vertical < abs(horizontal) {
                        Haptics.soft()
                        close()
                    }
                }
        )
        .fullScreenCover(item: $detailEntry) { entry in
            // The detail view hosts its own delete confirmation —
            // this view is covered while it's up, so a dialog
            // presented from here would never appear. `onDelete`
            // is the post-confirmation action.
            JournalEntryDetailView(
                entry: entry,
                onDelete: { Task { await deleteEntry(entry) } }
            )
        }
        // Confirmation for the context-menu path only (no cover is
        // presented then, so this view can show the dialog itself).
        .confirmationDialog(
            "Delete this Polaroid?",
            isPresented: Binding(
                get: { deleteConfirmFor != nil },
                set: { if !$0 { deleteConfirmFor = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleteConfirmFor
        ) { entry in
            Button("Delete", role: .destructive) {
                Task { await deleteEntry(entry) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { entry in
            // Honesty about quota — free users sometimes try to
            // delete and re-scan. Set the expectation.
            if Calendar.current.isDateInToday(entry.createdAt),
               !SubscriptionService.shared.isSubscribed {
                Text("This is today's Polaroid. Deleting it won't give you another scan until tomorrow.")
            } else {
                Text("The note and the photo go with it. This can't be undone.")
            }
        }
        .sheet(item: Binding(
            get: { shareImage.map { SharePayload(image: $0) } },
            set: { if $0 == nil { shareImage = nil } }
        )) { payload in
            ActivityViewSheet(items: [payload.image])
        }
    }

    // MARK: - Stack layout

    @ViewBuilder
    private var gallery: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 28) {
                    Color.clear.frame(height: 96)   // breathing room under topBar
                    ForEach(stackItems) { item in
                        switch item {
                        case .header(let label):
                            monthHeader(label)
                        case .card(let index, let entry):
                            cardRow(entry: entry, index: index)
                                .id(entry.id)
                        }
                    }
                    Color.clear.frame(height: 60)   // bottom breathing room
                }
            }
            .task {
                guard let focus = focusEntryId else { return }
                // Brief delay so the scroll target has time to lay out.
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(focus, anchor: .center)
                }
            }
        }
    }

    /// Stack contents with month dividers injected wherever the
    /// month rolls over (entries are newest-first). Gives the stack
    /// findability at 50+ entries without adding a search UI.
    private enum StackItem: Identifiable {
        case header(String)
        case card(Int, JournalEntry)
        var id: String {
            switch self {
            case .header(let label): return "header-\(label)"
            case .card(_, let entry): return entry.id.uuidString
            }
        }
    }

    private var stackItems: [StackItem] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        var items: [StackItem] = []
        var lastLabel = ""
        for (i, entry) in store.entries.enumerated() {
            let label = fmt.string(from: entry.createdAt).uppercased()
            if label != lastLabel {
                items.append(.header(label))
                lastLabel = label
            }
            items.append(.card(i, entry))
        }
        return items
    }

    private func monthHeader(_ label: String) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 0.5)
            Text(label)
                .scaledFont(size: 11, weight: .semibold, design: .monospaced)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize()
            Rectangle().fill(.white.opacity(0.12)).frame(height: 0.5)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
    }

    /// A single Polaroid in the stack. Slight tilt, generous shadow,
    /// scaled down a touch from full-width so two cards can ALMOST
    /// fit on screen at once — communicating "there's more under
    /// this one" without needing an explicit affordance.
    private func cardRow(entry: JournalEntry, index: Int) -> some View {
        let polaroidWidth: CGFloat = UIScreen.main.bounds.width * 0.72
        return Button {
            Haptics.tap()
            detailEntry = entry
        } label: {
            PolaroidCard(
                entry: entry,
                showShapeCaption: showShapeCaption,
                tilt: tilt(forIndex: index)
            )
            .frame(width: polaroidWidth)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .contextMenu {
            // iOS-standard long-press menu: share + delete without
            // visible chrome on the card itself.
            Button {
                Task { await shareEntry(entry) }
            } label: {
                Label("Share Polaroid", systemImage: "square.and.arrow.up")
            }
            Button {
                // The user's own photograph, full capture resolution,
                // no frame and no ink.
                if let img = UIImage(data: entry.originalImageData) {
                    shareImage = img
                }
            } label: {
                Label("Share Original Photo", systemImage: "photo")
            }
            Button(role: .destructive) {
                deleteConfirmFor = entry
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } preview: {
            // Tap-and-hold preview: untilted, centered.
            PolaroidCard(entry: entry, showShapeCaption: showShapeCaption, tilt: 0)
                .frame(width: 320)
                .padding(20)
        }
        .accessibilityLabel("Polaroid from \(accessibleDate(entry.createdAt))")
        .accessibilityHint("Opens the Polaroid in detail")
    }

    /// Alternating subtle tilt — keeps the stack looking like
    /// thumbs-shuffled prints, not a flat grid. Amplitudes are small
    /// enough that the cards still read as legible.
    private func tilt(forIndex idx: Int) -> Double {
        let amplitudes: [Double] = [-2.0, 1.3, -1.0, 2.2, -1.6, 0.7, -2.6, 1.0]
        return amplitudes[idx % amplitudes.count]
    }

    private func accessibleDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }

    // MARK: - Chrome

    private var backdrop: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.07, blue: 0.09),
                     Color(red: 0.04, green: 0.02, blue: 0.03)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// Overlay-hosted galleries close via the parent's callback so
    /// the slide-out transition runs in the parent's hierarchy;
    /// cover-hosted ones use the environment dismiss.
    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private var topBar: some View {
        HStack {
            Button {
                close()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .scaledFont(size: 13, weight: .semibold)
                    Text("Today")
                        .scaledFont(size: 13, weight: .medium)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to today's Polaroid")
            Spacer()
            VStack(spacing: 2) {
                Text("YOUR CLOUDS")
                    .scaledFont(size: 11, weight: .semibold, design: .monospaced)
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                if !store.entries.isEmpty {
                    Text("\(store.entries.count) Polaroid\(store.entries.count == 1 ? "" : "s")")
                        .scaledFont(size: 11, design: .monospaced)
                        .foregroundStyle(.white.opacity(0.40))
                }
            }
            Spacer()
            // Mirror the back chip's width so the title stays centered.
            Color.clear.frame(width: 80, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("☁︎")
                .scaledFont(size: 56)
                .foregroundStyle(.white.opacity(0.6))
            Text("Your Polaroids will live here")
                .scaledFont(size: 18, weight: .regular, design: .serif)
                .foregroundStyle(.white.opacity(0.9))
            Text("Scan a sky · let it develop · write a few lines.\nA quiet daily ritual.")
                .scaledFont(size: 13, design: .serif)
                .italic()
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Share + delete handlers

    private func deleteEntry(_ entry: JournalEntry) async {
        let wasShowingDetail = (detailEntry?.id == entry.id)
        await store.delete(entry.id)
        if wasShowingDetail { detailEntry = nil }
    }

    /// Renders the Polaroid card to a UIImage for the iOS share sheet.
    /// ImageRenderer needs the actual SwiftUI view — we instantiate a
    /// fresh, untilted copy at a fixed size so the shared image looks
    /// printable rather than stack-tilted.
    @MainActor
    private func shareEntry(_ entry: JournalEntry) async {
        let card = PolaroidCard(
            entry: entry,
            showShapeCaption: showShapeCaption,
            tilt: 0
        )
        .frame(width: 720)
        .padding(28)
        .background(Color(red: 0.10, green: 0.07, blue: 0.09))

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            shareImage = image
        }
    }
}

// SharePayload + ActivityViewSheet live in UI/ShareSheet.swift —
// shared with JournalEntryDetailView.
