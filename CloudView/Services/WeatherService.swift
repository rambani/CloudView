import Foundation
import CoreLocation
import Combine
import WeatherKit

// MARK: - Internal model
//
// The UI was originally written against an OpenWeatherMap-shaped response.
// We've migrated the data source to Apple's WeatherKit but kept this local
// model intact, mapping WeatherKit values into it. That keeps WeatherView /
// ContentView / the rest of the surface untouched.

struct WeatherData: Codable {
    let main: MainWeather
    let weather: [Weather]
    let wind: Wind
    let name: String

    struct MainWeather: Codable {
        let temp: Double
        let feelsLike: Double
        let humidity: Int

        enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case humidity
        }
    }

    struct Weather: Codable {
        let id: Int
        let main: String
        let description: String
        let icon: String
    }

    struct Wind: Codable {
        let speed: Double
    }
}

struct ForecastData: Codable {
    let list: [ForecastItem]

    struct ForecastItem: Codable {
        let dt: Int
        let main: WeatherData.MainWeather
        let weather: [WeatherData.Weather]

        var date: Date {
            Date(timeIntervalSince1970: TimeInterval(dt))
        }
    }
}

class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentWeather: WeatherData?
    @Published var forecast: [ForecastData.ForecastItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var locationPermissionDenied = false
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation? // Exposed for privacy-preserving scan reporting

    // WeatherKit handles auth via the app's signing identity — no API key in
    // source, no secret in the build, no key-rotation drill. Quota is 500K
    // calls/month per Apple Developer team, well above anything this app will
    // hit at one fetch per launch.
    private let weatherKit = WeatherKit.WeatherService.shared

    private var locationManager: CLLocationManager?
    private var cancellables = Set<AnyCancellable>()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyKilometer // Don't need exact location

        // Check initial authorization status
        checkLocationAuthorization()
    }

    private func checkLocationAuthorization() {
        guard let locationManager = locationManager else { return }

        locationPermissionStatus = locationManager.authorizationStatus

        switch locationManager.authorizationStatus {
        case .notDetermined:
            // First time - request permission
            locationManager.requestWhenInUseAuthorization()

        case .restricted, .denied:
            // Permission denied — surface that state to the UI.
            locationPermissionDenied = true
            error = "Location access denied. Weather info unavailable."
            useMockData() // DEBUG only; release clears state for placeholder

        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted - fetch location
            locationPermissionDenied = false
            requestLocationAndFetchWeather()

        @unknown default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        // Store current location for scan reporting
        currentLocation = location

        fetchWeather(for: location)

        // Stop updating location to save battery
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = "Location error: \(error.localizedDescription)"
        isLoading = false
        useMockData()
    }

    // MARK: - WeatherKit fetch

    func fetchWeather(for location: CLLocation) {
        isLoading = true
        error = nil

        Task { @MainActor in
            await fetchWeatherAsync(for: location)
        }
    }

    @MainActor
    private func fetchWeatherAsync(for location: CLLocation) async {
        do {
            // WeatherKit returns a single composite Weather object with
            // current conditions + hourly + daily forecasts in one call.
            let weather = try await weatherKit.weather(for: location)
            let cityName = await reverseGeocodedName(for: location)

            self.currentWeather = mapCurrent(weather.currentWeather, name: cityName)
            self.forecast = mapForecast(weather.hourlyForecast)
            self.isLoading = false
        } catch {
            print("WeatherKit fetch failed: \(error.localizedDescription)")
            self.error = "Couldn't reach weather service."
            self.isLoading = false
            useMockData()
        }
    }

    private func reverseGeocodedName(for location: CLLocation) async -> String {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                return placemark.locality
                    ?? placemark.administrativeArea
                    ?? placemark.country
                    ?? "Current Location"
            }
        } catch {
            // Geocoding hiccups (rate-limited, offline) shouldn't break weather.
        }
        return "Current Location"
    }

    func requestLocationAndFetchWeather() {
        guard let locationManager = locationManager else { return }

        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            // Permission denied — surface the LocationDeniedView state.
            locationPermissionDenied = true
            error = "Location access denied. Weather info unavailable."
            useMockData()
        }
    }

    func retryLocationPermission() {
        // This will prompt the user to go to Settings if permission was denied
        checkLocationAuthorization()
    }

    // MARK: - Mapping WeatherKit → local model

    /// User's locale-preferred temperature unit. US locales get Fahrenheit;
    /// the rest of the world gets Celsius. Falls back to °F if the locale
    /// hasn't declared a preference (uncommon on real devices).
    private var preferredTempUnit: UnitTemperature {
        switch Locale.current.measurementSystem {
        case .us:           return .fahrenheit
        case .metric, .uk:  return .celsius
        default:            return .fahrenheit
        }
    }

    /// US uses mph; UK uses mph too (for road speeds); rest of world uses km/h.
    private var preferredWindUnit: UnitSpeed {
        switch Locale.current.measurementSystem {
        case .us, .uk:      return .milesPerHour
        case .metric:       return .kilometersPerHour
        default:            return .milesPerHour
        }
    }

    private func mapCurrent(_ current: CurrentWeather, name: String) -> WeatherData {
        WeatherData(
            main: .init(
                temp: current.temperature.converted(to: preferredTempUnit).value,
                feelsLike: current.apparentTemperature.converted(to: preferredTempUnit).value,
                humidity: Int((current.humidity * 100).rounded())
            ),
            weather: [.init(
                id: openWeatherStyleID(for: current.condition),
                main: humanReadable(current.condition),
                description: humanReadable(current.condition),
                icon: current.symbolName
            )],
            wind: .init(speed: current.wind.speed.converted(to: preferredWindUnit).value),
            name: name
        )
    }

    private func mapForecast(_ hourly: Forecast<HourWeather>) -> [ForecastData.ForecastItem] {
        // Match the previous OpenWeatherMap shape: ~8 future intervals.
        let now = Date()
        return hourly
            .filter { $0.date > now }
            .prefix(8)
            .map { hour in
                ForecastData.ForecastItem(
                    dt: Int(hour.date.timeIntervalSince1970),
                    main: .init(
                        temp: hour.temperature.converted(to: preferredTempUnit).value,
                        feelsLike: hour.apparentTemperature.converted(to: preferredTempUnit).value,
                        humidity: Int((hour.humidity * 100).rounded())
                    ),
                    weather: [.init(
                        id: openWeatherStyleID(for: hour.condition),
                        main: humanReadable(hour.condition),
                        description: humanReadable(hour.condition),
                        icon: hour.symbolName
                    )]
                )
            }
    }

    // The UI's weatherEmoji(for:) was written for OpenWeatherMap IDs. Map each
    // WeatherKit condition to the closest OpenWeatherMap ID range so the emoji
    // lookup keeps working without UI changes.
    private func openWeatherStyleID(for condition: WeatherCondition) -> Int {
        switch condition {
        case .thunderstorms, .strongStorms, .isolatedThunderstorms,
             .scatteredThunderstorms, .tropicalStorm, .hurricane:
            return 200 // Thunderstorm
        case .drizzle, .freezingDrizzle, .sunShowers:
            return 300 // Drizzle
        case .rain, .heavyRain, .freezingRain, .sleet:
            return 500 // Rain
        case .snow, .heavySnow, .flurries, .sunFlurries,
             .wintryMix, .blizzard, .blowingSnow, .frigid:
            return 600 // Snow
        case .hail:
            return 622 // Snow (hail)
        case .foggy, .haze, .smoky, .blowingDust:
            return 701 // Atmosphere
        case .clear, .mostlyClear, .hot:
            return 800 // Clear
        case .partlyCloudy, .breezy, .windy:
            return 801 // Few clouds
        case .cloudy, .mostlyCloudy:
            return 803 // Broken/overcast clouds
        @unknown default:
            return 800
        }
    }

    private func humanReadable(_ condition: WeatherCondition) -> String {
        // condition.description is already user-friendly ("Partly Cloudy")
        // in modern WeatherKit. Provide a fallback just in case.
        condition.description.isEmpty
            ? String(describing: condition).capitalized
            : condition.description
    }

    // Helper to get weather emoji (kept verbatim — still called by the UI)
    static func weatherEmoji(for weatherId: Int) -> String {
        switch weatherId {
        case 200...232: return "⛈" // Thunderstorm
        case 300...321: return "🌦" // Drizzle
        case 500...531: return "🌧" // Rain
        case 600...622: return "❄️" // Snow
        case 701...781: return "🌫" // Atmosphere (fog, mist, etc.)
        case 800: return "☀️" // Clear
        case 801: return "🌤" // Few clouds
        case 802: return "⛅️" // Scattered clouds
        case 803...804: return "☁️" // Broken/overcast clouds
        default: return "🌡" // Default
        }
    }
}

extension WeatherService {
    /// Stable sample weather + forecast for dev runs. Compiled out of release
    /// builds — production never substitutes fake data for real weather.
    /// Release path clears state so the existing "unavailable" UI takes over.
    func useMockData() {
        #if DEBUG
        currentWeather = WeatherData(
            main: WeatherData.MainWeather(temp: 72, feelsLike: 70, humidity: 65),
            weather: [WeatherData.Weather(id: 801, main: "Clouds", description: "few clouds", icon: "02d")],
            wind: WeatherData.Wind(speed: 8.5),
            name: "Sample Weather"
        )

        forecast = [
            ForecastData.ForecastItem(
                dt: Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
                main: WeatherData.MainWeather(temp: 73, feelsLike: 71, humidity: 63),
                weather: [WeatherData.Weather(id: 800, main: "Clear", description: "clear sky", icon: "01d")]
            ),
            ForecastData.ForecastItem(
                dt: Int(Date().addingTimeInterval(7200).timeIntervalSince1970),
                main: WeatherData.MainWeather(temp: 75, feelsLike: 73, humidity: 60),
                weather: [WeatherData.Weather(id: 800, main: "Clear", description: "clear sky", icon: "01d")]
            ),
            ForecastData.ForecastItem(
                dt: Int(Date().addingTimeInterval(10800).timeIntervalSince1970),
                main: WeatherData.MainWeather(temp: 74, feelsLike: 72, humidity: 62),
                weather: [WeatherData.Weather(id: 801, main: "Clouds", description: "few clouds", icon: "02d")]
            )
        ]

        isLoading = false
        #else
        currentWeather = nil
        forecast = []
        isLoading = false
        if error == nil {
            error = "Weather unavailable"
        }
        #endif
    }
}
