import SwiftUI

/// Detail view for a single Polaroid — presented full-screen when
/// the user taps a card in the gallery stack. Layout:
///   • Top: chrome (back, share, delete)
///   • Middle: the Polaroid at large size, pinch-to-zoom, with an
///     Ink / Original toggle underneath (the user's photo is theirs
///     — the AI's overlay never replaces it)
///   • The day's quip, then the user's note (tap to edit)
///
/// The note editor opens as a sheet over this view so the user
/// can see the Polaroid above their typing — the "writing on the
/// back of a print" metaphor continues without losing the picture.
struct JournalEntryDetailView: View {
    let entry: JournalEntry
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var showNoteEditor = false
    @State private var showOriginal = false
    @State private var shareImage: UIImage?
    @AppStorage("polaroid_show_shape_caption") private var showShapeCaption = true

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 10)
                polaroid
                    .padding(.horizontal, 36)
                if hasDevelopedVersion {
                    inkToggle
                        .padding(.top, 14)
                }
                if !entry.quip.isEmpty {
                    quipLine
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }
                Spacer(minLength: 10)
                noteRow
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorSheet(entry: entry)
        }
        .sheet(item: Binding(
            get: { shareImage.map { SharePayload(image: $0) } },
            set: { if $0 == nil { shareImage = nil } }
        )) { payload in
            ActivityViewSheet(items: [payload.image])
        }
    }

    // MARK: - Sections

    private var polaroid: some View {
        ZoomableView(onSingleTap: { showNoteEditor = true }) {
            PolaroidCard(
                entry: entry,
                showShapeCaption: showShapeCaption,
                tilt: 0,
                showOriginal: showOriginal
            )
        }
    }

    private var hasDevelopedVersion: Bool {
        entry.developedImageData != nil
    }

    /// Ink / Original segmented chip. Only shown when there IS a
    /// developed version to toggle away from.
    private var inkToggle: some View {
        HStack(spacing: 0) {
            toggleSegment(title: "Ink", isActive: !showOriginal) {
                withAnimation(.easeInOut(duration: 0.2)) { showOriginal = false }
            }
            toggleSegment(title: "Original", isActive: showOriginal) {
                withAnimation(.easeInOut(duration: 0.2)) { showOriginal = true }
            }
        }
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Photo version")
    }

    private func toggleSegment(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 12, weight: .semibold, design: .monospaced)
                .tracking(0.5)
                .foregroundStyle(isActive ? .black : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isActive ? CV.Color.accent : .clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// The day's weather-aware quip — readable for every past entry,
    /// not just today's (the drawer peek only carries today's).
    private var quipLine: some View {
        Text(entry.quip)
            .scaledFont(size: 14, weight: .regular, design: .serif)
            .italic()
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Note preview / call-to-action. If the entry has a note, show
    /// it inline (a tap opens the editor); otherwise show a prompt.
    @ViewBuilder
    private var noteRow: some View {
        Button {
            showNoteEditor = true
        } label: {
            if let note = entry.note, !note.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note)
                        .scaledFont(size: 14, weight: .regular, design: .serif)
                        .italic()
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                    Text("Tap to edit")
                        .scaledFont(size: 10, weight: .regular, design: .monospaced)
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
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .scaledFont(size: 14)
                    Text("Write a note about today")
                        .scaledFont(size: 13, weight: .medium, design: .serif)
                        .italic()
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule().fill(.white.opacity(0.10))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share

    /// Shares whatever's currently displayed:
    ///   • Ink view → the rendered Polaroid card (printable artifact)
    ///   • Original view → the raw photo at full capture resolution,
    ///     no frame, no ink — the user's own photograph back.
    @MainActor
    private func share() {
        if showOriginal {
            if let img = UIImage(data: entry.originalImageData) {
                shareImage = img
            }
            return
        }
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

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            chromeButton(systemName: "chevron.left", label: "Back") {
                dismiss()
            }
            Spacer()
            Text(formattedDate)
                .scaledFont(size: 11, weight: .semibold, design: .monospaced)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            HStack(spacing: 8) {
                chromeButton(systemName: "square.and.arrow.up", label: "Share") {
                    share()
                }
                chromeButton(systemName: "trash", label: "Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    private func chromeButton(
        systemName: String,
        label: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.07, blue: 0.09),
                     Color(red: 0.04, green: 0.02, blue: 0.03)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: entry.createdAt).uppercased()
    }
}
