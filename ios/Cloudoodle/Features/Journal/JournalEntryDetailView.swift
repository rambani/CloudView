import SwiftUI

/// Detail view for a single Polaroid — presented full-screen when
/// the user taps a card in the gallery stack. Layout:
///   • Top: chrome (back, share, delete)
///   • Middle: the Polaroid at large size, pinch-to-zoom
///   • Bottom: the user's note (read in italic if set; tap to edit)
///
/// The note editor opens as a sheet over this view so the user
/// can see the Polaroid above their typing — the "writing on the
/// back of a print" metaphor continues without losing the picture.
struct JournalEntryDetailView: View {
    let entry: JournalEntry
    var onShare: () -> Void = {}
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var showNoteEditor = false
    @AppStorage("polaroid_show_shape_caption") private var showShapeCaption = true

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 12)
                polaroid
                    .padding(.horizontal, 36)
                Spacer(minLength: 12)
                noteRow
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorSheet(entry: entry)
        }
    }

    // MARK: - Sections

    private var polaroid: some View {
        ZoomableView(onSingleTap: { showNoteEditor = true }) {
            PolaroidCard(
                entry: entry,
                showShapeCaption: showShapeCaption,
                tilt: 0
            )
        }
    }

    /// Note preview / call-to-action. If the entry has a note, show
    /// it inline (a tap opens the editor); otherwise show a prompt.
    /// Either way the Polaroid above remains visible.
    @ViewBuilder
    private var noteRow: some View {
        Button {
            showNoteEditor = true
        } label: {
            if let note = entry.note, !note.isEmpty {
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
            } else {
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
                .frame(maxWidth: .infinity)
                .background(
                    Capsule().fill(.white.opacity(0.10))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            chromeButton(systemName: "chevron.left", label: "Back") {
                dismiss()
            }
            Spacer()
            Text(formattedDate)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            HStack(spacing: 8) {
                chromeButton(systemName: "square.and.arrow.up", label: "Share") {
                    onShare()
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
                .font(.system(size: 14, weight: .semibold))
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
