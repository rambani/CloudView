import SwiftUI

/// The user's Polaroid stack — horizontal swipe-through of past
/// developed cloud sightings, each with its caption and (optional)
/// note about the day. Reached by swiping right from the
/// PolaroidDevelopView or via a tab elsewhere in the app.
///
/// Design notes:
///   • Same darkroom-red ambient backdrop as the develop view so
///     the swipe transition feels continuous, not a context switch.
///   • Each page is one Polaroid centered with a peek of the next
///     and previous cards on either side (so the "stack" reads).
///   • Tap a card to expand into the note editor. Swipe up to
///     delete (long-press menu).
///   • Empty state explains the ritual: scan → develop → note.
struct JournalGalleryView: View {
    @State private var store = JournalStore.shared
    @State private var currentIndex: Int = 0
    @State private var editingNoteFor: UUID?
    @Environment(\.dismiss) private var dismiss

    /// When presented from PolaroidDevelopView, the entry that was
    /// just developed — gallery focuses on it on appear.
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

            // Top bar — close + title + count
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
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
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
            // Mirror the close button for visual balance
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    @ViewBuilder
    private var gallery: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(store.entries.enumerated()), id: \.element.id) { i, entry in
                page(for: entry).tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }

    private func page(for entry: JournalEntry) -> some View {
        let original = UIImage(data: entry.originalImageData)
        let developed = entry.developedImageData.flatMap(UIImage.init(data:))
        return VStack(spacing: 18) {
            Spacer()
            if let original {
                PolaroidCard(
                    original: original,
                    developed: developed,
                    caption: entry.captionLine,
                    subtitle: entry.quip,
                    tilt: tilt(forIndex: store.entries.firstIndex(where: { $0.id == entry.id }) ?? 0)
                )
                .padding(.horizontal, 36)
                .onTapGesture { editingNoteFor = entry.id }
            }
            // Note preview / call-to-action
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

    /// Note preview under each Polaroid — shows truncated note +
    /// "tap to add/edit" hint. Pressing the row opens the editor.
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

    /// Sheet that hosts the note editor. Presented modally so the
    /// gallery stays visible behind it (with a subtle dim) — this
    /// keeps the "looking through my journal" feel.
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
