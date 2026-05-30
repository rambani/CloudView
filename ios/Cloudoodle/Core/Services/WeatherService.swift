import WeatherKit
import CoreLocation

struct WeatherSnapshot: Sendable {
    let temperature: Int          // °F
    let feelsLike: Int
    let windSpeed: Int            // mph
    let windDirection: String     // "SW"
    let humidity: Int             // 0-100
    let uvIndex: Int
    let cloudCoverPct: Int        // 0-100
    let visibilityMiles: Double
    let dewPoint: Int             // °F
    let sunrise: Date
    let sunset: Date
    let hourlyWatchability: [(label: String, score: Double)]  // next 8h
    let weekAhead: [DayForecast]
    let precipAlert: String?      // "Rain in ~30m" or nil
}

struct DayForecast: Sendable {
    let dayName: String
    let skyDescription: String
    let bestWindow: String        // "11a–2p" or "—"
    let highTemp: Int
}

actor WeatherService {
    static let shared = WeatherService()
    private let wx = WeatherKit.WeatherService()

    func fetch(for location: CLLocation?) async -> WeatherSnapshot? {
        guard let location else { return nil }
        return await fetch(for: location)
    }

    func fetch(for location: CLLocation) async -> WeatherSnapshot? {
        do {
            let weather = try await wx.weather(for: location)
            return buildSnapshot(from: weather)
        } catch {
            return nil
        }
    }

    // MARK: - Snapshot assembly

    private func buildSnapshot(from weather: Weather) -> WeatherSnapshot {
        let current = weather.currentWeather
        let daily = weather.dailyForecast
        let hourly = weather.hourlyForecast

        let today = daily.first
        let sunrise = today?.sun.sunrise ?? Date()
        let sunset = today?.sun.sunset ?? Date()

        // Next 8 hours of watchability
        let now = Date()
        let upcoming = hourly.filter { $0.date >= now }.prefix(8)
        let hourlyWatchability: [(String, Double)] = upcoming.map { h in
            let score = watchabilityScore(
                cloudCover: h.cloudCover,
                precipChance: h.precipitationChance,
                date: h.date,
                sunrise: sunrise,
                sunset: sunset
            )
            return (hourLabel(h.date), score)
        }

        // Precipitation alert if rain is likely within 2 hours
        let next2h = hourly.filter { $0.date > now && $0.date <= now.addingTimeInterval(7200) }
        let precipAlert: String? = next2h.first(where: { $0.precipitationChance > 0.45 }).map { h in
            let mins = h.date.timeIntervalSince(now) / 60
            let rounded = max(15, Int(round(mins / 15) * 15))
            return "Rain in ~\(rounded)m"
        }

        // 3-day forecast (skip today)
        let weekAhead = Array(daily.dropFirst().prefix(3)).map { day -> DayForecast in
            DayForecast(
                dayName: dayName(for: day.date),
                skyDescription: skyDescription(for: day.condition),
                bestWindow: bestWindow(hourly: Array(hourly), for: day.date, sunrise: sunrise, sunset: sunset),
                highTemp: Int(day.highTemperature.converted(to: .fahrenheit).value.rounded())
            )
        }

        return WeatherSnapshot(
            temperature: Int(current.temperature.converted(to: .fahrenheit).value.rounded()),
            feelsLike: Int(current.apparentTemperature.converted(to: .fahrenheit).value.rounded()),
            windSpeed: Int(current.wind.speed.converted(to: .milesPerHour).value.rounded()),
            windDirection: compassString(current.wind.compassDirection),
            humidity: Int((current.humidity * 100).rounded()),
            uvIndex: current.uvIndex.value,
            cloudCoverPct: Int((current.cloudCover * 100).rounded()),
            visibilityMiles: current.visibility.converted(to: .miles).value,
            dewPoint: Int(current.dewPoint.converted(to: .fahrenheit).value.rounded()),
            sunrise: sunrise,
            sunset: sunset,
            hourlyWatchability: Array(hourlyWatchability),
            weekAhead: weekAhead,
            precipAlert: precipAlert
        )
    }

    // MARK: - Watchability score (0..1)

    private func watchabilityScore(
        cloudCover: Double,
        precipChance: Double,
        date: Date,
        sunrise: Date,
        sunset: Date
    ) -> Double {
        guard precipChance < 0.65 else { return 0.1 }

        // 20-65% cloud cover is the sweet spot for interesting shapes
        let coverScore: Double = {
            switch cloudCover {
            case 0..<0.1:    return 0.15
            case 0.1..<0.2:  return 0.35
            case 0.2..<0.65: return 0.7 + (0.3 * (cloudCover - 0.2) / 0.45)
            case 0.65..<0.85: return 1.0 - ((cloudCover - 0.65) / 0.2) * 0.75
            default:          return 0.2
            }
        }()

        // Golden hour bonus (~1h after sunrise or before sunset)
        let goldenBonus: Double = {
            let afterSunrise = date.timeIntervalSince(sunrise)
            let beforeSunset = sunset.timeIntervalSince(date)
            if (0..<3600).contains(afterSunrise) { return 0.3 }
            if (0..<3600).contains(beforeSunset) { return 0.3 }
            return 0
        }()

        return min(1.0, coverScore + goldenBonus)
    }

    // MARK: - Formatting helpers

    private func hourLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "ha"
        return fmt.string(from: date)
            .lowercased()
            .replacingOccurrences(of: "am", with: "a")
            .replacingOccurrences(of: "pm", with: "p")
    }

    private func dayName(for date: Date) -> String {
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: date)
    }

    private func skyDescription(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .hot:                                     return "clear skies"
        case .mostlyClear:                                     return "mostly clear"
        case .partlyCloudy:                                    return "lively cumulus"
        case .mostlyCloudy:                                    return "heavy cloud cover"
        case .cloudy:                                          return "overcast"
        case .foggy, .haze, .blowingDust, .smoky:             return "hazy"
        case .breezy, .windy:                                  return "breezy"
        case .drizzle, .sunShowers, .freezingDrizzle:          return "light rain"
        case .rain, .heavyRain, .freezingRain:                 return "rainy"
        case .thunderstorms, .isolatedThunderstorms,
             .scatteredThunderstorms, .strongStorms,
             .tropicalStorm, .hurricane:                       return "stormy"
        case .snow, .heavySnow, .blizzard, .blowingSnow,
             .sunFlurries, .flurries, .sleet, .wintryMix:      return "snow"
        case .hail:                                            return "hail"
        case .frigid:                                          return "frigid"
        @unknown default:                                      return "mixed skies"
        }
    }

    private func bestWindow(
        hourly: [HourWeather],
        for date: Date,
        sunrise: Date,
        sunset: Date
    ) -> String {
        let cal = Calendar.current
        let dayHours = hourly.filter { cal.isDate($0.date, inSameDayAs: date) }
        guard dayHours.count >= 2 else { return "—" }

        var bestStart: Date?
        var bestScore = 0.35   // minimum threshold

        for i in 0..<dayHours.count - 1 {
            let h1 = dayHours[i], h2 = dayHours[i + 1]
            let s1 = watchabilityScore(cloudCover: h1.cloudCover, precipChance: h1.precipitationChance, date: h1.date, sunrise: sunrise, sunset: sunset)
            let s2 = watchabilityScore(cloudCover: h2.cloudCover, precipChance: h2.precipitationChance, date: h2.date, sunrise: sunrise, sunset: sunset)
            let avg = (s1 + s2) / 2
            if avg > bestScore { bestScore = avg; bestStart = h1.date }
        }

        guard let start = bestStart else { return "—" }
        let end = start.addingTimeInterval(7200)
        let fmt = DateFormatter()
        fmt.dateFormat = "ha"
        let s = fmt.string(from: start).lowercased()
        let e = fmt.string(from: end).lowercased()
        return "\(s)–\(e)"
    }

    private func compassString(_ dir: Wind.CompassDirection) -> String {
        switch dir {
        case .north:          return "N"
        case .northNortheast: return "NNE"
        case .northeast:      return "NE"
        case .eastNortheast:  return "ENE"
        case .east:           return "E"
        case .eastSoutheast:  return "ESE"
        case .southeast:      return "SE"
        case .southSoutheast: return "SSE"
        case .south:          return "S"
        case .southSouthwest: return "SSW"
        case .southwest:      return "SW"
        case .westSouthwest:  return "WSW"
        case .west:           return "W"
        case .westNorthwest:  return "WNW"
        case .northwest:      return "NW"
        case .northNorthwest: return "NNW"
        @unknown default:     return "—"
        }
    }
}
