import XCTest
@testable import CloudView

/// Tests for the seeded quip/caption engine. The engine must produce valid,
/// weather-entangled copy for every creature in the current template
/// vocabulary AND for arbitrary unknown labels (so future art drops never
/// dead-branch it — the failure mode of the old hand-written template tree).
final class QuipEngineTests: XCTestCase {

    private let currentVocabulary = [
        "rabbit", "fish", "cat", "bird", "whale", "turtle", "dragon", "swan", "bear",
        "elephant", "giraffe", "butterfly", "octopus", "dog", "duck", "dolphin",
        "dinosaur", "unicorn", "snail", "sailboat",
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
                for seed in 0..<4 {
                    let quip = QuipEngine.quip(
                        creature: creature, trend: trend,
                        details: details(for: trend), seed: UInt64(seed)
                    )
                    XCTAssertFalse(quip.isEmpty, "\(creature)/\(trend)")
                    XCTAssertFalse(quip.contains("{"),
                                   "unsubstituted token in '\(quip)' (\(creature)/\(trend))")
                    XCTAssertFalse(quip.contains("nil"), "leaked nil in \(quip)")
                }
            }
        }
    }

    func testQuipEntanglesCreatureWithWeather() {
        // The whole point of the redesign: one integrated thought, where the
        // creature's nature meets the forecast. Spot-check signature cells —
        // every variant of the cell must carry the creature's angle.
        for seed in 0..<8 {
            let dragonRain = QuipEngine.quip(
                creature: "Dragon", trend: .rainComing,
                details: QuipEngine.WeatherDetails(hoursAway: 1), seed: UInt64(seed)
            ).lowercased()
            XCTAssertTrue(dragonRain.contains("flame") || dragonRain.contains("steam"),
                          "dragon×rain should be about fire meeting water: \(dragonRain)")

            let duckRain = QuipEngine.quip(
                creature: "duck", trend: .rainComing,
                details: QuipEngine.WeatherDetails(hoursAway: 2), seed: UInt64(seed)
            ).lowercased()
            XCTAssertTrue(duckRain.contains("duck"), "duck×rain should be duck-flavored: \(duckRain)")

            let turtleRain = QuipEngine.quip(
                creature: "turtle", trend: .rainComing,
                details: QuipEngine.WeatherDetails(hoursAway: 2), seed: UInt64(seed)
            ).lowercased()
            XCTAssertTrue(turtleRain.contains("roof"),
                          "turtle×rain should lean on the shell-as-roof joke: \(turtleRain)")
        }
    }

    func testUnknownCreatureFallsBackGracefully() {
        let quip = QuipEngine.quip(
            creature: "Axolotl", trend: .rainComing,
            details: QuipEngine.WeatherDetails(hoursAway: 2), seed: 7
        )
        XCTAssertFalse(quip.isEmpty)
        XCTAssertTrue(quip.lowercased().contains("axolotl"),
                      "generic form should name the creature: \(quip)")
        XCTAssertFalse(quip.contains("{"))
    }

    func testQuipIsDeterministicForSameSeed() {
        let a = QuipEngine.quip(creature: "whale", trend: .windy,
                                details: QuipEngine.WeatherDetails(windSpeed: 12), seed: 99)
        let b = QuipEngine.quip(creature: "whale", trend: .windy,
                                details: QuipEngine.WeatherDetails(windSpeed: 12), seed: 99)
        XCTAssertEqual(a, b)
    }

    func testQuipVariesAcrossSeedsOnMultiVariantCells() {
        // cat × rainComing has 2 authored variants; 16 seeds finding only
        // one would mean seeding is broken.
        let variants = Set((0..<16).map { seed in
            QuipEngine.quip(creature: "cat", trend: .rainComing,
                            details: QuipEngine.WeatherDetails(hoursAway: 2),
                            seed: UInt64(seed))
        })
        XCTAssertGreaterThan(variants.count, 1)
    }

    func testWeatherDetailsAreInterpolated() {
        let colder = QuipEngine.quip(
            creature: "bear", trend: .gettingColder,
            details: QuipEngine.WeatherDetails(targetTemp: 33), seed: 1
        )
        XCTAssertTrue(colder.contains("33"), "target temperature should appear: \(colder)")

        let windy = QuipEngine.quip(
            creature: "swan", trend: .windy,
            details: QuipEngine.WeatherDetails(windSpeed: 21), seed: 1
        )
        XCTAssertTrue(windy.contains("21"), "wind speed should appear: \(windy)")

        let rain = QuipEngine.quip(
            creature: "rabbit", trend: .rainComing,
            details: QuipEngine.WeatherDetails(hoursAway: 1), seed: 1
        )
        XCTAssertTrue(rain.contains("within the hour"), "imminent rain phrasing: \(rain)")
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
