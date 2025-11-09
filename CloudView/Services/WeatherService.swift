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

class WeatherService: ObservableObject {
    @Published var currentWeather: WeatherData?
    @Published var forecast: [ForecastData.ForecastItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private let apiKey = "YOUR_API_KEY_HERE" // Users will need to add their own key
    private let baseURL = "https://api.openweathermap.org/data/2.5"

    private var locationManager: CLLocationManager?
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.requestWhenInUseAuthorization()
    }

    func fetchWeather(for location: CLLocation) {
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
        guard let location = locationManager?.location else {
            // Try to get location
            locationManager?.requestLocation()
            return
        }

        fetchWeather(for: location)
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

// Mock data for testing without API key
extension WeatherService {
    func useMockData() {
        currentWeather = WeatherData(
            main: WeatherData.MainWeather(temp: 72, feelsLike: 70, humidity: 65),
            weather: [WeatherData.Weather(id: 801, main: "Clouds", description: "few clouds", icon: "02d")],
            wind: WeatherData.Wind(speed: 8.5),
            name: "San Francisco"
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
    }
}
