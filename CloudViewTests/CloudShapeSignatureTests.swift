import XCTest
import CoreGraphics
@testable import CloudView

final class CloudShapeSignatureTests: XCTestCase {

    func testSignatureIsTranslationInvariant() {
        let a = circle(center: CGPoint(x: 0, y: 0), radius: 1)
        let b = circle(center: CGPoint(x: 50, y: -30), radius: 1)

        let sa = CloudShapeSignature(contour: a)
        let sb = CloudShapeSignature(contour: b)
        XCTAssertEqual(sa.cacheKey, sb.cacheKey, "Translating a shape must not change its signature")
    }

    func testSignatureIsScaleInvariant() {
        let small = circle(center: .zero, radius: 1)
        let large = circle(center: .zero, radius: 10)

        let ss = CloudShapeSignature(contour: small)
        let sl = CloudShapeSignature(contour: large)
        XCTAssertEqual(ss.cacheKey, sl.cacheKey, "Scaling a shape must not change its signature")
    }

    func testSignatureIsRotationInvariant() {
        let upright = ellipse(rx: 1, ry: 2, rotation: 0)
        let rotated = ellipse(rx: 1, ry: 2, rotation: .pi / 3)

        let su = CloudShapeSignature(contour: upright)
        let sr = CloudShapeSignature(contour: rotated)
        XCTAssertEqual(su.cacheKey, sr.cacheKey, "Rotating a shape must not change its signature")
    }

    func testDifferentShapesProduceDifferentSignatures() {
        let round = circle(center: .zero, radius: 1)
        let stretched = ellipse(rx: 1, ry: 4, rotation: 0)

        let sr = CloudShapeSignature(contour: round)
        let ss = CloudShapeSignature(contour: stretched)
        XCTAssertNotEqual(sr.cacheKey, ss.cacheKey, "A circle and a long ellipse should hash differently")
    }

    func testDegenerateContourReturnsZeroSignature() {
        let pair = [CGPoint.zero, CGPoint(x: 1, y: 1)]
        let s = CloudShapeSignature(contour: pair)
        XCTAssertEqual(s.huMoments, Array(repeating: 0, count: 7),
                       "Contours with <3 points should produce a zero signature, not crash")
    }

    func testCircleAndEllipseHaveDistinctSecondHuInvariant() {
        // Sanity-check against an algebraic prediction: h₂ for a circle is
        // exactly 0; for an aspect-2 ellipse it is ((1/(2π)) − (1/(8π)))² ≈
        // 0.0142. The two should land in different buckets.
        let c = CloudShapeSignature(contour: circle(center: .zero, radius: 1))
        let e = CloudShapeSignature(contour: ellipse(rx: 1, ry: 2, rotation: 0))
        XCTAssertEqual(c.huMoments[1], 0, accuracy: 1e-4,
                       "Circle's h₂ should be ~0")
        XCTAssertGreaterThan(e.huMoments[1], 1e-3,
                             "Ellipse's h₂ should be measurably non-zero")
    }

    // MARK: - Test geometry helpers

    private func circle(center: CGPoint, radius: CGFloat, samples: Int = 64) -> [CGPoint] {
        (0..<samples).map { i in
            let t = Double(i) / Double(samples) * 2 * .pi
            return CGPoint(
                x: center.x + radius * CGFloat(cos(t)),
                y: center.y + radius * CGFloat(sin(t))
            )
        }
    }

    private func ellipse(rx: CGFloat, ry: CGFloat, rotation: Double, samples: Int = 64) -> [CGPoint] {
        (0..<samples).map { i in
            let t = Double(i) / Double(samples) * 2 * .pi
            let x = rx * CGFloat(cos(t))
            let y = ry * CGFloat(sin(t))
            // Rotate
            let cosR = CGFloat(cos(rotation))
            let sinR = CGFloat(sin(rotation))
            return CGPoint(x: x * cosR - y * sinR, y: x * sinR + y * cosR)
        }
    }
}
