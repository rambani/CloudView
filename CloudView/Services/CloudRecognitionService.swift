import Foundation
import CoreVideo

/// "What does this cloud look like?" — up to 5 alternative answers, best
/// weighted first. The caller renders the first and keeps the "5 viewers,
/// 5 different answers" property from docs/RECOGNITION.md.
///
/// Fully on-device: a permissively licensed contrastive image encoder
/// (SigLIP 2 / CLIP, see docs/CLIP_SETUP.md) + pre-computed text
/// embeddings for the kid-safe labels. $0 per call, no network.
///
/// When the model isn't present, recognition is simply off — `[]` — and
/// the shape-template path carries on alone. There is no fake fallback.
protocol CloudRecognitionService {
    /// `crop` is the real photo of the cloud (224×224, upright). Preferred;
    /// the silhouette is used only when no crop is available.
    func recognize(_ cluster: CloudCluster, crop: CVPixelBuffer?) async throws -> [Interpretation]
}

extension CloudRecognitionService {
    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation] {
        try await recognize(cluster, crop: nil)
    }
}

/// Production recognition service. The encoder may arrive late (On-Demand
/// Resource download); until then calls return `[]`.
final class OnDeviceCloudRecognitionService: CloudRecognitionService {
    static let shared = OnDeviceCloudRecognitionService()

    private var encoder: ImageEmbeddingEncoder?
    private let matcher: LabelEmbeddingMatcher?
    private var loading = false

    /// True once the model + embeddings are loaded and recognition runs.
    var isAvailable: Bool { encoder != nil && matcher != nil }

    init() {
        self.matcher = LabelEmbeddingMatcher()
        self.encoder = ImageEmbeddingEncoder()
        if matcher == nil {
            print("ℹ️  Recognition: no label embeddings bundled; shape matching only.")
        } else if encoder == nil {
            print("ℹ️  Recognition: model not in bundle; will try On-Demand Resources on first use.")
        }
    }

    /// Kick off the On-Demand Resource download (idempotent). Safe to call
    /// at launch so the first cloud doesn't wait on it.
    func prepare() {
        guard encoder == nil, matcher != nil, !loading else { return }
        loading = true
        Task {
            let loaded = await ImageEmbeddingEncoder.load()
            await MainActor.run {
                self.encoder = loaded
                self.loading = false
                if let loaded = loaded, let matcher = self.matcher, loaded.dimension != 0, loaded.dimension != matcher.dimension {
                    print("⚠️  Recognition model dim \(loaded.dimension) != label embeddings dim \(matcher.dimension) " +
                          "(\(matcher.modelName)). Regenerate LabelEmbeddings.json for this model.")
                    self.encoder = nil
                }
            }
        }
    }

    func recognize(_ cluster: CloudCluster, crop: CVPixelBuffer?) async throws -> [Interpretation] {
        guard let encoder = encoder, let matcher = matcher else {
            prepare()
            return []
        }
        guard let input = crop ?? CloudSilhouetteRenderer.render(cluster) else { return [] }
        let embedding = try await encoder.encode(input)
        return matcher.match(imageEmbedding: embedding)
    }
}

/// Test double: 5 canned interpretations seeded deterministically by the
/// cluster's signature. Never used by the shipping pipeline.
final class StubCloudRecognitionService: CloudRecognitionService {
    func recognize(_ cluster: CloudCluster, crop: CVPixelBuffer?) async throws -> [Interpretation] {
        let bank: [(String, Double)] = [
            ("turtle", 0.55), ("dragon", 0.55), ("rabbit", 0.55),
            ("cat", 0.55), ("whale", 0.55), ("dolphin", 0.55),
            ("rocket", 0.55), ("castle", 0.55), ("dog", 0.55),
            ("penguin", 0.55), ("unicorn", 0.55), ("bear", 0.55),
        ]
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
