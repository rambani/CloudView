import Foundation

/// One saved cloud drawing in the user's local gallery. Today the
/// `image` lives as a HEIC file under Application Support and we keep
/// only the URL in the index — keeps the index file small enough to
/// load synchronously, while images stream in from disk as the
/// gallery scrolls.
///
/// Identified by the file's URL stem (UUID). Sortable by `createdAt`
/// so the gallery shows newest-first.
struct ArchivedDrawing: Identifiable, Codable, Equatable {
    let id: UUID
    let label: String
    let createdAt: Date
    /// Relative path under Application Support. The full URL is built
    /// at read time from `DrawingArchiveService.imagesFolder()` so the
    /// index survives app reinstalls with stable iCloud restore.
    let imageRelativePath: String
}
