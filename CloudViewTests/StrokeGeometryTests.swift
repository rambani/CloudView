import XCTest
import CoreGraphics
import simd
@testable import CloudView

/// The progressive-reveal stroke geometry: pen-speed cutting of a polyline
/// and the ribbon mesh with round joins/caps. Pure — no RealityKit.
final class StrokeGeometryTests: XCTestCase {

    private func p(_ x: Float, _ y: Float) -> SIMD2<Float> { SIMD2<Float>(x, y) }

    func testLocalPointsCenterAndFlipY() {
        let pts = StrokeGeometry.localPoints(
            [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 0.5)],
            worldSize: CGSize(width: 10, height: 4)
        )
        XCTAssertEqual(pts[0], p(-5, 2))   // top-left → left, up
        XCTAssertEqual(pts[1], p(5, -2))   // bottom-right → right, down
        XCTAssertEqual(pts[2], p(0, 0))
    }

    func testClosedPolylineAppendsClosingSegment() {
        let square = [p(0, 0), p(1, 0), p(1, 1), p(0, 1)]
        let closed = StrokeGeometry.polyline(square, closed: true)
        XCTAssertEqual(closed.count, 5)
        XCTAssertEqual(closed.last, p(0, 0))
        XCTAssertEqual(StrokeGeometry.totalLength(closed), 4, accuracy: 1e-6)

        // Open paths and degenerate "closed" ones are left alone.
        XCTAssertEqual(StrokeGeometry.polyline(square, closed: false).count, 4)
        XCTAssertEqual(StrokeGeometry.polyline([p(0, 0), p(1, 0)], closed: true).count, 2)
    }

    func testRevealedPrefixCutsAtArcLength() {
        // An L: 3 units right, then 1 unit up. Total 4.
        let line = [p(0, 0), p(3, 0), p(3, 1)]

        XCTAssertEqual(StrokeGeometry.revealedPrefix(line, reveal: 0), [p(0, 0)])

        // Half way = 2 units along the first segment.
        let half = StrokeGeometry.revealedPrefix(line, reveal: 0.5)
        XCTAssertEqual(half.count, 2)
        XCTAssertEqual(half[1].x, 2, accuracy: 1e-6)
        XCTAssertEqual(half[1].y, 0, accuracy: 1e-6)

        // 7/8 of the way = 3.5 units: whole first segment, half the second.
        let most = StrokeGeometry.revealedPrefix(line, reveal: 0.875)
        XCTAssertEqual(most.count, 3)
        XCTAssertEqual(most[2].x, 3, accuracy: 1e-6)
        XCTAssertEqual(most[2].y, 0.5, accuracy: 1e-6)

        XCTAssertEqual(StrokeGeometry.revealedPrefix(line, reveal: 1), line)
        XCTAssertEqual(StrokeGeometry.revealedPrefix(line, reveal: 7), line)
        XCTAssertEqual(StrokeGeometry.revealedPrefix([], reveal: 0.5), [])
    }

    func testRibbonGeometryCountsAndBounds() {
        let line = [p(0, 0), p(2, 0)]
        let mesh = StrokeGeometry.ribbon(line, width: 0.2, discSegments: 8)

        // 1 segment → 4 verts, 2 triangles; 2 discs → 2·(1+8) verts, 2·8 triangles.
        XCTAssertEqual(mesh.positions.count, 4 + 2 * 9)
        XCTAssertEqual(mesh.indices.count, (2 + 16) * 3)

        for i in mesh.indices { XCTAssertLessThan(Int(i), mesh.positions.count) }
        for v in mesh.positions {
            XCTAssertEqual(v.z, 0)
            XCTAssertTrue(v.x >= -0.1 - 1e-6 && v.x <= 2.1 + 1e-6)
            XCTAssertTrue(v.y >= -0.1 - 1e-6 && v.y <= 0.1 + 1e-6)
        }
    }

    func testRibbonSegmentIsCounterClockwise() {
        let mesh = StrokeGeometry.ribbon([p(0, 0), p(1, 0)], width: 0.2, discSegments: 3)
        let a = mesh.positions[Int(mesh.indices[0])]
        let b = mesh.positions[Int(mesh.indices[1])]
        let c = mesh.positions[Int(mesh.indices[2])]
        let cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        XCTAssertGreaterThan(cross, 0)
    }

    func testRibbonOfSinglePointIsADot() {
        let mesh = StrokeGeometry.ribbon([p(1, 1)], width: 0.5, discSegments: 6)
        XCTAssertEqual(mesh.positions.count, 7)
        XCTAssertEqual(mesh.indices.count, 18)
        XCTAssertFalse(mesh.isEmpty)
    }

    func testRibbonRejectsDegenerateInput() {
        XCTAssertTrue(StrokeGeometry.ribbon([], width: 0.1).isEmpty)
        XCTAssertTrue(StrokeGeometry.ribbon([p(0, 0), p(1, 0)], width: 0).isEmpty)
        // Zero-length segment contributes no quad but the discs still draw.
        let mesh = StrokeGeometry.ribbon([p(0, 0), p(0, 0)], width: 0.1, discSegments: 4)
        XCTAssertEqual(mesh.positions.count, 2 * 5)
    }
}
