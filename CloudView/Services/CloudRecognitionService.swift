import Foundation

/// Returns 5 alternative interpretations of a cloud cluster. The caller
/// picks one at random to render, preserving the "5 viewers, 5 different
/// answers" property called out in docs/RECOGNITION.md.
///
/// Today: a fully on-device implementation backed by Apple's MobileCLIP
/// image encoder + pre-computed text embeddings for the kid-safe
/// allowlist. $0 per call, no network, no vendor dependency.
///
/// When the MobileCLIP model isn't shipped in the bundle (e.g. fresh
/// clone, before docs/CLIP_SETUP.md is followed), the service silently
/// falls back to deterministic stub picks so the app still runs end to
/// end for development.
protocol CloudRecognitionService {
    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation]
}

/// Production recognition service. Lazily initializes CLIP + the label
/// matcher; if either is unavailable, hands the call off to the stub so
/// the app never crashes on a missing asset.
final class OnDeviceCloudRecognitionService: CloudRecognitionService {
    static let shared = OnDeviceCloudRecognitionService()

    private let encoder: CLIPImageEncoder?
    private let matcher: LabelEmbeddingMatcher?
    private let fallback = StubCloudRecognitionService()

    init() {
        self.encoder = CLIPImageEncoder()
        self.matcher = LabelEmbeddingMatcher()
        if encoder == nil || matcher == nil {
            print("⚠️  OnDeviceCloudRecognitionService: using stub fallback. " +
                  "Recognition will return placeholder picks until the MobileCLIP " +
                  "model and label embeddings are added — see docs/CLIP_SETUP.md.")
        }
    }

    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation] {
        guard let encoder = encoder, let matcher = matcher else {
            return try await fallback.recognize(cluster)
        }
        guard let pixelBuffer = CloudSilhouetteRenderer.render(cluster) else {
            return try await fallback.recognize(cluster)
        }
        let embedding = try await encoder.encode(pixelBuffer)
        let picks = matcher.match(imageEmbedding: embedding)
        // Matcher returns [] when the top match is below the confidence
        // floor (genuinely no good match). Caller renders the "Cool cloud!"
        // default state in that case.
        return picks
    }
}

/// Fallback returned when the CLIP model isn't present. Returns 5 canned
/// interpretations seeded deterministically by the cluster's signature.
/// Lives in this file so the recognition pipeline is self-contained and
/// the rest of the app sees one type.
final class StubCloudRecognitionService: CloudRecognitionService {
    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation] {
        let bank: [(String, Double)] = [
            ("turtle", 0.55), ("dragon", 0.55), ("rabbit", 0.55),
            ("cat", 0.55), ("whale", 0.55), ("dolphin", 0.55),
            ("rocket", 0.55), ("castle", 0.55), ("dog", 0.55),
            ("penguin", 0.55), ("unicorn", 0.55), ("bear", 0.55),
        ]

        let hash = abs(cluster.signature.cacheKey.hashValue)
        var picks: [(String, Double)] = []
        var i = hash
        for _ in 0..<5 {
            picks.append(bank[i % bank.count])
            i /= bank.count + 1
            if i == 0 { i = hash &* 31 + 7 }
        }

        return picks.map { label, conf in
            Interpretation(label: label, confidence: conf, annotations: [])
        }
    }
}
