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

    /// Most recent entry created today (local time), or nil if none.
    /// Drives the "today's Polaroid is the home view" routing — the
    /// app shows the camera when this is nil and TodaysPolaroidView
    /// when it isn't.
    var todaysEntry: JournalEntry? {
        let cal = Calendar.current
        return entries.first(where: { cal.isDateInToday($0.createdAt) })
    }

    /// The user's most recent shape names, newest first. Sent to the
    /// develop-polaroid edge function as variety pressure so the AI
    /// avoids repeating yesterday's creature when the sky plausibly
    /// allows something fresh.
    func recentShapeNames(limit: Int = 7) -> [String] {
        entries.prefix(limit).map(\.shapeName).filter { !$0.isEmpty }
    }

    /// Count of consecutive recent days (ending today or yesterday)
    /// that have at least one Polaroid. Used by the home view to
    /// quietly reward the daily ritual without becoming nagware:
    ///   • 0  → nothing shown
    ///   • 1  → "1 day" (today is fresh)
    ///   • N+ → "N-day streak"
    ///
    /// "Ending yesterday" is intentional — if the user opens the app
    /// in the morning before they've scanned, we still want their
    /// in-progress streak to be visible so they want to extend it.
    var currentStreak: Int {
        guard !entries.isEmpty else { return 0 }
        let cal = Calendar.current
        // Bucket entries by day for O(1) lookup.
        let days = Set(entries.map { cal.startOfDay(for: $0.createdAt) })

        // Anchor on the most recent day with an entry that's either
        // today or yesterday. Older-than-yesterday → streak is zero.
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let anchor: Date
        if days.contains(today) {
            anchor = today
        } else if days.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = anchor
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    // MARK: - Export

    /// Builds a .zip of the entire journal for the user to take with
    /// them: per-entry JPEGs (developed + original) named by date and
    /// shape, plus a journal.txt with every date / shape / quip /
    /// weather line / note. This is the data-permanence stopgap until
    /// cloud sync exists — the journal lives only on this device, and
    /// users with a year of daily ritual need a way out that isn't
    /// "hope the iCloud device backup works."
    ///
    /// Zipping uses the NSFileCoordinator `.forUploading` trick — the
    /// coordinator produces a zip of a folder URL without needing a
    /// compression library. Heavy work runs detached off-main.
    func exportArchive() async throws -> URL {
        await loadIfNeeded()
        let snapshot = entries.sorted { $0.createdAt < $1.createdAt }

        return try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let staging = fm.temporaryDirectory
                .appendingPathComponent("Cloudoodle Journal", isDirectory: true)
            try? fm.removeItem(at: staging)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)

            let dayFormat = DateFormatter()
            dayFormat.dateFormat = "yyyy-MM-dd"
            let prettyFormat = DateFormatter()
            prettyFormat.dateStyle = .full
            prettyFormat.timeStyle = .short

            var journalText = "Cloudoodle Journal\n==================\n"
            // Subscribers can capture the same shape twice in a day
            // ("Capture another sky") — suffix repeats so the second
            // file doesn't silently clobber the first.
            var usedBaseNames: [String: Int] = [:]
            for entry in snapshot {
                let day = dayFormat.string(from: entry.createdAt)
                // Filesystem-safe slug from the shape name.
                let slug = entry.shapeName.lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }
                    .joined(separator: "-")
                    .prefix(40)
                var base = slug.isEmpty ? day : "\(day)-\(slug)"
                let seen = (usedBaseNames[base] ?? 0) + 1
                usedBaseNames[base] = seen
                if seen > 1 { base += "-\(seen)" }

                if let dev = entry.developedImageData {
                    try? dev.write(to: staging.appendingPathComponent("\(base)-polaroid.jpg"))
                }
                try? entry.originalImageData.write(
                    to: staging.appendingPathComponent("\(base)-original.jpg"))

                journalText += "\n\(prettyFormat.string(from: entry.createdAt))\n"
                journalText += "Shape: \(entry.shapeName)\n"
                if !entry.quip.isEmpty { journalText += "Quip: \(entry.quip)\n" }
                if let t = entry.temperatureF {
                    journalText += "Weather: \(t)°F, \(entry.conditionsSummary)"
                    if let city = entry.city, !city.isEmpty { journalText += " — \(city)" }
                    journalText += "\n"
                }
                if let note = entry.note, !note.isEmpty {
                    journalText += "Note: \(note)\n"
                }
            }
            try journalText.write(
                to: staging.appendingPathComponent("journal.txt"),
                atomically: true, encoding: .utf8)

            // NSFileCoordinator's .forUploading option zips folder
            // reads transparently. The zip is only valid inside the
            // accessor block, so copy it out before returning.
            var zipURL: URL?
            var coordinatorError: NSError?
            NSFileCoordinator().coordinate(
                readingItemAt: staging,
                options: .forUploading,
                error: &coordinatorError
            ) { tempZip in
                let dest = fm.temporaryDirectory
                    .appendingPathComponent("Cloudoodle-Journal-\(dayFormat.string(from: Date())).zip")
                try? fm.removeItem(at: dest)
                if (try? fm.copyItem(at: tempZip, to: dest)) != nil {
                    zipURL = dest
                }
            }
            try? fm.removeItem(at: staging)

            if let error = coordinatorError { throw error }
            guard let zip = zipURL else {
                throw CocoaError(.fileWriteUnknown)
            }
            return zip
        }.value
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
