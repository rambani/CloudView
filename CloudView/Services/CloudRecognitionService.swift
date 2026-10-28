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
/// clone, before docs/CLIP_SETUP.md is followed), the service returns no
/// interpretations — the honest "Cool cloud!" state — rather than making
/// up a label. (`StubCloudRecognitionService` below exists for tests.)
protocol CloudRecognitionService {
    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation]
}

/// Production recognition service. Lazily initializes CLIP + the label
/// matcher; if either is unavailable, recognition is simply off and every
/// call returns `[]`, so the app never crashes on a missing asset and never
/// claims a creature it didn't see.
final class OnDeviceCloudRecognitionService: CloudRecognitionService {
    static let shared = OnDeviceCloudRecognitionService()

    private let encoder: CLIPImageEncoder?
    private let matcher: LabelEmbeddingMatcher?

    /// True when the model + embeddings are bundled and recognition runs.
    var isAvailable: Bool { encoder != nil && matcher != nil }

    init() {
        self.encoder = CLIPImageEncoder()
        self.matcher = LabelEmbeddingMatcher()
        if encoder == nil || matcher == nil {
            print("ℹ️  OnDeviceCloudRecognitionService: CLIP recognition unavailable " +
                  "(model or label embeddings not bundled — see docs/CLIP_SETUP.md). " +
                  "Clouds the template library can't match will show as \"Cool cloud!\".")
        }
    }

    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation] {
        guard let encoder = encoder, let matcher = matcher else {
            return []
        }
        guard let pixelBuffer = CloudSilhouetteRenderer.render(cluster) else {
            return []
        }
        let embedding = try await encoder.encode(pixelBuffer)
        let picks = matcher.match(imageEmbedding: embedding)
        // Matcher returns [] when the top match is below the confidence
        // floor (genuinely no good match). Caller renders the "Cool cloud!"
        // default state in that case.
        return picks
    }
}

/// Test double: 5 canned interpretations seeded deterministically by the
/// cluster's signature. Not used by the shipping pipeline — a missing model
/// means no recognition, not fake recognition.
final class StubCloudRecognitionService: CloudRecognitionService {
    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation] {
        let bank: [(String, Double)] = [
            ("turtle", 0.55), ("dragon", 0.55), ("rabbit", 0.55),
            ("cat", 0.55), ("whale", 0.55), ("dolphin", 0.55),
            ("rocket", 0.55), ("castle", 0.55), ("dog", 0.55),
            ("penguin", 0.55), ("unicorn", 0.55), ("bear", 0.55),
        ]

        // Stable hash — Swift's `hashValue` is salted per process launch.
        let hash = Int(truncatingIfNeeded: StableHash.fnv1a(cluster.signature.cacheKey) >> 1)
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
