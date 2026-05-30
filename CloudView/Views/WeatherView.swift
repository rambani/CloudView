import SwiftUI
import WeatherKit

// Swipeable Weather Panel with drag gestures
struct SwipeableWeatherPanel: View {
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var arViewModel: ARViewModel

    @State private var isExpanded = false // Start collapsed to show quirky statement
    @State private var dragOffset: CGFloat = 0
    private let expandedHeight: CGFloat = 450
    private let collapsedHeight: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drag handle
                DragHandle()
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Only allow dragging within bounds
                                let translation = value.translation.height
                                dragOffset = translation
                            }
                            .onEnded { value in
                                let translation = value.translation.height
                                let velocity = value.predictedEndTranslation.height - translation

                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    // Determine if we should expand or collapse
                                    if abs(velocity) > 50 {
                                        // Fast swipe - use velocity
                                        isExpanded = velocity < 0
                                    } else {
                                        // Slow drag - use threshold
                                        isExpanded = translation < 100
                                    }
                                    dragOffset = 0
                                }
                            }
                    )

                // Content
                if isExpanded {
                    // Full weather panel
                    if weatherService.locationPermissionDenied {
                        LocationDeniedView(weatherService: weatherService)
                            .transition(.opacity)
                    } else if weatherService.isLoading {
                        EnhancedMagicalLoadingView()
                    } else if let weather = weatherService.currentWeather {
                        MagicalWeatherContentView(weather: weather, forecast: weatherService.forecast)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        MagicalPlaceholderView()
                    }
                } else {
                    // Collapsed: Just quirky statement
                    if weatherService.locationPermissionDenied {
                        LocationDeniedCollapsedView()
                            .transition(.opacity)
                    } else if let weather = weatherService.currentWeather {
                        QuirkyWeatherStatement(
                            drawingName: arViewModel.lastDrawingName,
                            weather: weather,
                            forecast: weatherService.forecast,
                            appState: arViewModel.appState
                        )
                        .transition(.opacity)
                    } else {
                        // No weather data but show app state
                        AppStateMessage(appState: arViewModel.appState)
                            .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isExpanded ? expandedHeight : collapsedHeight)
            .offset(y: dragOffset)
        }
        .frame(height: isExpanded ? expandedHeight : collapsedHeight)
    }
}

// Drag handle component
struct DragHandle: View {
    var body: some View {
        VStack(spacing: 8) {
            // Visual drag bar with glassy style
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .white.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 45, height: 5)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
    }
}

// Quirky weather statement based on drawing + forecast + app state
struct QuirkyWeatherStatement: View {
    let drawingName: String?
    let weather: WeatherData
    let forecast: [ForecastData.ForecastItem]
    let appState: AppState

    private var quirkyStatement: String {
        // Check app state first for contextual messages
        switch appState {
        case .permissionsNeeded:
            return "Camera and location access needed to detect clouds 📸"

        case .arNotSupported:
            return "This device doesn't support AR - try a newer iPhone or iPad 📱"

        case .arSessionError:
            return "AR session paused - try restarting the app or checking permissions ⚠️"

        case .pointAtSky:
            return "Point your camera at the sky to find clouds ☁️"

        case .nightTime:
            return "Cloud drawings work best during daylight hours 🌙"

        case .movingTooFast:
            return "Hold steady - let me scan the clouds for you! 📸"

        case .noCloudsClearSky:
            return generateClearSkyMessage()

        case .noCloudsOvercast:
            return "Waiting for some interesting cloud formations to appear..."

        case .noWeatherData:
            return "Point your phone at the clouds to create magical drawings! ✨"

        case .scanning:
            // Check if we have a drawing
            if let drawing = drawingName {
                let (trend, _) = analyzeWeatherTrend()
                return generateQuirkyStatement(for: drawing, trend: trend)
            } else {
                // No drawing yet, but scanning - check weather conditions
                return generateNoCloudWeatherMessage()
            }
        }
    }

    private func generateClearSkyMessage() -> String {
        let temp = Int(weather.main.temp)
        let condition = weather.weather.first?.main.lowercased() ?? "clear"

        if condition.contains("clear") || condition.contains("sun") {
            if temp > 75 {
                return "Beautiful clear skies at \(temp)° - enjoy the sunshine! ☀️"
            } else if temp > 60 {
                return "Gorgeous blue skies at \(temp)° - perfect day outside! 🌤️"
            } else {
                return "Crisp clear day at \(temp)° - not a cloud in sight! ☀️"
            }
        } else {
            return "Clear conditions at \(temp)° - waiting for clouds to appear! 🌤️"
        }
    }

    private func generateNoCloudWeatherMessage() -> String {
        guard let condition = weather.weather.first?.main.lowercased() else {
            return "Scanning the skies - hold steady! ☁️"
        }

        let temp = Int(weather.main.temp)

        if condition.contains("clear") || condition.contains("sun") {
            return "Beautiful clear skies at \(temp)° - clouds make the best canvases! ☀️"
        } else if condition.contains("rain") {
            return "Rain at \(temp)° - clouds are hiding today, check back soon! 🌧️"
        } else if condition.contains("cloud") {
            return "Cloudy skies at \(temp)° - searching for distinct formations..."
        } else {
            return "Scanning at \(temp)° - point at the sky to find clouds! ☁️"
        }
    }

    private func analyzeWeatherTrend() -> (trend: WeatherTrend, details: WeatherDetails) {
        guard !forecast.isEmpty else { return (.stable, WeatherDetails()) }

        let currentTemp = weather.main.temp
        let futureTemps = forecast.prefix(6).map { $0.main.temp }

        // Check for rain
        let willRain = forecast.prefix(6).contains { item in
            item.weather.first?.main.lowercased().contains("rain") ?? false
        }

        if willRain {
            // Find when rain starts
            if let rainItem = forecast.first(where: { item in
                item.weather.first?.main.lowercased().contains("rain") ?? false
            }) {
                let hoursUntilRain = rainItem.date.timeIntervalSince(Date()) / 3600
                return (.rainComing, WeatherDetails(hoursAway: Int(hoursUntilRain)))
            }
        }

        // Check temperature trend
        let avgFutureTemp = futureTemps.reduce(0, +) / Double(futureTemps.count)
        let tempDiff = avgFutureTemp - currentTemp
        let maxTemp = futureTemps.max() ?? currentTemp

        if tempDiff > 5 {
            return (.gettingWarmer, WeatherDetails(targetTemp: Int(maxTemp), tempChange: Int(tempDiff)))
        } else if tempDiff < -5 {
            let minTemp = futureTemps.min() ?? currentTemp
            return (.gettingColder, WeatherDetails(targetTemp: Int(minTemp), tempChange: Int(abs(tempDiff))))
        }

        // Check for storms
        let isStormy = forecast.prefix(6).contains { item in
            let condition = item.weather.first?.main.lowercased() ?? ""
            return condition.contains("storm") || condition.contains("thunder")
        }

        if isStormy {
            if let stormItem = forecast.first(where: { item in
                let condition = item.weather.first?.main.lowercased() ?? ""
                return condition.contains("storm") || condition.contains("thunder")
            }) {
                let hoursUntilStorm = stormItem.date.timeIntervalSince(Date()) / 3600
                return (.stormyComing, WeatherDetails(hoursAway: Int(hoursUntilStorm)))
            }
        }

        // Check wind
        if weather.wind.speed > 10 {
            return (.windy, WeatherDetails(windSpeed: Int(weather.wind.speed)))
        }

        return (.stable, WeatherDetails(currentTemp: Int(currentTemp)))
    }

    private func generateQuirkyStatement(for drawing: String, trend: WeatherTrend) -> String {
        let drawingLower = drawing.lowercased()
        let details = analyzeWeatherTrend().details

        // Generate contextual statements based on drawing and weather
        switch trend {
        case .rainComing:
            let hours = details.hoursAway ?? 2
            let timeStr = hours <= 1 ? "within the hour" : "in the next \(hours) hours"

            if drawingLower.contains("surf") || drawingLower.contains("swim") {
                return "Better grab your board - waves incoming with rain \(timeStr)! 🌊"
            } else if drawingLower.contains("cat") || drawingLower.contains("lion") || drawingLower.contains("tiger") {
                return "Time to find some shelter - rain drops expected \(timeStr)! 🌧️"
            } else if drawingLower.contains("paint") || drawingLower.contains("draw") || drawingLower.contains("art") {
                return "Better pack up the easel - precipitation \(timeStr)! 🎨"
            } else if drawingLower.contains("garden") || drawingLower.contains("flower") || drawingLower.contains("plant") {
                return "The garden will love this - rain showers \(timeStr)! 🌱"
            } else {
                return "Umbrellas recommended - rain moving in \(timeStr)! ☔"
            }

        case .gettingWarmer:
            let targetTemp = details.targetTemp ?? 75
            let change = details.tempChange ?? 8

            if drawingLower.contains("snow") || drawingLower.contains("ski") || drawingLower.contains("polar") {
                return "Time to get off the slopes - temperatures climbing to \(targetTemp)° soon! ⛷️"
            } else if drawingLower.contains("ice") || drawingLower.contains("frost") {
                return "Things are melting fast - warming up \(change) degrees to \(targetTemp)°! 🧊"
            } else if drawingLower.contains("surf") || drawingLower.contains("beach") || drawingLower.contains("swim") {
                return "Perfect beach weather incoming - heating up to \(targetTemp)°! 🏖️"
            } else if drawingLower.contains("ice cream") || drawingLower.contains("popsicle") {
                return "Now we're talking - temperatures rising to \(targetTemp)°! 🍦"
            } else {
                return "Warming trend ahead - expect \(targetTemp)° by this afternoon! ☀️"
            }

        case .gettingColder:
            let targetTemp = details.targetTemp ?? 45
            let change = details.tempChange ?? 8

            if drawingLower.contains("snow") || drawingLower.contains("ski") {
                return "Perfect slope conditions - dropping \(change) degrees to \(targetTemp)°! ❄️"
            } else if drawingLower.contains("hot") || drawingLower.contains("fire") || drawingLower.contains("summer") {
                return "Time to cool off - temperatures falling to \(targetTemp)° today! 🧊"
            } else if drawingLower.contains("tropical") || drawingLower.contains("beach") {
                return "Grab a jacket - cooling down \(change) degrees to \(targetTemp)°! 🧥"
            } else if drawingLower.contains("coffee") || drawingLower.contains("tea") || drawingLower.contains("cocoa") {
                return "Perfect sipping weather - dropping to a crisp \(targetTemp)°! ☕"
            } else {
                return "Bundle up - temperatures falling \(change) degrees to \(targetTemp)°! 🧣"
            }

        case .stormyComing:
            let hours = details.hoursAway ?? 3
            let timeStr = hours <= 1 ? "within the hour" : "in \(hours) hours"

            if drawingLower.contains("wizard") || drawingLower.contains("magic") {
                return "Powerful magic brewing - thunderstorms expected \(timeStr)! ⚡"
            } else if drawingLower.contains("sail") || drawingLower.contains("boat") || drawingLower.contains("ship") {
                return "Head to port - rough seas with storms \(timeStr)! ⛵"
            } else if drawingLower.contains("dragon") || drawingLower.contains("lightning") {
                return "Electricity in the air - lightning strikes \(timeStr)! 🐉"
            } else if drawingLower.contains("kite") || drawingLower.contains("fly") {
                return "Ground all aircraft - thunderstorms rolling in \(timeStr)! ⛈️"
            } else {
                return "Seek shelter - severe weather approaching \(timeStr)! ⚡"
            }

        case .windy:
            let windSpeed = details.windSpeed ?? 15

            if drawingLower.contains("kite") || drawingLower.contains("fly") {
                return "Excellent launch conditions - winds at \(windSpeed)mph! 🪁"
            } else if drawingLower.contains("sail") || drawingLower.contains("boat") {
                return "Full sails ahead - strong winds at \(windSpeed)mph! ⛵"
            } else if drawingLower.contains("sing") || drawingLower.contains("music") || drawingLower.contains("guitar") {
                return "Perfect singing weather - breezy winds at \(windSpeed)mph! 🎸"
            } else if drawingLower.contains("dance") || drawingLower.contains("ballet") {
                return "Graceful conditions - winds swirling at \(windSpeed)mph! 💃"
            } else {
                return "Hold onto your hat - winds gusting to \(windSpeed)mph! 💨"
            }

        case .stable:
            let temp = details.currentTemp ?? Int(weather.main.temp)

            if drawingLower.contains("perfect") || drawingLower.contains("paradise") {
                return "Living up to the name - beautiful \(temp)° conditions! ✨"
            } else {
                return "Gorgeous conditions holding steady at \(temp)°! ☀️"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Quirky statement at bottom
            Text(quirkyStatement)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity)
    }
}

// Simple app state message when no weather data available
struct AppStateMessage: View {
    let appState: AppState

    private var message: String {
        switch appState {
        case .permissionsNeeded:
            return "Camera and location access needed to detect clouds 📸"
        case .arNotSupported:
            return "This device doesn't support AR - try a newer iPhone or iPad 📱"
        case .arSessionError:
            return "AR session paused - try restarting the app ⚠️"
        case .pointAtSky:
            return "Point your camera at the sky to find clouds ☁️"
        case .nightTime:
            return "Cloud drawings work best during daylight hours 🌙"
        case .movingTooFast:
            return "Hold steady - let me scan the clouds for you! 📸"
        case .noCloudsClearSky, .noCloudsOvercast:
            return "Head outside and point at the sky to begin! ✨"
        case .noWeatherData, .scanning:
            return "Point your phone at the clouds to create magical drawings! ✨"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeatherDetails {
    var hoursAway: Int?
    var targetTemp: Int?
    var tempChange: Int?
    var windSpeed: Int?
    var currentTemp: Int?
}

enum WeatherTrend {
    case rainComing
    case gettingWarmer
    case gettingColder
    case stormyComing
    case windy
    case stable
}

// Legacy view for backward compatibility
struct WeatherView: View {
    @ObservedObject var weatherService: WeatherService

    var body: some View {
        VStack(spacing: 0) {
            if weatherService.isLoading {
                EnhancedMagicalLoadingView()
            } else if let weather = weatherService.currentWeather {
                MagicalWeatherContentView(weather: weather, forecast: weatherService.forecast)
            } else {
                MagicalPlaceholderView()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MagicalWeatherContentView: View {
    let weather: WeatherData
    let forecast: [ForecastData.ForecastItem]

    var body: some View {
        VStack(spacing: 0) {
            // Main weather display - glassmorphic design
            HStack(spacing: 20) {
                // Left: Temperature with emoji (animated)
                HStack(spacing: 12) {
                    if let weatherCondition = weather.weather.first {
                        FloatingWeatherEmoji(emoji: WeatherService.weatherEmoji(for: weatherCondition.id))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(weather.main.temp))°")
                            .font(.system(size: 56, weight: .thin, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        if let condition = weather.weather.first {
                            Text(condition.description.capitalized)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }

                Spacer()

                // Right: Additional details in pills
                VStack(alignment: .trailing, spacing: 10) {
                    WeatherPill(icon: "drop.fill", value: "\(weather.main.humidity)%", color: .cyan)
                    WeatherPill(icon: "wind", value: "\(Int(weather.wind.speed)) mph", color: .blue)
                    WeatherPill(icon: "thermometer.medium", value: "Feels \(Int(weather.main.feelsLike))°", color: .orange)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            // Temperature trend chart
            if !forecast.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.cyan.opacity(0.8))

                        Text("Temperature Trend")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    TemperatureChart(forecast: Array(forecast.prefix(8)))
                        .frame(height: 80)
                        .padding(.horizontal, 24)
                }
            }

            // Forecast timeline - glassmorphic cards
            if !forecast.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(forecast.prefix(8), id: \.dt) { item in
                            ForecastCard(item: item)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(
            ZStack {
                // Glassmorphic background with gradient
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.ultraThinMaterial)
                    )

                // Subtle border
                RoundedRectangle(cornerRadius: 32)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                // Magical sparkle effect in corner with animation
                MagicalSparkles()
            }
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)

        // WeatherKit TOS attribution — required by Apple when consuming
        // WeatherKit data. The view fetches the official Apple/data-vendor
        // logos and links to the legal pages on tap.
        WeatherAttributionLine()
            .padding(.bottom, 24)
    }
}

/// Apple's standard attribution view + the required link to the legal page.
/// Sits at the bottom of the expanded weather panel so it's visible whenever
/// the user is looking at weather data.
struct WeatherAttributionLine: View {
    @State private var attribution: WeatherAttribution?

    var body: some View {
        HStack(spacing: 6) {
            Spacer()
            if let attribution {
                Link(destination: attribution.legalPageURL) {
                    AsyncImage(url: attribution.combinedMarkLightURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 14)
                        } else {
                            Text("Weather").font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            } else {
                Text("Weather").font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .task {
            attribution = try? await WeatherKit.WeatherService.shared.attribution
        }
    }
}

struct WeatherPill: View {
    let icon: String
    let value: String
    let color: Color
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color.opacity(0.9))

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Capsule()
                    .fill(color.opacity(0.15))
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )

                // Subtle shimmer effect
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                color.opacity(0.2),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(
                Animation.linear(duration: 3.0)
                    .delay(Double.random(in: 0...2))
                    .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 200
            }
        }
    }
}

struct ForecastCard: View {
    let item: ForecastData.ForecastItem
    @State private var isPulsing = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: item.date)
    }

    private var isNow: Bool {
        let now = Date()
        let diff = abs(item.date.timeIntervalSince(now))
        return diff < 1800 // Within 30 minutes
    }

    var body: some View {
        VStack(spacing: 10) {
            // Time with pulse animation for "Now"
            ZStack {
                if isNow {
                    // Pulsing glow for "Now"
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0.5 : 1.0)
                }

                Text(isNow ? "Now" : timeString)
                    .font(.system(size: 12, weight: isNow ? .bold : .medium, design: .rounded))
                    .foregroundColor(isNow ? .yellow : .white.opacity(0.8))
            }
            .onAppear {
                if isNow {
                    withAnimation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                }
            }

            // Weather emoji
            if let weather = item.weather.first {
                Text(WeatherService.weatherEmoji(for: weather.id))
                    .font(.system(size: 32))
            }

            // Temperature
            Text("\(Int(item.main.temp))°")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            // Temperature change indicator
            if let change = getTemperatureChange() {
                HStack(spacing: 2) {
                    Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(abs(change))°")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundColor(change > 0 ? .orange.opacity(0.8) : .cyan.opacity(0.8))
            }
        }
        .frame(width: 68)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    isNow ?
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(0.15),
                            Color.orange.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ) :
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isNow ?
                    Color.yellow.opacity(0.4) :
                    Color.white.opacity(0.2),
                    lineWidth: isNow ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private func getTemperatureChange() -> Int? {
        // This would compare with previous forecast item
        // For now, return nil as we don't have that data easily accessible
        return nil
    }
}

struct MagicalPlaceholderView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: .spacing_md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cloudBlue.opacity(0.3), Color.skyMist.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LinearGradient.cloudoodleSky)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.gentle, value: isAnimating)
                    .floating(duration: 2.5, distance: 4)
            }

            VStack(alignment: .leading, spacing: .spacing_xs) {
                Text("Point at the sky")
                    .font(.cloudoodleBody)
                    .foregroundColor(.white)

                Text("Discover clouds and weather")
                    .font(.cloudoodleCaption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(.spacing_lg)
        .background(
            RoundedRectangle(cornerRadius: .radius_xl + 4)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: .radius_xl + 4)
                        .strokeBorder(
                            LinearGradient.glassShine,
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.glassShadow, radius: 20, x: 0, y: 10)
        .padding(.horizontal, .spacing_md)
        .padding(.bottom, .spacing_xl)
        .onAppear {
            isAnimating = true
        }
    }
}

struct FloatingWeatherEmoji: View {
    let emoji: String

    var body: some View {
        Text(emoji)
            .font(.system(size: 64))
            .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 0)
            .floating(duration: 2.5, distance: 8)
    }
}

struct MagicalSparkles: View {
    @State private var sparkleOpacity: Double = 0.6
    @State private var sparkleScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack {
            HStack {
                Spacer()
                ZStack {
                    // Main sparkle
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.sunGlow, Color.cloudPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(sparkleOpacity)
                        .scaleEffect(sparkleScale)
                        .rotationEffect(.degrees(rotationAngle))

                    // Background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.sunGlow.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .scaleEffect(sparkleScale)
                }
                .padding(.spacing_md)
                .onAppear {
                    // Breathing animation
                    withAnimation(.gentle) {
                        sparkleOpacity = 1.0
                        sparkleScale = 1.2
                    }

                    // Gentle rotation
                    withAnimation(
                        Animation.linear(duration: 8.0).repeatForever(autoreverses: false)
                    ) {
                        rotationAngle = 360
                    }
                }
            }
            Spacer()
        }
    }
}

struct TemperatureChart: View {
    let forecast: [ForecastData.ForecastItem]

    private var minTemp: Double {
        forecast.map { $0.main.temp }.min() ?? 0
    }

    private var maxTemp: Double {
        forecast.map { $0.main.temp }.max() ?? 100
    }

    private var tempRange: Double {
        max(maxTemp - minTemp, 10) // Minimum range of 10 degrees for visual clarity
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines (subtle)
                VStack(spacing: 0) {
                    ForEach(0..<3) { index in
                        if index > 0 {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 0.5)
                        }
                        if index < 2 {
                            Spacer()
                        }
                    }
                }

                // Temperature line chart
                let points = calculatePoints(in: geometry.size)

                // Gradient area under the line
                Path { path in
                    guard !points.isEmpty else { return }

                    path.move(to: CGPoint(x: points[0].x, y: geometry.size.height))
                    path.addLine(to: points[0])

                    for i in 1..<points.count {
                        path.addLine(to: points[i])
                    }

                    path.addLine(to: CGPoint(x: points[points.count - 1].x, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.3),
                            Color.orange.opacity(0.1),
                            Color.orange.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Temperature line
                Path { path in
                    guard !points.isEmpty else { return }

                    path.move(to: points[0])
                    for i in 1..<points.count {
                        path.addLine(to: points[i])
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )

                // Data points
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .stroke(Color.orange, lineWidth: 2)
                        )
                        .position(point)
                }

                // Temperature labels at key points (first, middle, last)
                ForEach([0, points.count / 2, points.count - 1], id: \.self) { index in
                    if index < forecast.count && index < points.count {
                        Text("\(Int(forecast[index].main.temp))°")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.8))
                            )
                            .position(x: points[index].x, y: max(12, points[index].y - 12))
                    }
                }
            }
        }
    }

    private func calculatePoints(in size: CGSize) -> [CGPoint] {
        guard !forecast.isEmpty else { return [] }

        let padding: CGFloat = 10
        let usableWidth = size.width - (padding * 2)
        let usableHeight = size.height - (padding * 2)

        return forecast.enumerated().map { index, item in
            let x = padding + (usableWidth * CGFloat(index) / CGFloat(max(forecast.count - 1, 1)))
            let normalizedTemp = (item.main.temp - minTemp) / tempRange
            let y = size.height - padding - (usableHeight * CGFloat(normalizedTemp))

            return CGPoint(x: x, y: y)
        }
    }
}

// Location permission denied views
struct LocationDeniedView: View {
    @ObservedObject var weatherService: WeatherService

    var body: some View {
        VStack(spacing: 24) {
            // Icon and message
            VStack(spacing: 16) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Text("Location Access Needed")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Weather requires your location to show accurate forecasts. The app still works for cloud drawings!")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.top, 40)

            // Open Settings button
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))

                    Text("Open Settings")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }
}

struct LocationDeniedCollapsedView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Weather unavailable - enjoy cloud watching! ☁️")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
    }
}

// Keep existing BlurView for compatibility
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
