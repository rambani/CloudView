import Foundation
import CoreLocation

/// Computes sunrise / sunset for a coordinate on a given day using the
/// standard NOAA solar position approximation. Accurate to ~1 minute,
/// which is plenty for deciding "is it daytime right now?".
enum SolarCalculator {
    struct Result {
        let sunrise: Date?
        let sunset: Date?
    }

    static func sunriseSunset(for coordinate: CLLocationCoordinate2D, date: Date) -> Result {
        // Day of year, 1-based.
        let calendar = Calendar(identifier: .gregorian)
        guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) else {
            return Result(sunrise: nil, sunset: nil)
        }

        let lat = coordinate.latitude
        let lng = coordinate.longitude

        let sunrise = solarEvent(dayOfYear: dayOfYear, latitude: lat, longitude: lng, rising: true, date: date)
        let sunset  = solarEvent(dayOfYear: dayOfYear, latitude: lat, longitude: lng, rising: false, date: date)

        // The NOAA algorithm normalizes UT to 0–24h and drops the day-rollover.
        // The clock-time is correct but the calendar day can be off by ±1 for
        // any longitude where the event crosses midnight UTC (SF sunset lands
        // on the next UTC day; Tokyo sunrise lands on the previous). Anchor
        // each event to the nearest copy of itself within ±12h of solar noon.
        let solarNoon = solarNoonUTC(for: date, longitude: lng)
        return Result(
            sunrise: sunrise.map { snap($0, near: solarNoon) },
            sunset:  sunset.map  { snap($0, near: solarNoon) }
        )
    }

    /// Solar noon in UTC for the calendar day of `date` at `longitude`.
    /// Solar noon ≈ 12:00 local solar time = (12 − lng/15) hours UTC.
    private static func solarNoonUTC(for date: Date, longitude: Double) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        var dc = DateComponents()
        dc.year = comps.year
        dc.month = comps.month
        dc.day = comps.day
        dc.hour = 0
        dc.timeZone = TimeZone(identifier: "UTC")
        let startOfDay = calendar.date(from: dc)!
        return startOfDay.addingTimeInterval((12.0 - longitude / 15.0) * 3600)
    }

    /// Shift `candidate` by whole days until it lies within ±12h of `anchor`.
    /// Both sunrise and sunset naturally fall inside this window because
    /// sunrise sits a few hours before solar noon and sunset a few hours after.
    private static func snap(_ candidate: Date, near anchor: Date) -> Date {
        var result = candidate
        let twelveHours: TimeInterval = 12 * 3600
        let day: TimeInterval = 24 * 3600
        while result.timeIntervalSince(anchor) < -twelveHours {
            result = result.addingTimeInterval(day)
        }
        while result.timeIntervalSince(anchor) > twelveHours {
            result = result.addingTimeInterval(-day)
        }
        return result
    }

    // Implementation of the "Sunrise/Sunset Algorithm" published by the US
    // Naval Observatory (Almanac for Computers, 1990). Returns nil at the
    // polar regions when the sun does not rise or set on the given date.
    private static func solarEvent(
        dayOfYear: Int,
        latitude: Double,
        longitude: Double,
        rising: Bool,
        date: Date
    ) -> Date? {
        let zenith = 90.833 // official sunrise/sunset zenith (includes refraction)
        let d2r = Double.pi / 180
        let r2d = 180 / Double.pi

        let lngHour = longitude / 15.0
        let t = Double(dayOfYear) + ((rising ? 6.0 : 18.0) - lngHour) / 24.0

        // Sun's mean anomaly
        let M = (0.9856 * t) - 3.289

        // Sun's true longitude
        var L = M + (1.916 * sin(M * d2r)) + (0.020 * sin(2 * M * d2r)) + 282.634
        L = (L + 360).truncatingRemainder(dividingBy: 360)

        // Right ascension
        var RA = r2d * atan(0.91764 * tan(L * d2r))
        RA = (RA + 360).truncatingRemainder(dividingBy: 360)

        // Right ascension into the same quadrant as L
        let Lquadrant  = floor(L / 90) * 90
        let RAquadrant = floor(RA / 90) * 90
        RA = RA + (Lquadrant - RAquadrant)
        RA = RA / 15.0 // to hours

        // Sun's declination
        let sinDec = 0.39782 * sin(L * d2r)
        let cosDec = cos(asin(sinDec))

        // Local hour angle
        let cosH = (cos(zenith * d2r) - (sinDec * sin(latitude * d2r))) / (cosDec * cos(latitude * d2r))
        if cosH > 1 || cosH < -1 {
            return nil // no rise/set at this latitude on this day
        }

        var H = rising ? (360 - r2d * acos(cosH)) : (r2d * acos(cosH))
        H = H / 15.0

        // Local mean time of event
        let T = H + RA - (0.06571 * t) - 6.622

        // Convert to UTC
        var UT = T - lngHour
        UT = ((UT.truncatingRemainder(dividingBy: 24)) + 24).truncatingRemainder(dividingBy: 24)

        // Build a Date in UTC for the same calendar day as `date`.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        var dc = DateComponents()
        dc.year = components.year
        dc.month = components.month
        dc.day = components.day
        dc.hour = Int(UT)
        dc.minute = Int((UT - Double(Int(UT))) * 60)
        dc.timeZone = TimeZone(identifier: "UTC")
        return calendar.date(from: dc)
    }
}
