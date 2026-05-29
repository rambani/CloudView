import Foundation
import CoreLocation
import Combine

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

    // Inject your OpenWeatherMap API key via Info.plist (key: "OPEN_WEATHER_API_KEY").
    // Typically wired up through an .xcconfig that's gitignored or a CI secret —
    // never commit the key to source. Empty / unconfigured ⇒ no live weather:
    // DEBUG builds fall back to sample data so dev work isn't blocked; release
    // builds surface "weather unavailable" and log a loud warning at startup.
    private let apiKey: String = {
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPEN_WEATHER_API_KEY") as? String,
           !key.isEmpty,
           key != "YOUR_API_KEY_HERE" {
            return key
        }
        return ""
    }()
    var hasAPIKey: Bool { !apiKey.isEmpty }
    private let baseURL = "https://api.openweathermap.org/data/2.5"

    private var locationManager: CLLocationManager?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        if !hasAPIKey {
            print("⚠️  WeatherService: OPEN_WEATHER_API_KEY missing from Info.plist. " +
                  "Release builds will show 'weather unavailable'; DEBUG builds will show sample data.")
        }
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
            // Permission denied - use mock data
            locationPermissionDenied = true
            error = "Location access denied. Weather info unavailable."
            useMockData() // Fallback to mock data

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

        // Fallback to mock data
        useMockData()
    }

    func fetchWeather(for location: CLLocation) {
        guard hasAPIKey else {
            // No API key configured — surface mock data so the UI still works.
            useMockData()
            return
        }

        isLoading = true
        error = nil

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Fetch current weather
        fetchCurrentWeather(lat: lat, lon: lon)

        // Fetch forecast
        fetchForecast(lat: lat, lon: lon)
    }

    private func fetchCurrentWeather(lat: Double, lon: Double) {
        let urlString = "\(baseURL)/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            isLoading = false
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: WeatherData.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let err) = completion {
                        self?.error = "Failed to fetch weather: \(err.localizedDescription)"
                        self?.isLoading = false
                    }
                },
                receiveValue: { [weak self] weather in
                    self?.currentWeather = weather
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }

    private func fetchForecast(lat: Double, lon: Double) {
        let urlString = "\(baseURL)/forecast?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=imperial&cnt=8" // Next 8 intervals (24 hours)

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: ForecastData.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] forecastData in
                    self?.forecast = forecastData.list
                }
            )
            .store(in: &cancellables)
    }

    func requestLocationAndFetchWeather() {
        guard let locationManager = locationManager else { return }

        // Check if we have permission
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {

            // Start location updates
            locationManager.startUpdatingLocation()
        } else if locationManager.authorizationStatus == .notDetermined {
            // Request permission first
            locationManager.requestWhenInUseAuthorization()
        } else {
            // Permission denied - use mock data
            locationPermissionDenied = true
            error = "Location access denied. Weather info unavailable."
            useMockData()
        }
    }

    func retryLocationPermission() {
        // This will prompt the user to go to Settings if permission was denied
        checkLocationAuthorization()
    }

    // Helper to get weather emoji
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
    /// Stable sample weather + forecast for dev runs without a configured
    /// OpenWeatherMap key. Compiled out of release builds so production
    /// can never silently substitute fake data for real weather — on
    /// release the function instead leaves state nil and surfaces the
    /// existing "weather unavailable" UI.
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
        // Production: never invent weather. Clear any partial state and
        // let the existing nil-weather UI render an "unavailable" hint.
        currentWeather = nil
        forecast = []
        isLoading = false
        if error == nil {
            error = "Weather unavailable"
        }
        if !hasAPIKey {
            // Loud signal during App Store review / TestFlight builds in
            // case a release ships without OPEN_WEATHER_API_KEY configured.
            print("⚠️  Release build missing OPEN_WEATHER_API_KEY in Info.plist — weather will not populate.")
        }
        #endif
    }
}
