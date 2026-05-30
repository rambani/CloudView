import Foundation

/// Single source of truth for the community backend URL.
/// Overridable at build time by adding `CLOUDOODLE_BACKEND_URL` to Info.plist,
/// which lets debug/staging/prod builds point at different deployments without
/// touching code.
enum BackendConfig {
    static let baseURL: URL = {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "CLOUDOODLE_BACKEND_URL") as? String,
           let url = URL(string: configured) {
            return url
        }
        return URL(string: "https://cloud-view-backend.vercel.app")!
    }()

    static var reportScanURL: URL { baseURL.appendingPathComponent("api/report-scan") }
    static var registerDeviceURL: URL { baseURL.appendingPathComponent("api/register-device") }
    static var regionalActivityURL: URL { baseURL.appendingPathComponent("api/regional-activity") }
    static var deleteDeviceURL: URL { baseURL.appendingPathComponent("api/delete-device") }
}
