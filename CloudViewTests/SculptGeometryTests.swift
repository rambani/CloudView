import XCTest
import CoreGraphics
@testable import CloudView

/// The pure part of the "develop" pass: sizing, placement and the
/// pool-vs-outline decision. The Core Image chain itself is exercised on
/// device and mirrored by tools/sculpt_preview.py.
final class SculptGeometryTests: XCTestCase {

    func testSculptWidthScalesWithCloudButNeverBelowInkFloor() {
        // Big cloud: 3% of the short side wins.
        XCTAssertEqual(SculptGeometry.sculptWidth(cloudShortSide: 600, inkWidth: 4), 18, accuracy: 1e-9)
        // Small cloud: 2.4 ink widths floor wins.
        XCTAssertEqual(SculptGeometry.sculptWidth(cloudShortSide: 100, inkWidth: 4), 9.6, accuracy: 1e-9)
    }

    func testPixelPointsMapNormalizedBoxToImagePixels() {
        let box = CGRect(x: 100, y: 200, width: 400, height: 300)
        let pts = SculptGeometry.pixelPoints([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 0.5)], in: box)
        XCTAssertEqual(pts[0], CGPoint(x: 100, y: 200))
        XCTAssertEqual(pts[1], CGPoint(x: 500, y: 500))
        XCTAssertEqual(pts[2], CGPoint(x: 300, y: 350))
    }

    func testPolygonAreaShoelace() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10)]
        XCTAssertEqual(SculptGeometry.polygonArea(square), 100, accuracy: 1e-9)
        XCTAssertEqual(SculptGeometry.polygonArea([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]), 0)
    }

    func testPoolDecision() {
        let boxArea: CGFloat = 400 * 300
        let eye = [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 10), CGPoint(x: 30, y: 30), CGPoint(x: 10, y: 30)] // 400 px²
        let body = [CGPoint(x: 0, y: 0), CGPoint(x: 300, y: 0), CGPoint(x: 300, y: 200), CGPoint(x: 0, y: 200)]   // 60 000 px²
        XCTAssertTrue(SculptGeometry.isPool(eye, closed: true, boxArea: boxArea))
        XCTAssertFalse(SculptGeometry.isPool(eye, closed: false, boxArea: boxArea)) // open paths never pool
        XCTAssertFalse(SculptGeometry.isPool(body, closed: true, boxArea: boxArea)) // the body outline stays a line
    }

    func testRimLightSitsAboveTheCrease() {
        let off = SculptGeometry.rimOffset(sculptWidth: 10)
        XCTAssertEqual(off.dx, 0)
        XCTAssertLessThan(off.dy, 0) // image space is y-down: negative = up
        XCTAssertEqual(off.dy, -8, accuracy: 1e-9)
    }

    func testWorkingScaleOnlyShrinks() {
        XCTAssertEqual(SculptGeometry.workingScale(imageSize: CGSize(width: 1440, height: 1920)), 1600.0 / 1920.0, accuracy: 1e-9)
        XCTAssertEqual(SculptGeometry.workingScale(imageSize: CGSize(width: 800, height: 600)), 1)
        XCTAssertEqual(SculptGeometry.workingScale(imageSize: .zero), 1)
    }
}
