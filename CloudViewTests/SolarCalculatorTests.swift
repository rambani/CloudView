import XCTest
import CoreLocation
@testable import CloudView

final class SolarCalculatorTests: XCTestCase {

    // San Francisco summer solstice — verify sunrise is in the morning UTC and
    // sunset is in the evening UTC, with sunrise comfortably before sunset.
    func testSunriseBeforeSunsetInSanFrancisco() {
        let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let june21 = date(year: 2026, month: 6, day: 21)

        let result = SolarCalculator.sunriseSunset(for: sf, date: june21)
        XCTAssertNotNil(result.sunrise)
        XCTAssertNotNil(result.sunset)

        if let sunrise = result.sunrise, let sunset = result.sunset {
            XCTAssertLessThan(sunrise, sunset, "sunrise should be before sunset")
            // SF sunrise on the summer solstice ≈ 12:48 UTC (~5:48 PDT). Allow
            // ±90 min slack to absorb the NOAA approximation's tolerance.
            let expectedSunrise = date(year: 2026, month: 6, day: 21, hour: 12, minute: 48)
            XCTAssertEqual(sunrise.timeIntervalSince(expectedSunrise), 0, accuracy: 90 * 60)
        }
    }

    func testEquatorHasNearTwelveHourDayAtEquinox() {
        // March equinox at the equator: day length should be ~12 hours.
        let equator = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let equinox = date(year: 2026, month: 3, day: 20)

        let result = SolarCalculator.sunriseSunset(for: equator, date: equinox)
        guard let sunrise = result.sunrise, let sunset = result.sunset else {
            XCTFail("Expected sunrise/sunset at the equator on the equinox")
            return
        }
        let dayLengthSeconds = sunset.timeIntervalSince(sunrise)
        XCTAssertEqual(dayLengthSeconds, 12 * 3600, accuracy: 30 * 60)
    }

    func testPolarNightReturnsNilSunriseOrSunset() {
        // Above the Arctic circle in mid-winter the sun does not rise.
        let nuuk = CLLocationCoordinate2D(latitude: 78.0, longitude: 15.0) // Svalbard
        let midWinter = date(year: 2026, month: 12, day: 21)

        let result = SolarCalculator.sunriseSunset(for: nuuk, date: midWinter)
        // The implementation returns nil when cosH is out of range. Either both
        // are nil (true polar night) — we tolerate either side being nil.
        XCTAssertTrue(
            result.sunrise == nil || result.sunset == nil,
            "Expected at least one of sunrise/sunset to be nil during polar night"
        )
    }

    // MARK: Helpers

    private func date(
        year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }
}
