import Foundation
import CoreGraphics

/// Translation/rotation/scale/reflection-invariant signature for a closed
/// contour, suitable for use as a cache key in the recognition service.
///
/// Uses the seven Hu invariant moments. Each moment is bucketed by
/// log-magnitude into 8 bins; the concatenated bin IDs form the cache key.
/// Approximate matches between slightly-different shapes (e.g. the same
/// cloud scanned a few seconds apart from a different angle) resolve to
/// the same key by construction, which is the cache-hit story in
/// docs/RECOGNITION.md.
struct CloudShapeSignature: Hashable, Codable {
    let huMoments: [Double]

    /// Discrete cache key. Similar shapes hash to the same key.
    let cacheKey: String

    init(contour: [CGPoint]) {
        let moments = Self.huMoments(of: contour)
        self.huMoments = moments
        self.cacheKey = Self.bucket(moments)
    }

    // MARK: - Implementation

    /// Compute Hu's seven invariant moments from a closed contour.
    ///
    /// We treat the contour as a uniformly-sampled polygon and compute
    /// raw moments by summation. For a real raster shape you'd integrate
    /// over pixels; for our purposes (a few hundred contour points) this
    /// is accurate enough and far cheaper.
    static func huMoments(of contour: [CGPoint]) -> [Double] {
        guard contour.count >= 3 else { return Array(repeating: 0, count: 7) }

        // Centroid
        var sumX: Double = 0, sumY: Double = 0
        for p in contour { sumX += Double(p.x); sumY += Double(p.y) }
        let n = Double(contour.count)
        let cx = sumX / n
        let cy = sumY / n

        // Central moments μ_pq up to order 3
        func mu(_ p: Int, _ q: Int) -> Double {
            var acc: Double = 0
            for point in contour {
                let dx = Double(point.x) - cx
                let dy = Double(point.y) - cy
                acc += pow(dx, Double(p)) * pow(dy, Double(q))
            }
            return acc
        }

        let mu00 = max(mu(0, 0), 1e-12)
        // Normalize: η_pq = μ_pq / μ00^((p+q)/2 + 1)
        func eta(_ p: Int, _ q: Int) -> Double {
            mu(p, q) / pow(mu00, Double(p + q) / 2.0 + 1.0)
        }

        let n20 = eta(2, 0), n02 = eta(0, 2), n11 = eta(1, 1)
        let n30 = eta(3, 0), n12 = eta(1, 2), n21 = eta(2, 1), n03 = eta(0, 3)

        // Seven Hu invariants
        let h1 = n20 + n02
        let h2 = pow(n20 - n02, 2) + 4 * pow(n11, 2)
        let h3 = pow(n30 - 3 * n12, 2) + pow(3 * n21 - n03, 2)
        let h4 = pow(n30 + n12, 2) + pow(n21 + n03, 2)
        let h5 = (n30 - 3 * n12) * (n30 + n12) *
                 (pow(n30 + n12, 2) - 3 * pow(n21 + n03, 2)) +
                 (3 * n21 - n03) * (n21 + n03) *
                 (3 * pow(n30 + n12, 2) - pow(n21 + n03, 2))
        let h6 = (n20 - n02) * (pow(n30 + n12, 2) - pow(n21 + n03, 2)) +
                 4 * n11 * (n30 + n12) * (n21 + n03)
        let h7 = (3 * n21 - n03) * (n30 + n12) *
                 (pow(n30 + n12, 2) - 3 * pow(n21 + n03, 2)) -
                 (n30 - 3 * n12) * (n21 + n03) *
                 (3 * pow(n30 + n12, 2) - pow(n21 + n03, 2))

        return [h1, h2, h3, h4, h5, h6, h7]
    }

    /// Bucket Hu moments into discrete bins by log magnitude. Hu values
    /// commonly span ~10 orders of magnitude, so linear bucketing would
    /// collapse most shapes to one bin.
    static func bucket(_ moments: [Double], bucketsPerDecade: Int = 4) -> String {
        moments.map { value in
            guard value.isFinite, value != 0 else { return "0" }
            let mag = log10(abs(value))
            let bucket = Int(round(mag * Double(bucketsPerDecade)))
            let sign = value < 0 ? "-" : ""
            return "\(sign)\(bucket)"
        }.joined(separator: ":")
    }
}
