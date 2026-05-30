import SwiftUI
import MapKit

struct CityMapView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @EnvironmentObject private var location: LocationService

    @State private var cityStats: [CityStats] = []
    @State private var isLoading = false
    @State private var fetchError: Error?
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
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloud Map")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(CV.Color.textPrimary)
                        headerSubtitle
                    }
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .tint(CV.Color.textTertiary)
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // Empty / error overlay surfaced from the bottom so the map
            // chrome stays visible behind it.
            if let _ = fetchError, cityStats.isEmpty, !isLoading {
                fetchErrorBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if cityStats.isEmpty && !isLoading && fetchError == nil {
                emptyBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            await loadStats()
            centerOnUser()
        }
    }

    @ViewBuilder
    private var headerSubtitle: some View {
        if isLoading && cityStats.isEmpty {
            Text("Loading sightings…")
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textTertiary)
        } else if fetchError != nil && cityStats.isEmpty {
            Text("Couldn't load sightings")
                .font(CV.Font.caption)
                .foregroundStyle(.red.opacity(0.85))
        } else {
            Text("\(cityStats.count) cit\(cityStats.count == 1 ? "y" : "ies") scouting")
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textTertiary)
        }
    }

    private var emptyBanner: some View {
        VStack(spacing: 10) {
            Text("No sightings on the map yet")
                .font(CV.Font.headline)
                .foregroundStyle(CV.Color.textPrimary)
            Text("Add the first cloud and your pin appears here.")
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CV.Radius.lg)
                .fill(.ultraThinMaterial)
        )
    }

    private var fetchErrorBanner: some View {
        VStack(spacing: 12) {
            Text("Couldn't load sightings")
                .font(CV.Font.headline)
                .foregroundStyle(CV.Color.textPrimary)
            Text(fetchError?.localizedDescription ?? "Check your connection and try again.")
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadStats() }
            } label: {
                Text("Try again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: CV.Radius.md).fill(CV.Color.accent))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CV.Radius.lg)
                .fill(.ultraThinMaterial)
        )
    }

    private func loadStats() async {
        isLoading = true
        fetchError = nil
        do {
            cityStats = try await supabase.fetchCityStats()
        } catch {
            fetchError = error
        }
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
