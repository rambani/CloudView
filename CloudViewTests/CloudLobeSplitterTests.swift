import XCTest
import CoreGraphics
@testable import CloudView

/// The brightness-field lobe splitter on synthetic skies: two puffs split,
/// one dome stays whole, a shallow valley merges, outlines trace.
final class CloudLobeSplitterTests: XCTestCase {

    private let w = 96, h = 64

    /// Sum of gaussian puffs on a dim background, with the mask at 0.5.
    private func sky(puffs: [(cx: Float, cy: Float, sigma: Float, amp: Float)]) -> (GrayGrid, [Bool]) {
        var px = [Float](repeating: 0.2, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                var v: Float = 0.2
                for p in puffs {
                    let dx = Float(x) - p.cx, dy = Float(y) - p.cy
                    v += p.amp * exp(-(dx * dx + dy * dy) / (2 * p.sigma * p.sigma))
                }
                px[y * w + x] = min(v, 1)
            }
        }
        let grid = GrayGrid(width: w, height: h, pixels: px)
        return (grid, px.map { $0 > 0.5 })
    }

    func testTwoPuffsSplitIntoTwoLobes() {
        let (grid, mask) = sky(puffs: [(28, 32, 10, 0.8), (68, 32, 10, 0.8)])
        let lobes = CloudLobeSplitter.split(grid, mask: mask)
        XCTAssertEqual(lobes.count, 2)
        // Roughly equal halves, each a real outline.
        let areas = lobes.map(\.area)
        XCTAssertGreaterThan(areas.min()!, Int(Double(areas.max()!) * 0.6))
        for lobe in lobes { XCTAssertGreaterThanOrEqual(lobe.outline.count, 3) }
        // One lobe lives on the left, the other on the right.
        let centersX = lobes.map { $0.outline.map(\.x).reduce(0, +) / CGFloat($0.outline.count) }.sorted()
        XCTAssertLessThan(centersX[0], 48)
        XCTAssertGreaterThan(centersX[1], 48)
    }

    func testSingleDomeStaysWhole() {
        let (grid, mask) = sky(puffs: [(48, 32, 16, 0.8)])
        let lobes = CloudLobeSplitter.split(grid, mask: mask)
        XCTAssertEqual(lobes.count, 1)
        XCTAssertEqual(lobes[0].area, mask.filter { $0 }.count)
    }

    func testShallowValleyMergesIntoOneLobe() {
        // Two peaks so close that the saddle between them is nearly as
        // bright as the peaks → one lobe, not two.
        let (grid, mask) = sky(puffs: [(42, 32, 14, 0.8), (54, 32, 14, 0.8)])
        let lobes = CloudLobeSplitter.split(grid, mask: mask)
        XCTAssertEqual(lobes.count, 1)
    }

    func testTinyLobeFoldsIntoNeighbor() {
        // A big puff and a speck of a puff: the speck isn't its own lobe.
        let (grid, mask) = sky(puffs: [(40, 32, 14, 0.8), (80, 32, 2.5, 0.8)])
        let lobes = CloudLobeSplitter.split(grid, mask: mask)
        XCTAssertEqual(lobes.count, 1)
    }

    func testBoxBlurPreservesConstantImage() {
        let img = [Float](repeating: 0.7, count: w * h)
        let out = CloudLobeSplitter.boxBlur(img, width: w, height: h, radius: 3)
        for v in out { XCTAssertEqual(v, 0.7, accuracy: 1e-5) }
    }

    func testOutlineTracesRectanglePerimeter() {
        var labels = [Int](repeating: 0, count: w * h)
        for y in 10..<20 { for x in 20..<40 { labels[y * w + x] = 1 } }
        let outline = CloudLobeSplitter.traceOutline(labels, width: w, height: h, label: 1)
        XCTAssertGreaterThanOrEqual(outline.count, 4)
        for p in outline {
            XCTAssertTrue(p.x >= 20 && p.x <= 39 && p.y >= 10 && p.y <= 19)
            XCTAssertTrue(p.x == 20 || p.x == 39 || p.y == 10 || p.y == 19, "\(p) is not on the perimeter")
        }
        XCTAssertEqual(outline.first, CGPoint(x: 20, y: 10))
    }

    func testSummitIsTheTopOfTheBrightMassNotTheWisp() {
        // A puff with a dim vertical wisp rising from its top: the mask
        // includes the wisp, the summit stops where the brightness falls.
        let (grid0, _) = sky(puffs: [(48, 40, 9, 0.8)])
        var px = grid0.pixels
        for y in 4..<40 { px[y * w + 48] = max(px[y * w + 48], 0.55); px[y * w + 47] = max(px[y * w + 47], 0.55) }
        let grid = GrayGrid(width: w, height: h, pixels: px)
        let mask = px.map { $0 > 0.5 }
        let lobes = CloudLobeSplitter.split(grid, mask: mask)
        XCTAssertEqual(lobes.count, 1)
        let s = lobes[0].summit
        XCTAssertEqual(s.x, 48, accuracy: 1.5)
        // Peak brightness 1.0 at y=40; 80% of it is reached ~6–7 px up the
        // gaussian, far below the wisp's top at y=4.
        XCTAssertGreaterThan(s.y, 28)
        XCTAssertLessThan(s.y, 40)
        // …while the outline's extreme top is up the wisp.
        XCTAssertLessThan(lobes[0].outline.map(\.y).min()!, 10)
    }

    func testPeaksAreNonMaxSuppressed() {
        let (grid, mask) = sky(puffs: [(28, 32, 10, 0.8), (68, 32, 10, 0.8)])
        let field = CloudLobeSplitter.smooth(grid)
        let peaks = CloudLobeSplitter.findPeaks(field, width: w, height: h, mask: mask, minDistance: 9)
        XCTAssertEqual(peaks.count, 2)
        XCTAssertGreaterThanOrEqual(peaks[0].value, peaks[1].value)
    }
}
