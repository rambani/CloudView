import Foundation

/// Top-level UI state driving the contextual hint surface.
/// Owned by `ARViewModel`; observed by `ContentView`.
enum AppState {
    case scanning              // Normal scanning mode
    case noCloudsClearSky      // No clouds, but weather is clear/sunny
    case noCloudsOvercast      // No clouds, but weather is cloudy/rainy
    case pointAtSky            // Camera not pointing upward
    case nightTime             // Too dark / nighttime
    case movingTooFast         // Camera moving too much
    case noWeatherData         // Can't determine weather context
    case permissionsNeeded     // Camera/Location permissions required
    case arNotSupported        // Device doesn't support ARKit
    case arSessionError        // AR session failed or interrupted
}
