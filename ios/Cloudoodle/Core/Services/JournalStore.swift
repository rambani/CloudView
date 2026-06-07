import Foundation
import Observation

/// Local persistence for the user's cloud journal. Writes a single
/// `journal.json` to the app's Documents directory and watches the
/// entries array via @Observable so the gallery UI stays in sync.
///
/// File-based storage rather than UserDefaults — entries can get
/// big (developed PNGs are ~1 MB each base64'd) and UserDefaults
/// has a soft limit that those would blow past. Documents is the
/// right place for user-owned content that persists across app
/// updates and is included in iCloud Backup by default.
@Observable
@MainActor
final class JournalStore {
    static let shared = JournalStore()

    private(set) var entries: [JournalEntry] = []
    private(set) var hasLoaded = false

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent("journal.json")
    }

    private init() {}

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Read the JSON store and replace `entries`. Resilient to a
    /// missing or malformed file — first-run users have nothing yet,
    /// and a corrupt file shouldn't lock them out of journaling
    /// going forward (we just start over).
    func load() async {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            entries = []
            hasLoaded = true
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([JournalEntry].self, from: data)
            entries = decoded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            // Corrupt file → start fresh but keep the original on
            // disk renamed for forensics so we don't silently lose
            // a user's history.
            let backup = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: url, to: backup)
            entries = []
        }
        hasLoaded = true
    }

    /// Append a new entry and persist. Most recent first.
    @discardableResult
    func add(_ entry: JournalEntry) async -> JournalEntry {
        await loadIfNeeded()
        entries.insert(entry, at: 0)
        await persist()
        return entry
    }

    /// Update the note on an existing entry. Truncates to the
    /// character cap so callers can pass user input directly.
    func updateNote(_ note: String, on entryId: UUID) async {
        await loadIfNeeded()
        guard let idx = entries.firstIndex(where: { $0.id == entryId }) else { return }
        let clamped = String(note.prefix(JournalEntry.noteCharacterLimit))
        entries[idx].note = clamped.isEmpty ? nil : clamped
        await persist()
    }

    func updateDevelopedImage(_ data: Data, on entryId: UUID) async {
        await loadIfNeeded()
        guard let idx = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[idx].developedImageData = data
        await persist()
    }

    func delete(_ entryId: UUID) async {
        await loadIfNeeded()
        entries.removeAll { $0.id == entryId }
        await persist()
    }

    /// Write `entries` back to disk. Off-main since JSON encoding
    /// + file write is non-trivial for entries that carry images.
    private func persist() async {
        let snapshot = entries
        let url = fileURL
        await Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(snapshot)
                // Write to a temp file then atomically replace so a
                // mid-write crash never leaves an empty journal.json.
                let tmp = url.appendingPathExtension("tmp")
                try data.write(to: tmp, options: .atomic)
                if FileManager.default.fileExists(atPath: url.path) {
                    _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
                } else {
                    try FileManager.default.moveItem(at: tmp, to: url)
                }
            } catch {
                // Best-effort — failing to persist shouldn't crash
                // the app; the next save will retry.
            }
        }.value
    }
}
