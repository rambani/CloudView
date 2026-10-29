import XCTest
import CoreGraphics
@testable import CloudView

/// The pure parts of dream mode: prompts and crop geometry. Generation
/// itself needs the model and a device (docs/DREAM_MODE.md).
final class DreamDeveloperTests: XCTestCase {

    func testPromptsNameTheCreatureAndStayKidSafe() {
        let (p, n) = DreamDeveloper.prompt(for: "dragon", style: .ink)
        XCTAssertTrue(p.contains("dragon"))
        XCTAssertTrue(p.contains("white ink line drawing"))
        XCTAssertTrue(n.contains("scary"))
        let (c, _) = DreamDeveloper.prompt(for: "bear", style: .creature)
        XCTAssertTrue(c.contains("bear made of white cumulus clouds"))
    }

    func testCropRectScalesWithTheFrame() {
        // A 1440×1920 original scaled to 1200 wide for the sculpt working
        // size (frameScale 0.8333): the crop is computed in frame pixels.
        let frameScale: CGFloat = 1200.0 / 1440.0
        let box = CGRect(x: 400, y: 600, width: 480, height: 300)
        let frame = makeImage(width: 1200, height: 1600)
        let request = DreamDeveloper.Request(frame: frame, frameScale: frameScale, cloudContour: [],
                                             cloudBox: box, paths: [], creature: "bear")
        let rect = DreamDeveloper.cropRect(request)
        // 480 px wide in original → 400 in frame; ×1.3 margin = 520.
        XCTAssertEqual(rect.width, 520, accuracy: 1)
        XCTAssertEqual(rect.midX, (400 + 240) * frameScale, accuracy: 1)
    }

    func testIsAvailableIsFalseWithoutModelOrOptIn() {
        // No DreamModel resource in the test bundle, and the toggle default
        // is off → never claims availability (and never crashes).
        DreamDeveloper.isEnabled = false
        XCTAssertFalse(DreamDeveloper.isAvailable)
    }

    private func makeImage(width: Int, height: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.5, green: 0.7, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }
}
