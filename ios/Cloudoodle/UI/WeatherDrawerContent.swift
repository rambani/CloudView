import SwiftUI

/// The contents of Cloudoodle's bottom weather drawer. Shared by
/// today's Polaroid view and the camera viewfinder so the swipe-up
/// gesture means the same thing everywhere.
///
/// Layout (peek → expanded):
///   • Optional action row at the very top (caller-supplied)
///   • "Right now" — current temperature + conditions phrase
///   • "Watchability · next 8h" — bar chart with peak hour highlighted
///   • "Light today" — sun position bar with sunrise/sunset stamps
///
/// The action row is a `@ViewBuilder` slot so callers can drop in
/// whatever's appropriate (a "Capture another" CTA for subscribers,
/// the "Tomorrow's sky awaits" hint for free users, nothing at all
/// from the camera viewfinder).
struct WeatherDrawerContent<ActionRow: View>: View {
    let weather: WeatherSnapshot?
    @ViewBuilder let actionRow: () -> ActionRow

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                actionRow()
                if let w = weather {
                    conditionsRow(w)
                    watchabilityChart(w)
                    sunBar(w)
                } else {
                    weatherUnavailable
                }
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    private func conditionsRow(_ w: WeatherSnapshot) -> some View {
        let cloudDesc: String
        let cloudQual: String
        switch w.cloudCoverPct {
        case ..<20:  cloudDesc = "Clear sky";         cloudQual = "few shapes to find"
        case ..<50:  cloudDesc = "Scattered cumulus"; cloudQual = "ideal for shapes"
        case ..<80:  cloudDesc = "Broken cloud";      cloudQual = "good canvas overhead"
        default:     cloudDesc = "Overcast";          cloudQual = "catch it quick"
        }

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Right now")
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(w.temperature)°")
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cloudDesc)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CV.Color.textPrimary)
                    Text("\(w.cloudCoverPct)% cover · \(cloudQual)")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textSecondary)
                }
                Spacer()
            }
        }
    }

    private func watchabilityChart(_ w: WeatherSnapshot) -> some View {
        let hours = w.hourlyWatchability
        let peak = hours.max(by: { $0.score < $1.score })

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Watchability · next 8h")
                Spacer()
                if let p = peak {
                    Text("peak \(p.label)")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textSecondary)
                }
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(hours.enumerated()), id: \.0) { _, h in
                    let isPeak = h.label == peak?.label
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 52)
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isPeak ? CV.Color.accent : Color.white.opacity(0.3))
                                .frame(height: max(4, 52 * h.score))
                        }
                        Text(h.label)
                            .font(.system(size: 10, weight: isPeak ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(isPeak ? CV.Color.textPrimary : CV.Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func sunBar(_ w: WeatherSnapshot) -> some View {
        let now = Date()
        let total = max(1, w.sunset.timeIntervalSince(w.sunrise))
        let elapsed = now.timeIntervalSince(w.sunrise)
        let progress = max(0, min(1, elapsed / total))

        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Light today")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 8)
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: CV.Color.accent.opacity(0.6), radius: 6)
                        .offset(x: geo.size.width * progress - 8)
                }
            }
            .frame(height: 18)
            HStack {
                Text(fmt.string(from: w.sunrise).lowercased())
                Spacer()
                Text(fmt.string(from: w.sunset).lowercased())
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(CV.Color.textTertiary)
        }
    }

    private var weatherUnavailable: some View {
        HStack(spacing: 10) {
            Image(systemName: "cloud.slash")
                .foregroundStyle(CV.Color.textTertiary)
            Text("Weather unavailable — check location access.")
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textSecondary)
        }
        .padding(.vertical, 6)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(CV.Color.textTertiary)
    }
}
