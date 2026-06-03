import Foundation
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var currentLocation: CLLocation?
    @Published var currentCity: String?
    @Published var currentCountry: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // Debounce reverse geocoding. CLGeocoder is rate-limited (~1 req/sec
    // per Apple's docs; exceed it and you start getting kCLErrorNetwork
    // back). A moving user streams locations several times a minute and
    // the city/country don't change that often — re-geocode only when
    // we've moved enough to plausibly cross a city boundary, AND not
    // more often than once every 30 s.
    private var lastGeocodedLocation: CLLocation?
    private var lastGeocodedAt: Date?
    private let geocodeMinSpacing: TimeInterval = 30
    private let geocodeMinMovementMeters: CLLocationDistance = 500

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func reverseGeocode(_ location: CLLocation) async -> (city: String?, country: String?) {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            return (placemark?.locality, placemark?.country)
        } catch {
            return (nil, nil)
        }
    }

    /// Returns true when a fresh reverse-geocode is justified for the
    /// given new location: either we've never geocoded one yet, the
    /// minimum interval has elapsed, OR the user has moved far enough
    /// that the city/country might have changed.
    private func shouldGeocode(_ location: CLLocation) -> Bool {
        guard let lastLoc = lastGeocodedLocation, let lastAt = lastGeocodedAt else {
            return true
        }
        if location.distance(from: lastLoc) >= geocodeMinMovementMeters {
            return true
        }
        return Date().timeIntervalSince(lastAt) >= geocodeMinSpacing
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            guard self.shouldGeocode(location) else { return }
            self.lastGeocodedLocation = location
            self.lastGeocodedAt = Date()
            let geo = await self.reverseGeocode(location)
            // Don't blank out existing city/country on a transient
            // geocoder failure — the previous value is more useful than
            // nil for the camera flow's "spotted near <city>" copy.
            if let city = geo.city { self.currentCity = city }
            if let country = geo.country { self.currentCountry = country }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse {
                manager.startUpdatingLocation()
            }
        }
    }
}
