import XCTest
@testable import Cloudoodle

final class CloudAnalysisParsingTests: XCTestCase {

    func testParseValidResponse() throws {
        let json = """
        {
          "shape_name": "Dragon",
          "quip": "A sleepy dragon banks left toward the horizon, trailing a wisp of cumulus smoke.",
          "cloud_type": "Cumulonimbus",
          "weather_mood": "Brooding",
          "watchability_score": 9
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let analysis = try JSONDecoder().decode(CloudAnalysis.self, from: data)

        XCTAssertEqual(analysis.shapeName, "Dragon")
        XCTAssertEqual(analysis.cloudType, "Cumulonimbus")
        XCTAssertEqual(analysis.weatherMood, "Brooding")
        XCTAssertEqual(analysis.watchabilityScore, 9)
        XCTAssertFalse(analysis.quip.isEmpty)
    }

    func testParseMinimalResponse() throws {
        let json = """
        {
          "shape_name": "Bunny",
          "quip": "Cotton-tailed and dozing.",
          "cloud_type": "Cumulus",
          "weather_mood": "Gentle",
          "watchability_score": 6
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let analysis = try JSONDecoder().decode(CloudAnalysis.self, from: data)
        XCTAssertEqual(analysis.shapeName, "Bunny")
        XCTAssertEqual(analysis.watchabilityScore, 6)
    }

    func testSightingRoundTrip() throws {
        let analysis = CloudAnalysis(
            shapeName: "Ship",
            quip: "A galleon made of air.",
            cloudType: "Cirrus",
            weatherMood: "Airy",
            watchabilityScore: 7
        )
        let elements = [
            CloudAnalysis.DrawingElement(
                points: [[0.1, 0.2], [0.3, 0.4], [0.5, 0.3]],
                smooth: false,
                strokeWidth: 2.0,
                label: nil
            )
        ]
        let sighting = CloudSighting(
            analysis: analysis,
            drawingElements: elements,
            drawingLabelX: 0.5,
            drawingLabelY: 0.3
        )
        XCTAssertEqual(sighting.shapeName, "Ship")
        XCTAssertEqual(sighting.drawingElements.count, 1)
        XCTAssertEqual(sighting.drawingElements[0].points.count, 3)
    }

    func testDrawingElementEncoding() throws {
        let element = CloudAnalysis.DrawingElement(
            points: [[0.2, 0.3], [0.4, 0.5]],
            smooth: false,
            strokeWidth: 2.5,
            label: "body"
        )
        let data = try JSONEncoder().encode(element)
        let decoded = try JSONDecoder().decode(CloudAnalysis.DrawingElement.self, from: data)
        XCTAssertEqual(decoded.points.count, 2)
        XCTAssertEqual(decoded.strokeWidth, 2.5)
        XCTAssertEqual(decoded.label, "body")
        XCTAssertFalse(decoded.smooth)
    }
}
