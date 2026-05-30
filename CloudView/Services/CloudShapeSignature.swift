import Foundation
import CoreGraphics

/// Translation/rotation/scale/reflection-invariant signature for a closed
/// contour, suitable as a cache key in the recognition service.
///
/// Uses **Hu's seven invariant moments** computed from polygon moments
/// (Green's theorem over the polygon's interior — not by summing over
/// discrete contour points, which is a common mistake that breaks scale
/// invariance because μ₀₀ would equal the point count instead of the
/// polygon's area).
///
/// Each Hu invariant is then bucketed by log magnitude into discrete bins;
/// the concatenated bin IDs form the cache key. Approximate matches between
/// slightly-different shapes (the same cloud scanned a few seconds apart
/// from a different angle) resolve to the same key by construction.
struct CloudShapeSignature: Hashable, Codable {
    /// The seven Hu invariants, in order h₁..h₇.
    let huMoments: [Double]

    /// Discrete cache key. Similar shapes hash to the same key.
    let cacheKey: String

    init(contour: [CGPoint]) {
        let moments = Self.huMoments(of: contour)
        self.huMoments = moments
        self.cacheKey = Self.bucket(moments)
    }

    // MARK: - Hu moments via Green's theorem polygon moments

    static func huMoments(of contour: [CGPoint]) -> [Double] {
        guard contour.count >= 3 else { return Array(repeating: 0, count: 7) }

        // Pre-center to a rough estimate of the centroid. Without this,
        // a shape translated far from the origin (e.g., a cloud silhouette
        // in pixel coordinates) computes raw moments that span many
        // orders of magnitude, and the central-moment subtractions lose
        // all precision to catastrophic cancellation. After this pass,
        // every m_pq is on the same scale as the polygon itself, and
        // the central moments come out correctly translation-invariant.
        let n = Double(contour.count)
        let vx = contour.reduce(0.0) { $0 + Double($1.x) } / n
        let vy = contour.reduce(0.0) { $0 + Double($1.y) } / n
        let centered: [CGPoint] = contour.map {
            CGPoint(x: Double($0.x) - vx, y: Double($0.y) - vy)
        }

        let raw = polygonRawMoments(centered)
        // Degenerate shape (zero area) → return zero signature, don't crash.
        guard abs(raw.m00) > 1e-12 else { return Array(repeating: 0, count: 7) }

        let cx = raw.m10 / raw.m00
        let cy = raw.m01 / raw.m00

        // Central moments μ_pq, derived from raw moments via the
        // standard translation formulas. μ₀₀ = m₀₀, μ₁₀ = μ₀₁ = 0.
        let mu00 = raw.m00
        let mu20 = raw.m20 - cx * raw.m10
        let mu02 = raw.m02 - cy * raw.m01
        let mu11 = raw.m11 - cx * raw.m01
        let mu30 = raw.m30 - 3 * cx * raw.m20 + 2 * cx * cx * raw.m10
        let mu03 = raw.m03 - 3 * cy * raw.m02 + 2 * cy * cy * raw.m01
        let mu21 = raw.m21 - 2 * cx * raw.m11 - cy * raw.m20 + 2 * cx * cx * raw.m01
        let mu12 = raw.m12 - 2 * cy * raw.m11 - cx * raw.m02 + 2 * cy * cy * raw.m10

        // Normalized central moments η_pq = μ_pq / μ₀₀^((p+q)/2 + 1).
        // Scale-invariance comes from this normalization.
        func eta(_ mu: Double, p: Int, q: Int) -> Double {
            mu / pow(abs(mu00), Double(p + q) / 2.0 + 1.0)
        }
        let n20 = eta(mu20, p: 2, q: 0)
        let n02 = eta(mu02, p: 0, q: 2)
        let n11 = eta(mu11, p: 1, q: 1)
        let n30 = eta(mu30, p: 3, q: 0)
        let n03 = eta(mu03, p: 0, q: 3)
        let n21 = eta(mu21, p: 2, q: 1)
        let n12 = eta(mu12, p: 1, q: 2)

        // Seven Hu invariants. h₁..h₆ are invariant under rotation;
        // h₇ flips sign under reflection (we take its absolute value so
        // the signature also collapses mirror images, which is what we
        // want for cache lookup of a cloud seen from either side).
        let h1 = n20 + n02
        let h2 = pow(n20 - n02, 2) + 4 * pow(n11, 2)
        let h3 = pow(n30 - 3 * n12, 2) + pow(3 * n21 - n03, 2)
        let h4 = pow(n30 + n12, 2) + pow(n21 + n03, 2)
        let h5 = (n30 - 3 * n12) * (n30 + n12) *
                 (pow(n30 + n12, 2) - 3 * pow(n21 + n03, 2)) +
                 (3 * n21 - n03) * (n21 + n03) *
                 (3 * pow(n30 + n12, 2) - pow(n21 + n03, 2))
        let h6 = (n20 - n02) *
                 (pow(n30 + n12, 2) - pow(n21 + n03, 2)) +
                 4 * n11 * (n30 + n12) * (n21 + n03)
        let h7raw = (3 * n21 - n03) * (n30 + n12) *
                    (pow(n30 + n12, 2) - 3 * pow(n21 + n03, 2)) -
                    (n30 - 3 * n12) * (n21 + n03) *
                    (3 * pow(n30 + n12, 2) - pow(n21 + n03, 2))
        let h7 = abs(h7raw)

        return [h1, h2, h3, h4, h5, h6, h7]
    }

    /// Raw polygon moments via Green's theorem closed forms. For a polygon
    /// with vertices closed (vᵢ → vᵢ₊₁ wrapping at the end), each moment
    /// is a sum of edge contributions weighted by the signed cross product
    /// (xᵢ·yᵢ₊₁ − xᵢ₊₁·yᵢ).
    private struct RawMoments {
        let m00, m10, m01, m20, m02, m11, m30, m03, m21, m12: Double
    }

    private static func polygonRawMoments(_ pts: [CGPoint]) -> RawMoments {
        var m00 = 0.0, m10 = 0.0, m01 = 0.0
        var m20 = 0.0, m02 = 0.0, m11 = 0.0
        var m30 = 0.0, m03 = 0.0, m21 = 0.0, m12 = 0.0

        let n = pts.count
        for i in 0..<n {
            let p0 = pts[i]
            let p1 = pts[(i + 1) % n]
            let xi = Double(p0.x), yi = Double(p0.y)
            let xj = Double(p1.x), yj = Double(p1.y)

            // Signed twice-area of the triangle (origin, pᵢ, pᵢ₊₁).
            let cross = xi * yj - xj * yi

            // Closed-form polynomial weights from Green's theorem.
            m00 += cross
            m10 += (xi + xj) * cross
            m01 += (yi + yj) * cross
            m20 += (xi * xi + xi * xj + xj * xj) * cross
            m02 += (yi * yi + yi * yj + yj * yj) * cross
            m11 += (2 * xi * yi + xi * yj + xj * yi + 2 * xj * yj) * cross
            m30 += (xi * xi * xi + xi * xi * xj + xi * xj * xj + xj * xj * xj) * cross
            m03 += (yi * yi * yi + yi * yi * yj + yi * yj * yj + yj * yj * yj) * cross
            m21 += (3 * xi * xi * yi + 2 * xi * xj * yi + xj * xj * yi
                  + xi * xi * yj + 2 * xi * xj * yj + 3 * xj * xj * yj) * cross
            m12 += (3 * xi * yi * yi + 2 * xi * yi * yj + xi * yj * yj
                  + xj * yi * yi + 2 * xj * yi * yj + 3 * xj * yj * yj) * cross
        }

        // Constant divisors from the line-integral formulas.
        // m00:  ½ × sum
        // m10/m01: 1/6 × sum
        // m20/m02: 1/12 × sum
        // m11:  1/24 × sum
        // m30/m03: 1/20 × sum
        // m21/m12: 1/60 × sum
        return RawMoments(
            m00: m00 / 2.0,
            m10: m10 / 6.0,
            m01: m01 / 6.0,
            m20: m20 / 12.0,
            m02: m02 / 12.0,
            m11: m11 / 24.0,
            m30: m30 / 20.0,
            m03: m03 / 20.0,
            m21: m21 / 60.0,
            m12: m12 / 60.0
        )
    }

    /// Bucket Hu moments into discrete bins by log magnitude. Hu values
    /// commonly span ~10 orders of magnitude (h₁ ≈ 10⁻¹, h₇ ≈ 10⁻²⁰),
    /// so linear bucketing would collapse most shapes to one bin.
    static func bucket(_ moments: [Double], bucketsPerDecade: Int = 4) -> String {
        moments.map { value in
            guard value.isFinite, abs(value) > 1e-30 else { return "0" }
            let mag = log10(abs(value))
            let bucket = Int(round(mag * Double(bucketsPerDecade)))
            let sign = value < 0 ? "-" : ""
            return "\(sign)\(bucket)"
        }.joined(separator: ":")
    }
}
