import XCTest
import CoreGraphics
import simd
@testable import CloudView

/// Which detected blob the pipeline acts on. The detector used to take
/// whatever Vision listed first; now the one the user is aiming at wins and
/// an overcast sheet is not a cloud.
final class CloudCandidateSelectionTests: XCTestCase {

    private let image = CGSize(width: 1440, height: 1920)

    private func shape(center: CGPoint, size: CGSize) -> CloudShape {
        CloudShape(
            center: simd_float3(0, 0, 0),
            boundingBox: CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                                width: size.width, height: size.height),
            screenPosition: center,
            size: size,
            aspectRatio: Float(size.width / size.height),
            area: Float(size.width * size.height),
            contourPoints: [],
            normalizedContour: []
        )
    }

    func testCenteredCloudBeatsBiggerCloudAtTheEdge() {
        let centered = shape(center: CGPoint(x: 720, y: 960), size: CGSize(width: 300, height: 300))
        let edge = shape(center: CGPoint(x: 150, y: 200), size: CGSize(width: 600, height: 600))
        let ranked = CloudCandidateSelection.rank([edge, centered], imageSize: image)
        XCTAssertEqual(ranked.first?.size.width, 300)
    }

    func testBiggerCloudWinsAtTheSameSpot() {
        let small = shape(center: CGPoint(x: 720, y: 960), size: CGSize(width: 200, height: 200))
        let big = shape(center: CGPoint(x: 720, y: 960), size: CGSize(width: 500, height: 500))
        let ranked = CloudCandidateSelection.rank([small, big], imageSize: image)
        XCTAssertEqual(ranked.first?.size.width, 500)
    }

    func testOvercastSheetIsDropped() {
        // Covers ~75% of the frame — nothing to doodle on.
        let sheet = shape(center: CGPoint(x: 720, y: 960), size: CGSize(width: 1300, height: 1650))
        let puff = shape(center: CGPoint(x: 400, y: 500), size: CGSize(width: 250, height: 250))
        let ranked = CloudCandidateSelection.rank([sheet, puff], imageSize: image)
        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked.first?.size.width, 250)
        XCTAssertTrue(CloudCandidateSelection.rank([sheet], imageSize: image).isEmpty)
    }

    func testAreaFractionAndScoreAreWellBehaved() {
        let s = shape(center: CGPoint(x: 720, y: 960), size: CGSize(width: 720, height: 960))
        XCTAssertEqual(Double(CloudCandidateSelection.areaFraction(s, imageSize: image)), 0.25, accuracy: 1e-9)
        XCTAssertEqual(Double(CloudCandidateSelection.score(s, imageSize: image)), 0.5, accuracy: 1e-9)
        XCTAssertEqual(CloudCandidateSelection.score(s, imageSize: .zero), 0)
    }
}
