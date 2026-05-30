import Foundation
import Accelerate

/// Loads the pre-computed text embeddings for the kid-safe allowlist and
/// matches an image embedding against them via cosine similarity. Returns
/// 5 alternative labels per call, weighted-random sampled from the top-K
/// matches so different scans of the same cloud yield different picks —
/// the "5 viewers, 5 different things" property in docs/RECOGNITION.md.
///
/// Embeddings are generated offline by `tools/generate_label_embeddings.py`
/// and shipped as `LabelEmbeddings.json` in the app bundle.
final class LabelEmbeddingMatcher {
    /// Map label string → unit-norm embedding (Float). All embeddings must
    /// have the same dimensionality; we assert this at load time.
    private let embeddings: [(label: String, vector: [Float])]
    private let dimension: Int

    /// Cosine-similarity threshold below which we treat the top match as
    /// "no good match found" and the recognition service returns the
    /// "Cool cloud!" fallback. Tuned empirically; 0.18 is around where
    /// CLIP starts giving genuinely off-topic answers for cloud silhouettes.
    private let confidenceFloor: Float = 0.18

    /// Sample 5 from the top 15 by softmax-weighted probability. Bigger K
    /// = more variety, lower per-pick quality. 15 was the sweet spot in
    /// dev — picks stay believable while still varying scan-to-scan.
    private let topK: Int = 15
    private let returnCount: Int = 5

    /// Temperature for the weighted-random sampling. Lower = more
    /// concentrated on the top match; higher = flatter / more variety.
    private let temperature: Float = 0.07

    init?() {
        guard let url = Bundle.main.url(
            forResource: "LabelEmbeddings",
            withExtension: "json"
        ) else {
            print("⚠️  LabelEmbeddings.json not found in bundle. " +
                  "CLIP recognition disabled; falling back to stub picks. " +
                  "See docs/CLIP_SETUP.md.")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode([String: [Float]].self, from: data)
            guard let firstDim = raw.values.first?.count, firstDim > 0 else {
                print("⚠️  LabelEmbeddings.json is empty.")
                return nil
            }
            // Sanity-check dimensions are consistent.
            for (label, vec) in raw {
                guard vec.count == firstDim else {
                    print("⚠️  Label '\(label)' has embedding dim \(vec.count); expected \(firstDim).")
                    return nil
                }
            }
            self.embeddings = raw.map { (label: $0.key, vector: $0.value) }
            self.dimension = firstDim
        } catch {
            print("⚠️  Failed to decode LabelEmbeddings.json: \(error.localizedDescription)")
            return nil
        }
    }

    /// Match a unit-norm image embedding against the label set. Returns 5
    /// interpretations, or fewer if the top match is below the confidence
    /// floor.
    func match(imageEmbedding: [Float]) -> [Interpretation] {
        guard imageEmbedding.count == dimension else {
            print("⚠️  Image embedding dim \(imageEmbedding.count) != label dim \(dimension)")
            return []
        }

        // Cosine similarity reduces to dot product because every vector is
        // L2-normalized at load/encode time.
        var scored: [(label: String, score: Float)] = []
        scored.reserveCapacity(embeddings.count)
        for (label, vec) in embeddings {
            var score: Float = 0
            vDSP_dotpr(imageEmbedding, 1, vec, 1, &score, vDSP_Length(dimension))
            scored.append((label, score))
        }

        scored.sort { $0.score > $1.score }
        guard let best = scored.first, best.score >= confidenceFloor else {
            return []
        }

        // Weighted-random sample 5 from top-K.
        let top = Array(scored.prefix(topK))
        let picks = weightedSample(from: top, count: returnCount)

        return picks.map { entry in
            Interpretation(
                label: entry.label,
                confidence: Double(entry.score),
                annotations: []  // Phase 2: annotation hints lookup
            )
        }
    }

    /// Sample `count` distinct entries from `top` with probability
    /// softmax(score / temperature). Distinct = each label appears at
    /// most once in the output.
    private func weightedSample(
        from top: [(label: String, score: Float)],
        count: Int
    ) -> [(label: String, score: Float)] {
        var pool = top
        var picks: [(label: String, score: Float)] = []
        picks.reserveCapacity(count)

        while picks.count < count && !pool.isEmpty {
            // Softmax over the current pool's scores.
            let maxScore = pool.map(\.score).max() ?? 0
            let weights = pool.map { exp(($0.score - maxScore) / temperature) }
            let total = weights.reduce(0, +)
            guard total > 0 else { break }
            let target = Float.random(in: 0..<total)
            var cumulative: Float = 0
            var pickedIdx = pool.count - 1
            for (i, w) in weights.enumerated() {
                cumulative += w
                if cumulative >= target {
                    pickedIdx = i
                    break
                }
            }
            picks.append(pool[pickedIdx])
            pool.remove(at: pickedIdx)
        }

        return picks
    }
}
