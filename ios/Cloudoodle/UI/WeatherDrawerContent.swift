import SwiftUI
import UIKit
import CoreLocation

/// The contents of Cloudoodle's bottom weather drawer. Shared by
/// today's Polaroid view and the camera viewfinder so the swipe-up
/// gesture means the same thing everywhere.
///
/// Layout:
///   • PEEK (always visible) — the temperature as the headline
///     number paired with the weather-aware quip when one exists,
///     or the short conditions phrase otherwise. This is the TL;DR
///     of the moment, sized to read at a glance without expanding.
///   • EXPANDED (swipe up) — caller-supplied action row, full
///     watchability chart for the next 8 hours, sunrise/sunset arc,
///     and a fall-back conditions row.
///
/// The action row is a `@ViewBuilder` slot so callers can drop in
/// whatever's appropriate (a "Capture another" CTA for subscribers,
/// the "Tomorrow's sky awaits" hint for free users, nothing at all
/// from the camera viewfinder).
struct WeatherDrawerContent<ActionRow: View>: View {
    let weather: WeatherSnapshot?
    /// Optional weather-aware quip from the most recent Polaroid.
    /// nil from the camera viewfinder (nothing developed yet); set
    /// from today's view to whatever the AI wrote about today's
    /// shape against the conditions.
    var quip: String? = nil
    @ViewBuilder let actionRow: () -> ActionRow

    @EnvironmentObject private var location: LocationService

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                peekRow
                actionRow()
                if let w = weather {
                    watchabilityChart(w)
                    sunBar(w)
                }
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    // MARK: - Peek row (the always-visible TL;DR)

    /// Big temperature + the quip (or a short conditions phrase if
    /// there's no quip yet). This is what fits inside the drawer's
    /// resting peek height — by design, the user can read the
    /// "what's the sky like right now, and what does it mean" line
    /// without lifting a finger.
    @ViewBuilder
    private var peekRow: some View {
        if let w = weather {
            HStack(alignment: .top, spacing: 14) {
                Text("\(w.temperature)°")
                    .font(.system(size: 48, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                VStack(alignment: .leading, spacing: 4) {
                    if let quip, !quip.isEmpty {
                        Text(quip)
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(CV.Color.textPrimary.opacity(0.9))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(conditionsHeadline(w))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CV.Color.textPrimary)
                    }
                    Text(conditionsSubline(w))
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textSecondary)
                }
                Spacer(minLength: 0)
            }
        } else {
            weatherUnavailable
        }
    }

    private func conditionsHeadline(_ w: WeatherSnapshot) -> String {
        switch w.cloudCoverPct {
        case ..<20:  return "Clear sky"
        case ..<50:  return "Scattered cumulus"
        case ..<80:  return "Broken cloud"
        default:     return "Overcast"
        }
    }

    private func conditionsSubline(_ w: WeatherSnapshot) -> String {
        let qual: String
        switch w.cloudCoverPct {
        case ..<20:  qual = "few shapes to find"
        case ..<50:  qual = "ideal for shapes"
        case ..<80:  qual = "good canvas overhead"
        default:     qual = "catch it quick"
        }
        return "\(w.cloudCoverPct)% cover · \(qual)"
    }

    // MARK: - Expanded sections

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

    /// Weather requires a coarse location. When that's denied we
    /// can't recover from inside the app — surface the system
    /// Settings deep link so the user has a one-tap path.
    @ViewBuilder
    private var weatherUnavailable: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "cloud.slash")
                    .foregroundStyle(CV.Color.textTertiary)
                Text(unavailableMessage)
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if needsSystemSettings {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                        Text("Open iOS Settings")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(CV.Color.accentBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }

    private var needsSystemSettings: Bool {
        location.authorizationStatus == .denied
            || location.authorizationStatus == .restricted
    }

    private var unavailableMessage: String {
        switch location.authorizationStatus {
        case .denied, .restricted:
            return "Weather needs your location. Enable it in iOS Settings → Cloudoodle."
        case .notDetermined:
            return "Waiting on a location reading…"
        default:
            return "Weather unavailable right now. Try again in a moment."
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(CV.Color.textTertiary)
    }
}
