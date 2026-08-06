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
