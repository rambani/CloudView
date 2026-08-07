import XCTest
@testable import CloudView

/// Tests for the seeded quip/caption engine. The engine must produce valid
/// copy for every creature in the current template vocabulary AND for
/// arbitrary unknown labels (so future art drops never dead-branch it, the
/// failure mode of the old hand-written template tree).
final class QuipEngineTests: XCTestCase {

    private let currentVocabulary = [
        "rabbit", "fish", "cat", "bird", "whale", "turtle", "dragon", "swan", "bear",
    ]

    private let allTrends: [QuipEngine.WeatherTrend] = [
        .rainComing, .gettingWarmer, .gettingColder, .stormyComing, .windy, .stable,
    ]

    private func details(for trend: QuipEngine.WeatherTrend) -> QuipEngine.WeatherDetails {
        switch trend {
        case .rainComing:    return QuipEngine.WeatherDetails(hoursAway: 2)
        case .gettingWarmer: return QuipEngine.WeatherDetails(targetTemp: 78)
        case .gettingColder: return QuipEngine.WeatherDetails(targetTemp: 41)
        case .stormyComing:  return QuipEngine.WeatherDetails(hoursAway: 1)
        case .windy:         return QuipEngine.WeatherDetails(windSpeed: 18)
        case .stable:        return QuipEngine.WeatherDetails(currentTemp: 68)
        }
    }

    func testEveryCreatureTimesEveryTrendProducesValidCopy() {
        for creature in currentVocabulary {
            for trend in allTrends {
                let quip = QuipEngine.quip(
                    creature: creature, trend: trend,
                    details: details(for: trend), seed: 42
                )
                XCTAssertFalse(quip.isEmpty, "\(creature)/\(trend)")
                XCTAssertFalse(quip.contains("%@"), "unsubstituted placeholder in \(quip)")
                XCTAssertFalse(quip.contains("nil"), "leaked nil in \(quip)")
            }
        }
    }

    func testUnknownCreatureFallsBackGracefully() {
        let quip = QuipEngine.quip(
            creature: "Axolotl", trend: .stable,
            details: QuipEngine.WeatherDetails(currentTemp: 70), seed: 7
        )
        XCTAssertFalse(quip.isEmpty)
        XCTAssertTrue(quip.lowercased().contains("axolotl"), "generic form should name the creature: \(quip)")
        XCTAssertFalse(quip.contains("%@"))
    }

    func testQuipIsDeterministicForSameSeed() {
        let a = QuipEngine.quip(creature: "whale", trend: .windy,
                                details: QuipEngine.WeatherDetails(windSpeed: 12), seed: 99)
        let b = QuipEngine.quip(creature: "whale", trend: .windy,
                                details: QuipEngine.WeatherDetails(windSpeed: 12), seed: 99)
        XCTAssertEqual(a, b)
    }

    func testQuipVariesAcrossSeeds() {
        let variants = Set((0..<16).map { seed in
            QuipEngine.quip(creature: "dragon", trend: .stable,
                            details: QuipEngine.WeatherDetails(currentTemp: 70),
                            seed: UInt64(seed))
        })
        // 3 sighting × 3 weather lines = 9 possible; 16 seeds finding only
        // one would mean the seeding is broken.
        XCTAssertGreaterThan(variants.count, 1)
    }

    func testWeatherDetailsAreInterpolated() {
        let quip = QuipEngine.quip(
            creature: "bear", trend: .gettingColder,
            details: QuipEngine.WeatherDetails(targetTemp: 33), seed: 1
        )
        XCTAssertTrue(quip.contains("33"), "target temperature should appear: \(quip)")

        let windy = QuipEngine.quip(
            creature: "swan", trend: .windy,
            details: QuipEngine.WeatherDetails(windSpeed: 21), seed: 1
        )
        XCTAssertTrue(windy.contains("21"), "wind speed should appear: \(windy)")
    }

    func testCaptionNamesTheCreatureAndIsDeterministic() {
        for creature in currentVocabulary + ["Axolotl"] {
            let caption = QuipEngine.caption(creature: creature, seed: 5)
            XCTAssertFalse(caption.isEmpty)
            XCTAssertTrue(
                caption.contains(creature.capitalized),
                "caption should show the display name: \(caption)"
            )
            XCTAssertEqual(caption, QuipEngine.caption(creature: creature, seed: 5))
        }
    }

    func testSeedStableWithinHourFreshAcrossHoursAndDrawings() {
        let a = QuipEngine.seed(for: "Dragon", hourBucket: 100)
        XCTAssertEqual(a, QuipEngine.seed(for: "Dragon", hourBucket: 100))
        XCTAssertEqual(a, QuipEngine.seed(for: "dragon", hourBucket: 100), "case-insensitive")
        XCTAssertNotEqual(a, QuipEngine.seed(for: "Dragon", hourBucket: 101))
        XCTAssertNotEqual(a, QuipEngine.seed(for: "Whale", hourBucket: 100))
    }
}
