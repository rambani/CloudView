import Foundation
import CoreGraphics

/// DEBUG-only capture of real cloud contours for the offline retrieval
/// harness (`tools/validate_retrieval.py`). Each primary cloud the pipeline
/// acts on is appended as one JSON line — its upright, normalized contour,
/// true aspect ratio, and what (if anything) was drawn — to a file the
/// developer exports from Settings → Developer. Compiled out of Release.
enum ContourRecorder {
#if DEBUG
    private static let enabledKey = "cloudoodle.recordContours"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("cloudoodle-contours.jsonl")
    }

    static var recordCount: Int {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return 0 }
        return data.reduce(0) { $0 + ($1 == UInt8(ascii: "\n") ? 1 : 0) }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func record(contour: [CGPoint], aspectRatio: Double, label: String?) {
        guard isEnabled, contour.count >= 3 else { return }
        var entry: [String: Any] = [
            "t": ISO8601DateFormatter().string(from: Date()),
            "aspect": aspectRatio,
            "contour": contour.map { [Double($0.x), Double($0.y)] },
        ]
        entry["label"] = label ?? NSNull()
        guard let json = try? JSONSerialization.data(withJSONObject: entry),
              var line = String(data: json, encoding: .utf8) else { return }
        line.append("\n")

        let url = fileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }
#endif
}
