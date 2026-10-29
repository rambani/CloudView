import Foundation
import Accelerate

/// Loads the pre-computed text embeddings for the kid-safe labels and
/// matches an image embedding against them via cosine similarity. Returns
/// up to 5 labels per call, weighted-random sampled from the top-K matches
/// so different scans of the same cloud yield different picks — the "5
/// viewers, 5 different things" property in docs/RECOGNITION.md.
///
/// `LabelEmbeddings.json` is generated offline by
/// `tools/generate_label_embeddings.py` from the same model family as the
/// on-device image encoder. It carries a `_meta` entry with the model name,
/// dimension and a calibrated confidence floor, so swapping models never
/// means editing Swift.
final class LabelEmbeddingMatcher {
    struct Meta: Decodable {
        let model: String?
        let dimension: Int?
        /// Cosine similarity below which the top match is "no good match"
        /// and the caller shows "Cool cloud!".
        let confidenceFloor: Float?
        /// Softmax temperature for the sampling.
        let temperature: Float?
    }

    private let embeddings: [(label: String, vector: [Float])]
    let dimension: Int
    let confidenceFloor: Float
    let modelName: String

    private let topK = 15
    private let returnCount = 5
    private let temperature: Float

    private static let defaultFloor: Float = 0.18
    private static let defaultTemperature: Float = 0.07

    /// Test seam.
    init(embeddings: [String: [Float]], confidenceFloor: Float = LabelEmbeddingMatcher.defaultFloor,
         temperature: Float = LabelEmbeddingMatcher.defaultTemperature, modelName: String = "test") {
        self.embeddings = embeddings.map { (label: $0.key, vector: $0.value) }.sorted { $0.label < $1.label }
        self.dimension = embeddings.values.first?.count ?? 0
        self.confidenceFloor = confidenceFloor
        self.temperature = temperature
        self.modelName = modelName
    }

    convenience init?() {
        guard let url = Bundle.main.url(forResource: "LabelEmbeddings", withExtension: "json") else {
            print("ℹ️  LabelEmbeddings.json not in bundle — recognition off. See docs/CLIP_SETUP.md.")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            var meta = Meta(model: nil, dimension: nil, confidenceFloor: nil, temperature: nil)
            if let m = raw["_meta"], let md = try? JSONSerialization.data(withJSONObject: m) {
                meta = (try? JSONDecoder().decode(Meta.self, from: md)) ?? meta
            }
            var vectors: [String: [Float]] = [:]
            for (key, value) in raw where key != "_meta" {
                guard let nums = value as? [NSNumber] else { continue }
                vectors[key] = nums.map { $0.floatValue }
            }
            guard let firstDim = vectors.values.first?.count, firstDim > 0 else {
                print("⚠️  LabelEmbeddings.json is empty.")
                return nil
            }
            for (label, vec) in vectors where vec.count != firstDim {
                print("⚠️  Label '\(label)' has embedding dim \(vec.count); expected \(firstDim).")
                return nil
            }
            self.init(
                embeddings: vectors,
                confidenceFloor: meta.confidenceFloor ?? Self.defaultFloor,
                temperature: meta.temperature ?? Self.defaultTemperature,
                modelName: meta.model ?? "unknown"
            )
        } catch {
            print("⚠️  Failed to decode LabelEmbeddings.json: \(error.localizedDescription)")
            return nil
        }
    }

    /// Match a unit-norm image embedding against the label set. Returns up
    /// to 5 interpretations, best-weighted first, or [] when the top match
    /// is below the confidence floor.
    func match(imageEmbedding: [Float]) -> [Interpretation] {
        guard imageEmbedding.count == dimension else {
            print("⚠️  Image embedding dim \(imageEmbedding.count) != label dim \(dimension)")
            return []
        }
        var scored: [(label: String, score: Float)] = []
        scored.reserveCapacity(embeddings.count)
        for (label, vec) in embeddings {
            var score: Float = 0
            vDSP_dotpr(imageEmbedding, 1, vec, 1, &score, vDSP_Length(dimension))
            scored.append((label, score))
        }
        scored.sort { $0.score > $1.score }
        guard let best = scored.first, best.score >= confidenceFloor else { return [] }

        let picks = weightedSample(from: Array(scored.prefix(topK)), count: returnCount)
        return picks.map { entry in
            Interpretation(
                label: entry.label,
                confidence: Double(entry.score),
                annotations: AnnotationHints.hints(for: entry.label)
            )
        }
    }

    /// Deterministic ranking without sampling — for tests and diagnostics.
    func ranked(imageEmbedding: [Float]) -> [(label: String, score: Float)] {
        guard imageEmbedding.count == dimension else { return [] }
        return embeddings.map { entry in
            var score: Float = 0
            vDSP_dotpr(imageEmbedding, 1, entry.vector, 1, &score, vDSP_Length(dimension))
            return (entry.label, score)
        }.sorted { $0.score > $1.score }
    }

    private func weightedSample(
        from top: [(label: String, score: Float)],
        count: Int
    ) -> [(label: String, score: Float)] {
        var pool = top
        var picks: [(label: String, score: Float)] = []
        picks.reserveCapacity(count)
        while picks.count < count && !pool.isEmpty {
            let maxScore = pool.map(\.score).max() ?? 0
            let weights = pool.map { exp(($0.score - maxScore) / temperature) }
            let total = weights.reduce(0, +)
            guard total > 0 else { break }
            let target = Float.random(in: 0..<total)
            var cumulative: Float = 0
            var pickedIdx = pool.count - 1
            for (i, w) in weights.enumerated() {
                cumulative += w
                if cumulative >= target { pickedIdx = i; break }
            }
            picks.append(pool[pickedIdx])
            pool.remove(at: pickedIdx)
        }
        return picks
    }
}
