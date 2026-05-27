import SwiftUI
import MapKit

struct CityMapView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @EnvironmentObject private var location: LocationService

    @State private var cityStats: [CityStats] = []
    @State private var isLoading = false
    @State private var selectedCity: CityStats?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                // User location
                UserAnnotation()

                // City clusters
                ForEach(cityStats) { city in
                    Annotation(city.city, coordinate: CLLocationCoordinate2D(
                        latitude: city.latitude,
                        longitude: city.longitude
                    )) {
                        CityPin(stats: city, isSelected: selectedCity?.id == city.id)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCity = selectedCity?.id == city.id ? nil : city
                                }
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapUserLocationButton() }
            .ignoresSafeArea()
            .tint(CV.Color.accent)

            // Selected city card
            if let city = selectedCity {
                CityDetailCard(stats: city) {
                    selectedCity = nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }

            // Header
            VStack {
                ZStack {
                    Color.black.opacity(0.001) // hit area
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cloud Map")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(CV.Color.textPrimary)
                            Text("\(cityStats.count) cities scouting")
                                .font(CV.Font.caption)
                                .foregroundStyle(CV.Color.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    .padding(.bottom, 16)
                }
                .background(.ultraThinMaterial)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
        .task {
            await loadStats()
            centerOnUser()
        }
    }

    private func loadStats() async {
        isLoading = true
        do {
            cityStats = try await supabase.fetchCityStats()
        } catch {}
        isLoading = false
    }

    private func centerOnUser() {
        if let loc = location.currentLocation {
            cameraPosition = .region(MKCoordinateRegion(
                center: loc.coordinate,
                latitudinalMeters: 200_000,
                longitudinalMeters: 200_000
            ))
        }
    }
}

// MARK: - City Pin
private struct CityPin: View {
    let stats: CityStats
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isSelected ? CV.Color.accent : .white.opacity(0.85))
                    .frame(width: pinSize, height: pinSize)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                Text("\(stats.count)")
                    .font(.system(size: pinSize > 40 ? 13 : 10, weight: .bold))
                    .foregroundStyle(isSelected ? .black : .black.opacity(0.7))
            }
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)

            if isSelected {
                Text(stats.city)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.black.opacity(0.6)))
            }
        }
    }

    private var pinSize: CGFloat {
        let base = 28.0
        let extra = min(Double(stats.count) * 2.0, 20.0)
        return base + extra
    }
}

// MARK: - City Detail Card
private struct CityDetailCard: View {
    let stats: CityStats
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(stats.city)
                        .font(CV.Font.headline)
                        .foregroundStyle(CV.Color.textPrimary)
                    Text(stats.country)
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textTertiary)
                }
                Text("\(stats.count) sighting\(stats.count == 1 ? "" : "s")")
                    .font(CV.Font.shapeName)
                    .foregroundStyle(CV.Color.accent)

                if !stats.recentShapes.isEmpty {
                    HStack(spacing: 4) {
                        Text("Recent:")
                            .font(CV.Font.caption)
                            .foregroundStyle(CV.Color.textTertiary)
                        Text(stats.recentShapes.prefix(3).joined(separator: ", "))
                            .font(CV.Font.caption)
                            .foregroundStyle(CV.Color.textSecondary)
                    }
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CV.Color.textSecondary)
                    .padding(8)
                    .background(Circle().fill(CV.Color.glassBackground))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CV.Radius.lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CV.Radius.lg)
                        .strokeBorder(CV.Color.glassBorder, lineWidth: 0.5)
                )
        )
    }
}
