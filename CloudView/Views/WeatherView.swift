import SwiftUI

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
                    if weatherService.isLoading {
                        MagicalLoadingView()
                    } else if let weather = weatherService.currentWeather {
                        MagicalWeatherContentView(weather: weather, forecast: weatherService.forecast)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        MagicalPlaceholderView()
                    }
                } else {
                    // Collapsed: Just quirky statement
                    if let weather = weatherService.currentWeather {
                        QuirkyWeatherStatement(
                            drawingName: arViewModel.lastDrawingName,
                            weather: weather,
                            forecast: weatherService.forecast
                        )
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

// Quirky weather statement based on drawing + forecast
struct QuirkyWeatherStatement: View {
    let drawingName: String?
    let weather: WeatherData
    let forecast: [ForecastData.ForecastItem]

    private var quirkyStatement: String {
        guard let drawing = drawingName else {
            return "Point your phone at the clouds to create magical drawings! ✨"
        }

        let trend = analyzeWeatherTrend()
        return generateQuirkyStatement(for: drawing, trend: trend)
    }

    private func analyzeWeatherTrend() -> WeatherTrend {
        guard !forecast.isEmpty else { return .stable }

        let currentTemp = weather.main.temp
        let futureTemps = forecast.prefix(6).map { $0.main.temp }

        // Check for rain
        let willRain = forecast.prefix(6).contains { item in
            item.weather.first?.main.lowercased().contains("rain") ?? false
        }

        if willRain {
            return .rainComing
        }

        // Check temperature trend
        let avgFutureTemp = futureTemps.reduce(0, +) / Double(futureTemps.count)
        let tempDiff = avgFutureTemp - currentTemp

        if tempDiff > 5 {
            return .gettingWarmer
        } else if tempDiff < -5 {
            return .gettingColder
        }

        // Check for storms
        let isStormy = forecast.prefix(6).contains { item in
            let condition = item.weather.first?.main.lowercased() ?? ""
            return condition.contains("storm") || condition.contains("thunder")
        }

        if isStormy {
            return .stormyComing
        }

        // Check wind
        if weather.wind.speed > 10 {
            return .windy
        }

        return .stable
    }

    private func generateQuirkyStatement(for drawing: String, trend: WeatherTrend) -> String {
        let drawingLower = drawing.lowercased()

        // Generate contextual statements based on drawing and weather
        switch trend {
        case .rainComing:
            if drawingLower.contains("penguin") || drawingLower.contains("duck") {
                return "This \(drawing) won't mind the rain, but you might want an umbrella! ☔"
            } else if drawingLower.contains("cat") || drawingLower.contains("lion") || drawingLower.contains("tiger") {
                return "This \(drawing) won't be happy about the incoming rain! 🌧️"
            } else if drawingLower.contains("surf") || drawingLower.contains("swim") {
                return "Perfect timing! This \(drawing) is ready for extra water! 🌊"
            } else {
                return "Better grab an umbrella - this \(drawing) sees rain clouds ahead! ☔"
            }

        case .gettingWarmer:
            if drawingLower.contains("snow") || drawingLower.contains("polar") || drawingLower.contains("penguin") {
                return "Things are heating up - this \(drawing) might need some ice! ☀️"
            } else if drawingLower.contains("surf") || drawingLower.contains("beach") || drawingLower.contains("swim") {
                return "Perfect weather ahead for this \(drawing)! 🌞"
            } else {
                return "Warming up nicely! This \(drawing) approves! ☀️"
            }

        case .gettingColder:
            if drawingLower.contains("snow") || drawingLower.contains("ski") || drawingLower.contains("polar") {
                return "This \(drawing) is thrilled - it's getting chilly! ❄️"
            } else if drawingLower.contains("tropical") || drawingLower.contains("beach") {
                return "Uh oh, cooling down! This \(drawing) might need a sweater! 🧥"
            } else {
                return "Bundle up! This \(drawing) feels the cold coming! ❄️"
            }

        case .stormyComing:
            if drawingLower.contains("dragon") || drawingLower.contains("wizard") {
                return "This \(drawing) is summoning a storm! ⚡"
            } else if drawingLower.contains("sail") || drawingLower.contains("boat") {
                return "Rough seas ahead! This \(drawing) should head to shore! ⛈️"
            } else {
                return "Storm's brewing! This \(drawing) sees lightning ahead! ⚡"
            }

        case .windy:
            if drawingLower.contains("kite") || drawingLower.contains("fly") || drawingLower.contains("bird") {
                return "Perfect flying weather for this \(drawing)! 🪁"
            } else if drawingLower.contains("sail") {
                return "Great winds for this \(drawing)! ⛵"
            } else {
                return "Hold on tight - this \(drawing) feels the wind! 💨"
            }

        case .stable:
            return "Beautiful weather for this \(drawing)! ✨"
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
                MagicalLoadingView()
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
        .padding(.bottom, 32)
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

struct MagicalLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            // Magical loading animation
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 40, height: 40)
                        .scaleEffect(isAnimating ? 1.5 : 0.5)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                            value: isAnimating
                        )
                }
            }
            .frame(height: 60)

            Text("Reading the sky...")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .onAppear {
            isAnimating = true
        }
    }
}

struct MagicalPlaceholderView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.3), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .cyan.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Point at the sky")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("Discover clouds and weather")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .onAppear {
            isAnimating = true
        }
    }
}

struct FloatingWeatherEmoji: View {
    let emoji: String
    @State private var isFloating = false

    var body: some View {
        Text(emoji)
            .font(.system(size: 64))
            .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 0)
            .offset(y: isFloating ? -8 : 0)
            .animation(
                Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear {
                isFloating = true
            }
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
                                colors: [.yellow, .orange],
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
                                colors: [.yellow.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .scaleEffect(sparkleScale)
                }
                .padding(16)
                .onAppear {
                    // Breathing animation
                    withAnimation(
                        Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                    ) {
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
