import SwiftUI

/// The user's Polaroid stack — horizontal swipe-through of past
/// developed cloud sightings, each with its caption and (optional)
/// note about the day. Reached by swiping right from today's
/// Polaroid view, or from the Profile tab.
///
/// Design notes:
///   • Same darkroom-red ambient backdrop as the develop view so
///     the swipe transition feels continuous, not a context switch.
///   • Each page is one Polaroid centered with a peek of the next
///     and previous cards on either side (so the "stack" reads).
///   • Tap a card to open the note editor.
///   • Empty state explains the ritual: scan → develop → note.
struct JournalGalleryView: View {
    @State private var store = JournalStore.shared
    @State private var currentIndex: Int = 0
    @State private var editingNoteFor: UUID?
    @State private var deleteConfirmFor: JournalEntry?
    @State private var shareImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @AppStorage("polaroid_show_shape_caption") private var showShapeCaption = true

    /// When presented from today's Polaroid view or the develop
    /// reveal, the entry that should be focused on appear.
    var focusEntryId: UUID? = nil

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
        .task {
            await store.loadIfNeeded()
            if let focus = focusEntryId,
               let idx = store.entries.firstIndex(where: { $0.id == focus }) {
                currentIndex = idx
            }
        }
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

    // MARK: - Share + delete handlers

    private func deleteEntry(_ entry: JournalEntry) async {
        // Step out of the page that's about to vanish so SwiftUI
        // doesn't fight a vanishing TabView selection.
        if store.entries.count <= 1 {
            await store.delete(entry.id)
            dismiss()
            return
        }
        let nextIndex = max(0, currentIndex - 1)
        await store.delete(entry.id)
        currentIndex = nextIndex
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
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Today")
                        .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                if !store.entries.isEmpty {
                    Text("\(currentIndex + 1) of \(store.entries.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.40))
                }
            }
            Spacer()
            // Balance the back chip on the right so the title stays
            // centered. Same dimensions, invisible.
            Color.clear.frame(width: 80, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    @ViewBuilder
    private var gallery: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(store.entries.enumerated()), id: \.element.id) { i, entry in
                page(for: entry, index: i).tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }

    private func page(for entry: JournalEntry, index: Int) -> some View {
        VStack(spacing: 18) {
            Spacer()
            PolaroidCard(
                entry: entry,
                showShapeCaption: showShapeCaption,
                tilt: tilt(forIndex: index)
            )
            .padding(.horizontal, 36)
            .onTapGesture { editingNoteFor = entry.id }
            .contextMenu {
                // Long-press menu — discoverable via the iOS-standard
                // gesture, invisible chrome otherwise.
                Button {
                    Task { await shareEntry(entry) }
                } label: {
                    Label("Share Polaroid", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    deleteConfirmFor = entry
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            noteRow(for: entry)
                .padding(.horizontal, 28)
            Spacer()
        }
        .sheet(isPresented: Binding(
            get: { editingNoteFor == entry.id },
            set: { if !$0 { editingNoteFor = nil } }
        )) {
            noteEditorSheet(for: entry)
        }
    }

    @ViewBuilder
    private func noteRow(for entry: JournalEntry) -> some View {
        if let note = entry.note, !note.isEmpty {
            Button {
                editingNoteFor = entry.id
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                    Text("Tap to edit")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(1)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        } else {
            Button {
                editingNoteFor = entry.id
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                    Text("Write a note about today")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .italic()
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(
                    Capsule().fill(.white.opacity(0.10))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func noteEditorSheet(for entry: JournalEntry) -> some View {
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("☁︎")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.6))
            Text("Your Polaroids will live here")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.9))
            Text("Scan a sky · let it develop · write a few lines.\nA quiet daily ritual.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 36)
    }

    /// Subtle alternating tilt per index — gives the stack feel
    /// without making everything wobble identically.
    private func tilt(forIndex idx: Int) -> Double {
        let amplitudes: [Double] = [-1.4, -0.6, -2.0, 0.8, -1.0, 1.6]
        return amplitudes[idx % amplitudes.count]
    }
}

/// Identifiable wrapper so the share sheet can present from a
/// nil-able binding without re-presenting whenever currentIndex
/// flips. The id encodes the image itself by reference.
private struct SharePayload: Identifiable {
    let image: UIImage
    var id: ObjectIdentifier { ObjectIdentifier(image) }
}

/// UIKit bridge for `UIActivityViewController`. SwiftUI's `ShareLink`
/// is fine for text/URLs, but image sharing from arbitrary callsites
/// is more reliable through the activity controller — it correctly
/// previews the image and supports Messages/Mail/Instagram/etc.
private struct ActivityViewSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
