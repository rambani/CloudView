import Foundation
import UIKit
import Combine

/// Local-only gallery of saved cloud drawings. Persists images to
/// Application Support as HEIC files and keeps a small JSON index of
/// metadata so the gallery view can render without scanning the
/// filesystem.
///
/// **Privacy**: stays strictly on device. No upload, no analytics on
/// what's been drawn. The user owns these images.
///
/// **Cap**: `maxDrawings = 100` with FIFO eviction. Pictures + index
/// stay bounded; older drawings get GC'd when the user passes the cap.
@MainActor
final class DrawingArchiveService: ObservableObject {
    static let shared = DrawingArchiveService()

    /// Published so SwiftUI gallery views update reactively after saves
    /// and deletes. Sorted newest-first.
    @Published private(set) var drawings: [ArchivedDrawing] = []

    private let maxDrawings = 100
    private let folderName = "drawings"
    private let indexName = "drawings-index.json"
    private let fileManager = FileManager.default

    private init() {
        load()
    }

    // MARK: - Public API

    /// Persist a drawing snapshot and its label. Returns the newly-
    /// created `ArchivedDrawing` or nil on failure (e.g. disk full).
    @discardableResult
    func save(image: UIImage, label: String) -> ArchivedDrawing? {
        guard let imagesFolder = imagesFolder(),
              let data = image.heicData(quality: 0.85) ?? image.jpegData(compressionQuality: 0.85) else {
            return nil
        }
        let id = UUID()
        let filename = "\(id.uuidString).heic"
        let url = imagesFolder.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️  DrawingArchive: failed to write \(filename): \(error.localizedDescription)")
            return nil
        }

        let drawing = ArchivedDrawing(
            id: id,
            label: label,
            createdAt: Date(),
            imageRelativePath: "\(folderName)/\(filename)"
        )
        drawings.insert(drawing, at: 0)
        enforceCap()
        save()
        return drawing
    }

    /// Delete a drawing's image + index entry.
    func delete(_ drawing: ArchivedDrawing) {
        if let url = url(for: drawing) {
            try? fileManager.removeItem(at: url)
        }
        drawings.removeAll { $0.id == drawing.id }
        save()
    }

    /// Delete every drawing. Used by Settings "Delete my data" so the
    /// erasure is comprehensive.
    func deleteAll() {
        for drawing in drawings {
            if let url = url(for: drawing) {
                try? fileManager.removeItem(at: url)
            }
        }
        drawings.removeAll()
        save()
    }

    /// Full URL of the archived image, suitable for `UIImage(contentsOfFile:)`
    /// or `ShareLink`. Returns nil if the file is missing.
    func url(for drawing: ArchivedDrawing) -> URL? {
        guard let support = appSupportFolder() else { return nil }
        let url = support.appendingPathComponent(drawing.imageRelativePath)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Index persistence

    private func enforceCap() {
        while drawings.count > maxDrawings, let oldest = drawings.last {
            if let url = url(for: oldest) {
                try? fileManager.removeItem(at: url)
            }
            drawings.removeLast()
        }
    }

    private func load() {
        guard let url = indexURL(),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ArchivedDrawing].self, from: data) else {
            return
        }
        drawings = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func save() {
        guard let url = indexURL() else { return }
        do {
            let data = try JSONEncoder().encode(drawings)
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️  DrawingArchive: failed to write index: \(error.localizedDescription)")
        }
    }

    // MARK: - Filesystem helpers

    private func appSupportFolder() -> URL? {
        try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private func imagesFolder() -> URL? {
        guard let support = appSupportFolder() else { return nil }
        let folder = support.appendingPathComponent(folderName, isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private func indexURL() -> URL? {
        appSupportFolder()?.appendingPathComponent(indexName)
    }
}

// MARK: - UIImage HEIC encoder
// Native UIImage doesn't expose HEIC encoding directly, so wrap
// ImageIO's CGImageDestination. Falls back to nil; caller substitutes
// JPEG when HEIC isn't available.

import ImageIO
import UniformTypeIdentifiers

private extension UIImage {
    func heicData(quality: CGFloat) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.heic.identifier as CFString, 1, nil
        ) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
