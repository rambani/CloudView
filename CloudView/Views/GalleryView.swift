import SwiftUI

/// Grid of saved cloud drawings. Reached from Settings → "My drawings".
/// Tap a thumbnail to see it full-screen with share + delete actions.
struct GalleryView: View {
    @ObservedObject private var archive = DrawingArchiveService.shared
    @State private var selected: ArchivedDrawing?

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 12)
    ]

    var body: some View {
        Group {
            if archive.drawings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(archive.drawings) { drawing in
                            Button {
                                selected = drawing
                            } label: {
                                ThumbnailCell(drawing: drawing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("My drawings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selected) { drawing in
            DrawingDetailView(drawing: drawing)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No drawings yet")
                .font(.headline)
            Text("Drawings you make get saved here. Point at clouds to start.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Thumbnail cell

private struct ThumbnailCell: View {
    let drawing: ArchivedDrawing
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color(.secondarySystemBackground)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(drawing.label)
                .font(.caption)
                .lineLimit(1)
            Text(drawing.createdAt, format: .dateTime.month().day())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .task { loadImage() }
        .accessibilityElement()
        .accessibilityLabel("\(drawing.label), \(drawing.createdAt.formatted(.dateTime))")
        .accessibilityHint("Open to share or delete")
    }

    private func loadImage() {
        guard image == nil,
              let url = DrawingArchiveService.shared.url(for: drawing),
              let loaded = UIImage(contentsOfFile: url.path) else { return }
        image = loaded
    }
}

// MARK: - Detail / share / delete

private struct DrawingDetailView: View {
    let drawing: ArchivedDrawing
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Drawing of \(drawing.label)")
                } else {
                    Color(.secondarySystemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text(drawing.label)
                    .font(.title2)
                    .bold()
                Text(drawing.createdAt, format: .dateTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let url = DrawingArchiveService.shared.url(for: drawing) {
                    ShareLink(item: url, subject: Text("Look what I saw in the clouds!")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: closeToolbar)
            .alert("Delete this drawing?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    DrawingArchiveService.shared.delete(drawing)
                    dismiss()
                }
            } message: {
                Text("This can't be undone.")
            }
            .task { loadImage() }
        }
    }

    @ToolbarContentBuilder
    private func closeToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }

    private func loadImage() {
        guard image == nil,
              let url = DrawingArchiveService.shared.url(for: drawing),
              let loaded = UIImage(contentsOfFile: url.path) else { return }
        image = loaded
    }
}
