import Foundation
import MetricKit

/// Subscribes to Apple's MetricKit and persists daily metric + diagnostic
/// payloads to the app's Application Support directory. This is the
/// vendor-free crash / hang / energy reporting path: no SDK, no account,
/// no per-user cost, no data leaving the device.
///
/// What MetricKit delivers (once per day, roughly 24h after install):
/// - **MXMetricPayload**: app launch time, peak memory, energy usage,
///   network bytes, location-activity time, etc.
/// - **MXDiagnosticPayload**: crash logs, hang reports, disk-write
///   exception reports, app-launch hangs.
///
/// We persist each payload as a timestamped JSON file under
/// `Library/Application Support/Cloudoodle/diagnostics/`. The most
/// recent 30 days are kept; older are pruned. Support can retrieve
/// them via the Files app on the user's device when triaging an issue.
///
/// For kids' app privacy posture, payloads stay strictly local. A
/// future opt-in backend upload would require explicit parental
/// consent — not in scope for v1.
final class DiagnosticsService: NSObject, MXMetricManagerSubscriber {
    static let shared = DiagnosticsService()

    private let folderName = "diagnostics"
    private let retentionDays = 30
    private let fileManager = FileManager.default

    private override init() { super.init() }

    /// Call from app launch (AppDelegate or @main App init). Registers
    /// this object as the singleton MetricKit subscriber. Calling more
    /// than once is harmless.
    func start() {
        MXMetricManager.shared.add(self)
        pruneOldPayloads()
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            persist(payload.jsonRepresentation(), kind: "metrics", date: payload.timeStampBegin)
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            persist(payload.jsonRepresentation(), kind: "diagnostics", date: payload.timeStampBegin)
        }
    }

    // MARK: - Persistence

    private func persist(_ data: Data, kind: String, date: Date) {
        guard let folder = diagnosticsFolder() else { return }
        let ts = ISO8601DateFormatter().string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("\(ts)-\(kind).json")
        do {
            try data.write(to: url, options: .atomic)
            print("📊 Wrote \(kind) payload to \(url.lastPathComponent)")
        } catch {
            print("⚠️  Failed to write \(kind) payload: \(error.localizedDescription)")
        }
    }

    private func pruneOldPayloads() {
        guard let folder = diagnosticsFolder() else { return }
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 24 * 3600)

        guard let entries = try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        for entry in entries {
            guard let mod = try? entry.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate,
                  mod < cutoff else { continue }
            try? fileManager.removeItem(at: entry)
        }
    }

    private func diagnosticsFolder() -> URL? {
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        let folder = appSupport.appendingPathComponent(folderName, isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }
}
