import SwiftUI

struct WeatherView: View {
    @ObservedObject var weatherService: WeatherService

    var body: some View {
        VStack(spacing: 0) {
            if weatherService.isLoading {
                LoadingView()
            } else if let weather = weatherService.currentWeather {
                WeatherContentView(weather: weather, forecast: weatherService.forecast)
            } else {
                PlaceholderView()
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            BlurView(style: .systemUltraThinMaterialDark)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
        .padding()
    }
}

struct WeatherContentView: View {
    let weather: WeatherData
    let forecast: [ForecastData.ForecastItem]

    var body: some View {
        VStack(spacing: 12) {
            // Current weather
            HStack(alignment: .top, spacing: 16) {
                // Left side: Temperature and condition
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(Int(weather.main.temp))°")
                            .font(.system(size: 48, weight: .medium, design: .rounded))
                            .foregroundColor(.white)

                        if let weatherCondition = weather.weather.first {
                            Text(WeatherService.weatherEmoji(for: weatherCondition.id))
                                .font(.system(size: 36))
                        }
                    }

                    if let condition = weather.weather.first {
                        Text(condition.description.capitalized)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Text(weather.name)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Right side: Additional info
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 12))
                        Text("Feels like \(Int(weather.main.feelsLike))°")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 6) {
                        Image(systemName: "humidity")
                            .font(.system(size: 12))
                        Text("\(weather.main.humidity)%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 6) {
                        Image(systemName: "wind")
                            .font(.system(size: 12))
                        Text("\(Int(weather.wind.speed)) mph")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Forecast
            if !forecast.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(forecast.prefix(6), id: \.dt) { item in
                            ForecastItemView(item: item)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 70)
            }

            Spacer()
                .frame(height: 12)
        }
    }
}

struct ForecastItemView: View {
    let item: ForecastData.ForecastItem

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: item.date)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(timeString)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            if let weather = item.weather.first {
                Text(WeatherService.weatherEmoji(for: weather.id))
                    .font(.system(size: 24))
            }

            Text("\(Int(item.main.temp))°")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 50)
    }
}

struct LoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))

            Text("Loading weather...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(height: 80)
        .padding(.horizontal, 20)
    }
}

struct PlaceholderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.6))

            Text("Point at the sky to see weather")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(height: 80)
        .padding(.horizontal, 20)
    }
}

// Custom blur view using UIKit
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
