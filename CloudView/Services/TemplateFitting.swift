import Foundation
import CoreGraphics

/// Geometry that drapes a `DrawingTemplate` onto a real cloud contour so the
/// creature "feels discovered in" the cloud. Two pure, testable pieces:
///
///   1. `CloudLandmarks` — reduce a contour to a handful of stable reference
///      points (centroid + the four extremes). Both the cloud and each
///      template are reduced the same way, giving a correspondence set.
///
///   2. `SimilarityTransform` — the least-squares similarity (uniform scale +
///      rotation + translation, no reflection, no shear) that best maps the
///      template's landmarks onto the cloud's. Applied to the template's
///      strokes, it lands ears at the cloud's top, a tail off its side bump,
///      and so on — because the transform sends the template's extremes to
///      the cloud's extremes.
///
/// All coordinates are normalized 0–1, top-left origin, y-down.

// MARK: - Landmarks

enum CloudLandmarks {
    /// The five reference points, in a fixed order so two landmark sets line
    /// up index-for-index as transform correspondences:
    /// `[centroid, top, bottom, left, right]`.
    ///
    /// - centroid: mean of the contour points (robust to an unclosed contour).
    /// - top/bottom/left/right: the extreme points by y (min/max) and x
    ///   (min/max). These are where a creature's silhouette naturally pushes
    ///   out — the bumps the eye reads as head, feet, tail.
    static func referencePoints(_ contour: [CGPoint]) -> [CGPoint] {
        guard !contour.isEmpty else {
            return Array(repeating: .zero, count: 5)
        }

        var sumX = 0.0, sumY = 0.0
        var top = contour[0], bottom = contour[0]
        var left = contour[0], right = contour[0]

        for p in contour {
            sumX += Double(p.x)
            sumY += Double(p.y)
            if p.y < top.y { top = p }        // smallest y = visually highest
            if p.y > bottom.y { bottom = p }
            if p.x < left.x { left = p }
            if p.x > right.x { right = p }
        }

        let n = CGFloat(contour.count)
        let centroid = CGPoint(x: CGFloat(sumX) / n, y: CGFloat(sumY) / n)
        return [centroid, top, bottom, left, right]
    }
}

// MARK: - Similarity transform

/// A 2-D similarity: `p ↦ scale · R(rotation) · p + translation`. Stored in
/// the complex-number form `w = c·z + d` (with `z = x + iy`), which makes both
/// the least-squares fit and application branch-free and free of matrix
/// inversion. `c = scale · e^{iθ}` carries scale + rotation; `d` is the
/// translation.
struct SimilarityTransform: Equatable {
    /// Real/imaginary parts of the complex multiplier `c` (scale·rotation).
    let cRe: Double
    let cIm: Double
    /// Real/imaginary parts of the complex offset `d` (translation).
    let dRe: Double
    let dIm: Double

    static let identity = SimilarityTransform(cRe: 1, cIm: 0, dRe: 0, dIm: 0)

    /// Apply the transform to a point.
    func apply(_ p: CGPoint) -> CGPoint {
        let x = Double(p.x), y = Double(p.y)
        // (cRe + i·cIm)(x + i·y) + (dRe + i·dIm)
        let rx = cRe * x - cIm * y + dRe
        let ry = cIm * x + cRe * y + dIm
        return CGPoint(x: rx, y: ry)
    }

    func apply(_ points: [CGPoint]) -> [CGPoint] { points.map(apply) }

    /// Least-squares similarity mapping `source[i] → target[i]`. Closed-form
    /// complex linear regression of `w = c·z + d`:
    ///
    ///   c = Σ conj(Δzᵢ)·Δwᵢ / Σ |Δzᵢ|²        d = w̄ − c·z̄
    ///
    /// where Δ is "minus the mean". Requires ≥ 2 non-coincident source points;
    /// returns a pure translation (and, failing that, identity-with-offset)
    /// for degenerate inputs rather than dividing by zero.
    static func fit(source: [CGPoint], target: [CGPoint]) -> SimilarityTransform {
        let n = min(source.count, target.count)
        guard n >= 1 else { return .identity }

        var zbarRe = 0.0, zbarIm = 0.0, wbarRe = 0.0, wbarIm = 0.0
        for i in 0..<n {
            zbarRe += Double(source[i].x); zbarIm += Double(source[i].y)
            wbarRe += Double(target[i].x); wbarIm += Double(target[i].y)
        }
        let nd = Double(n)
        zbarRe /= nd; zbarIm /= nd; wbarRe /= nd; wbarIm /= nd

        // numerator = Σ conj(Δz)·Δw ; denom = Σ |Δz|²
        var numRe = 0.0, numIm = 0.0, denom = 0.0
        for i in 0..<n {
            let dzRe = Double(source[i].x) - zbarRe
            let dzIm = Double(source[i].y) - zbarIm
            let dwRe = Double(target[i].x) - wbarRe
            let dwIm = Double(target[i].y) - wbarIm
            // conj(Δz)·Δw = (dzRe - i·dzIm)(dwRe + i·dwIm)
            numRe += dzRe * dwRe + dzIm * dwIm
            numIm += dzRe * dwIm - dzIm * dwRe
            denom += dzRe * dzRe + dzIm * dzIm
        }

        guard denom > 1e-12 else {
            // All source points coincide: no scale/rotation is recoverable.
            // Fall back to a pure translation of the centroid.
            return SimilarityTransform(
                cRe: 1, cIm: 0,
                dRe: wbarRe - zbarRe, dIm: wbarIm - zbarIm
            )
        }

        let cRe = numRe / denom
        let cIm = numIm / denom
        // d = w̄ − c·z̄
        let dRe = wbarRe - (cRe * zbarRe - cIm * zbarIm)
        let dIm = wbarIm - (cIm * zbarRe + cRe * zbarIm)
        return SimilarityTransform(cRe: cRe, cIm: cIm, dRe: dRe, dIm: dIm)
    }

    /// Convenience: fit directly from a template's and a cloud's contours by
    /// reducing both to landmarks first.
    static func fit(templateContour: [CGPoint], cloudContour: [CGPoint]) -> SimilarityTransform {
        fit(
            source: CloudLandmarks.referencePoints(templateContour),
            target: CloudLandmarks.referencePoints(cloudContour)
        )
    }
}

// MARK: - Point warp abstraction

/// Anything that maps a point from template space onto the cloud. Lets the
/// composer treat the closed-form `SimilarityTransform` and the richer
/// `ThinPlateSpline` interchangeably.
protocol PointWarp {
    func apply(_ p: CGPoint) -> CGPoint
}

extension PointWarp {
    func apply(_ points: [CGPoint]) -> [CGPoint] { points.map { apply($0) } }
}

extension SimilarityTransform: PointWarp {}

// MARK: - Richer landmarks for the spline warp

extension CloudLandmarks {
    /// Nine reference points — centroid, the four axis extremes, and the four
    /// diagonal extremes (max/min of x±y). More correspondences than
    /// `referencePoints` so a thin-plate spline can follow the cloud's bumps
    /// in eight directions rather than just scaling+rotating. Some may
    /// coincide on a given shape; the warp fitter de-duplicates before
    /// solving.
    static func richReferencePoints(_ contour: [CGPoint]) -> [CGPoint] {
        guard !contour.isEmpty else { return Array(repeating: .zero, count: 9) }

        var sumX = 0.0, sumY = 0.0
        var top = contour[0], bottom = contour[0], left = contour[0], right = contour[0]
        var maxSum = contour[0], minSum = contour[0]      // x+y extremes (BR / TL)
        var maxDiff = contour[0], maxNegDiff = contour[0] // x−y and y−x extremes (TR / BL)

        for p in contour {
            sumX += Double(p.x); sumY += Double(p.y)
            if p.y < top.y { top = p }
            if p.y > bottom.y { bottom = p }
            if p.x < left.x { left = p }
            if p.x > right.x { right = p }
            if (p.x + p.y) > (maxSum.x + maxSum.y) { maxSum = p }
            if (p.x + p.y) < (minSum.x + minSum.y) { minSum = p }
            if (p.x - p.y) > (maxDiff.x - maxDiff.y) { maxDiff = p }
            if (p.y - p.x) > (maxNegDiff.y - maxNegDiff.x) { maxNegDiff = p }
        }

        let n = CGFloat(contour.count)
        let centroid = CGPoint(x: CGFloat(sumX) / n, y: CGFloat(sumY) / n)
        return [centroid, top, bottom, left, right, maxSum, minSum, maxDiff, maxNegDiff]
    }
}

// MARK: - Dense linear solver

/// Gauss–Jordan elimination with partial pivoting for small dense systems
/// (the spline's `L` matrix is at most 12×12). Returns `nil` on a singular
/// system so the caller can fall back to the similarity transform.
enum LinearSolve {
    static func solve(_ A: [[Double]], _ b: [Double]) -> [Double]? {
        let n = A.count
        guard n > 0, b.count == n else { return nil }

        var M = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: n)
        for i in 0..<n {
            for j in 0..<n { M[i][j] = A[i][j] }
            M[i][n] = b[i]
        }

        for col in 0..<n {
            var piv = col
            for r in (col + 1)..<n where abs(M[r][col]) > abs(M[piv][col]) { piv = r }
            if abs(M[piv][col]) < 1e-12 { return nil }
            M.swapAt(col, piv)

            let pivotValue = M[col][col]
            for r in 0..<n where r != col {
                let factor = M[r][col] / pivotValue
                if factor == 0 { continue }
                for c in col...n { M[r][c] -= factor * M[col][c] }
            }
        }

        var x = [Double](repeating: 0, count: n)
        for i in 0..<n { x[i] = M[i][n] / M[i][i] }
        return x
    }
}

// MARK: - Thin-plate spline

/// A thin-plate-spline warp: the smooth 2-D deformation that exactly maps each
/// source control point onto its target and bends as little as possible in
/// between. Drapes a template onto the cloud so appendages follow the cloud's
/// actual bumps, not just a global scale+rotation. Fitting solves the standard
/// TPS linear system `[[K, P], [Pᵀ, 0]] · [w; a] = [v; 0]` per axis.
struct ThinPlateSpline: PointWarp {
    private let src: [CGPoint]
    private let coeffX: [Double] // length src.count + 3 (weights ++ affine a0,a1,a2)
    private let coeffY: [Double]

    /// TPS radial kernel U(r) = r²·ln r, expressed in squared distance:
    /// r²·ln r = ½·d²·ln(d²). Zero at the control point itself.
    private static func kernel(_ d2: Double) -> Double {
        d2 < 1e-30 ? 0 : 0.5 * d2 * log(d2)
    }

    /// Fit the spline for `source[i] → target[i]`. `regularization` (λ, added
    /// to the kernel diagonal) trades exact interpolation for smoothness and
    /// guards near-degenerate control sets. Returns `nil` if the system is
    /// singular or produces non-finite coefficients.
    static func fit(source: [CGPoint], target: [CGPoint], regularization: Double = 1e-6) -> ThinPlateSpline? {
        let n = min(source.count, target.count)
        guard n >= 3 else { return nil }

        var L = [[Double]](repeating: [Double](repeating: 0, count: n + 3), count: n + 3)
        for i in 0..<n {
            for j in 0..<n {
                let dx = Double(source[i].x - source[j].x)
                let dy = Double(source[i].y - source[j].y)
                L[i][j] = kernel(dx * dx + dy * dy)
            }
            L[i][i] += regularization
            L[i][n] = 1; L[i][n + 1] = Double(source[i].x); L[i][n + 2] = Double(source[i].y)
            L[n][i] = 1; L[n + 1][i] = Double(source[i].x); L[n + 2][i] = Double(source[i].y)
        }

        var bx = [Double](repeating: 0, count: n + 3)
        var by = [Double](repeating: 0, count: n + 3)
        for i in 0..<n { bx[i] = Double(target[i].x); by[i] = Double(target[i].y) }

        guard let cx = LinearSolve.solve(L, bx),
              let cy = LinearSolve.solve(L, by),
              cx.allSatisfy(\.isFinite), cy.allSatisfy(\.isFinite)
        else { return nil }

        return ThinPlateSpline(src: source, coeffX: cx, coeffY: cy)
    }

    func apply(_ p: CGPoint) -> CGPoint {
        CGPoint(x: evaluate(coeffX, p), y: evaluate(coeffY, p))
    }

    private func evaluate(_ c: [Double], _ p: CGPoint) -> Double {
        let n = src.count
        // Affine part a0 + a1·x + a2·y …
        var v = c[n] + c[n + 1] * Double(p.x) + c[n + 2] * Double(p.y)
        // … plus the bending contribution from each control point.
        for i in 0..<n {
            let dx = Double(p.x - src[i].x)
            let dy = Double(p.y - src[i].y)
            v += c[i] * Self.kernel(dx * dx + dy * dy)
        }
        return v
    }
}

// MARK: - Warp selection

/// Chooses the best warp from a template contour onto a cloud contour: a
/// thin-plate spline over the (de-duplicated) rich landmarks when they support
/// one, otherwise the closed-form similarity transform. Always returns a usable
/// warp.
enum TemplateWarp {
    static func fit(templateContour: [CGPoint], cloudContour: [CGPoint]) -> PointWarp {
        let (source, target) = dedupedRichCorrespondences(
            templateContour: templateContour,
            cloudContour: cloudContour
        )
        if source.count >= 4,
           let spline = ThinPlateSpline.fit(source: source, target: target) {
            return spline
        }
        return SimilarityTransform.fit(templateContour: templateContour, cloudContour: cloudContour)
    }

    /// Rich landmarks for both contours, dropping template landmarks that
    /// coincide (a shape whose top point is also its top-left diagonal, say)
    /// — coincident source points make the spline system singular. The same
    /// indices are removed from the cloud side to keep the correspondence.
    static func dedupedRichCorrespondences(
        templateContour: [CGPoint],
        cloudContour: [CGPoint],
        epsilon: CGFloat = 1e-4
    ) -> (source: [CGPoint], target: [CGPoint]) {
        let src = CloudLandmarks.richReferencePoints(templateContour)
        let dst = CloudLandmarks.richReferencePoints(cloudContour)
        let e2 = epsilon * epsilon

        var keptSource: [CGPoint] = []
        var keptTarget: [CGPoint] = []
        for i in 0..<min(src.count, dst.count) {
            let p = src[i]
            let isDuplicate = keptSource.contains { q in
                let dx = q.x - p.x, dy = q.y - p.y
                return dx * dx + dy * dy <= e2
            }
            if !isDuplicate {
                keptSource.append(p)
                keptTarget.append(dst[i])
            }
        }
        return (keptSource, keptTarget)
    }
}
