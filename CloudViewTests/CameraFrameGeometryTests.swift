import XCTest
import CoreGraphics
import simd
@testable import CloudView

/// The buffer ↔ upright bridge and the pinhole sizing. These pin the two
/// bugs that made drawings "pasted on": the drawing was sized with a magic
/// constant instead of the intrinsics, and "top of the cloud" was the
/// landscape buffer's top (the portrait screen's right).
final class CameraFrameGeometryTests: XCTestCase {

    private let buffer = CGSize(width: 1920, height: 1440)

    func testUprightSizeSwapsAxesForPortrait() {
        let upright = CameraFrameGeometry.uprightImageSize(bufferSize: buffer, orientation: .right)
        XCTAssertEqual(upright.width, 1440)
        XCTAssertEqual(upright.height, 1920)

        let same = CameraFrameGeometry.uprightImageSize(bufferSize: buffer, orientation: .up)
        XCTAssertEqual(same.width, 1920)
        XCTAssertEqual(same.height, 1440)
    }

    func testUprightCornersMapToBufferCornersForPortrait() {
        // Upright = buffer turned 90° clockwise. The buffer's first row ends
        // up on the right; its first column ends up on top.
        let upright = CGSize(width: 1440, height: 1920)
        func buf(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CameraFrameGeometry.bufferPoint(fromUpright: CGPoint(x: x, y: y), uprightSize: upright, orientation: .right)
        }
        // Upright top-left → buffer bottom-left (x = 0, y = H).
        XCTAssertEqual(buf(0, 0), CGPoint(x: 0, y: 1440))
        // Upright top-right → buffer top-left (0, 0).
        XCTAssertEqual(buf(1440, 0), CGPoint(x: 0, y: 0))
        // Upright bottom-right → buffer top-right (W, 0).
        XCTAssertEqual(buf(1440, 1920), CGPoint(x: 1920, y: 0))
        // Upright bottom-left → buffer bottom-right (W, H).
        XCTAssertEqual(buf(0, 1920), CGPoint(x: 1920, y: 1440))
        // Center stays the center.
        XCTAssertEqual(buf(720, 960), CGPoint(x: 960, y: 720))
    }

    func testIdentityOrientationIsPassThrough() {
        let p = CGPoint(x: 123, y: 456)
        XCTAssertEqual(
            CameraFrameGeometry.bufferPoint(fromUpright: p, uprightSize: buffer, orientation: .up),
            p
        )
    }

    func testWorldExtentFollowsPinholeModel() {
        // A 480-px-wide cloud through a 1500-px focal length at 50 m spans
        // 480 / 1500 · 50 = 16 m. (The old code gave 4.8 m.)
        let size = CameraFrameGeometry.worldExtent(
            uprightPixelSize: CGSize(width: 480, height: 300),
            fx: 1500, fy: 1500, distance: 50, orientation: .right
        )
        XCTAssertEqual(Double(size.width), 16.0, accuracy: 1e-5)
        XCTAssertEqual(Double(size.height), 10.0, accuracy: 1e-5)
    }

    func testWorldExtentUsesTheRightFocalLengthPerAxis() {
        // In portrait the upright x axis is the buffer's y axis → fy.
        let size = CameraFrameGeometry.worldExtent(
            uprightPixelSize: CGSize(width: 100, height: 100),
            fx: 1000, fy: 2000, distance: 10, orientation: .right
        )
        XCTAssertEqual(Double(size.width), 0.5, accuracy: 1e-6)   // 100/2000·10
        XCTAssertEqual(Double(size.height), 1.0, accuracy: 1e-6)  // 100/1000·10

        let landscape = CameraFrameGeometry.worldExtent(
            uprightPixelSize: CGSize(width: 100, height: 100),
            fx: 1000, fy: 2000, distance: 10, orientation: .up
        )
        XCTAssertEqual(Double(landscape.width), 1.0, accuracy: 1e-6)
        XCTAssertEqual(Double(landscape.height), 0.5, accuracy: 1e-6)
    }

    func testWorldLengthForStrokeWidth() {
        // 4 px at f = 1500 and 50 m → 13.3 cm.
        XCTAssertEqual(
            Double(CameraFrameGeometry.worldLength(pixels: 4, focalLength: 1500, distance: 50)),
            4.0 / 1500 * 50, accuracy: 1e-6
        )
        XCTAssertEqual(CameraFrameGeometry.worldLength(pixels: 4, focalLength: 0, distance: 50), 0)
    }

    func testUprightRollMapsImageAxesOntoCameraAxes() {
        // Portrait: image-right is the buffer's top (camera +Y); image-up is
        // the buffer's left (camera −X).
        let roll = CameraFrameGeometry.uprightRoll(orientation: .right)
        let right = roll.act(SIMD3<Float>(1, 0, 0))
        let up = roll.act(SIMD3<Float>(0, 1, 0))
        XCTAssertEqual(right.x, 0, accuracy: 1e-5)
        XCTAssertEqual(right.y, 1, accuracy: 1e-5)
        XCTAssertEqual(up.x, -1, accuracy: 1e-5)
        XCTAssertEqual(up.y, 0, accuracy: 1e-5)
        // The plane normal is untouched: the drawing still faces the camera.
        let normal = roll.act(SIMD3<Float>(0, 0, 1))
        XCTAssertEqual(normal.z, 1, accuracy: 1e-5)
    }

    func testDrawingOrientationFacesTheCamera() {
        // A camera yawed 90° left (looking down world −X). The drawing's
        // normal (+Z local) must point back at the camera: world +X.
        let yaw = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
        let cameraTransform = simd_float4x4(yaw)
        let orientation = CameraFrameGeometry.drawingOrientation(cameraTransform: cameraTransform, orientation: .right)
        let normal = orientation.act(SIMD3<Float>(0, 0, 1))
        XCTAssertEqual(normal.x, 1, accuracy: 1e-5)
        XCTAssertEqual(normal.y, 0, accuracy: 1e-5)
        XCTAssertEqual(normal.z, 0, accuracy: 1e-5)
    }
}
