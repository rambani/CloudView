import Foundation
import Sentry

/// Centralised breadcrumb sink. Every interesting event in the app
/// funnels through here so production crashes carry the user's path
/// into the failure — without it, a Sentry stack trace tells you what
/// crashed but not what they were doing.
///
/// Crumbs are no-ops when Sentry isn't initialised (no DSN configured)
/// so callers don't have to guard. The SDK silently drops calls in
/// that case.
enum Telemetry {

    // MARK: - Auth

    static func signUp(success: Bool, method: AuthMethod, error: Error? = nil) {
        let crumb = Breadcrumb(level: success ? .info : .warning, category: "auth")
        crumb.type = "user"
        crumb.message = "sign-up \(success ? "succeeded" : "failed") via \(method.rawValue)"
        if let error { crumb.data = ["error": String(describing: error)] }
        SentrySDK.addBreadcrumb(crumb)
    }

    static func signIn(success: Bool, method: AuthMethod, error: Error? = nil) {
        let crumb = Breadcrumb(level: success ? .info : .warning, category: "auth")
        crumb.type = "user"
        crumb.message = "sign-in \(success ? "succeeded" : "failed") via \(method.rawValue)"
        if let error { crumb.data = ["error": String(describing: error)] }
        SentrySDK.addBreadcrumb(crumb)
    }

    static func signOut() {
        let crumb = Breadcrumb(level: .info, category: "auth")
        crumb.type = "user"
        crumb.message = "sign-out"
        SentrySDK.addBreadcrumb(crumb)
    }

    static func deleteAccount(success: Bool, error: Error? = nil) {
        let crumb = Breadcrumb(level: success ? .info : .error, category: "auth")
        crumb.type = "user"
        crumb.message = "delete-account \(success ? "succeeded" : "failed")"
        if let error { crumb.data = ["error": String(describing: error)] }
        SentrySDK.addBreadcrumb(crumb)
    }

    enum AuthMethod: String {
        case email
        case apple
    }

    // MARK: - Scan + upload

    static func scanAttempt() {
        let crumb = Breadcrumb(level: .info, category: "scan")
        crumb.type = "user"
        crumb.message = "scan started"
        SentrySDK.addBreadcrumb(crumb)
    }

    static func scanSuccess(shapeName: String) {
        let crumb = Breadcrumb(level: .info, category: "scan")
        crumb.message = "scan succeeded"
        crumb.data = ["shape": shapeName]
        SentrySDK.addBreadcrumb(crumb)
    }

    /// Tag scan failures with a short category so crash dashboards can
    /// group by error class without dumping raw user-facing strings.
    static func scanFailure(error: Error) {
        let crumb = Breadcrumb(level: .warning, category: "scan")
        crumb.message = "scan failed"
        crumb.data = ["category": Self.geminiCategory(error)]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func uploadStart() {
        let crumb = Breadcrumb(level: .info, category: "sighting")
        crumb.message = "upload started"
        SentrySDK.addBreadcrumb(crumb)
    }

    static func uploadFinish(success: Bool, error: Error? = nil) {
        let crumb = Breadcrumb(level: success ? .info : .warning, category: "sighting")
        crumb.message = "upload \(success ? "succeeded" : "failed")"
        if let error { crumb.data = ["error": String(describing: error)] }
        SentrySDK.addBreadcrumb(crumb)
    }

    // MARK: - Permissions

    static func locationGranted(_ granted: Bool) {
        let crumb = Breadcrumb(level: .info, category: "permission")
        crumb.message = "location \(granted ? "granted" : "denied")"
        SentrySDK.addBreadcrumb(crumb)
    }

    static func notificationsGranted(_ granted: Bool) {
        let crumb = Breadcrumb(level: .info, category: "permission")
        crumb.message = "notifications \(granted ? "granted" : "denied")"
        SentrySDK.addBreadcrumb(crumb)
    }

    static func cameraGranted(_ granted: Bool) {
        let crumb = Breadcrumb(level: .info, category: "permission")
        crumb.message = "camera \(granted ? "granted" : "denied")"
        SentrySDK.addBreadcrumb(crumb)
    }

    // MARK: - Helpers

    /// Short, low-cardinality label for the kind of scan failure
    /// observed. Keeps dashboards clean: a handful of distinct values
    /// instead of thousands of localized error strings.
    private static func geminiCategory(_ error: Error) -> String {
        if (error as NSError).domain == NSURLErrorDomain {
            return "network_error"
        }
        if let supabase = error as? SupabaseError {
            switch supabase {
            case .notConfigured:    return "backend_not_configured"
            case .notAuthenticated: return "auth_error"
            case .uploadFailed:     return "upload_failed"
            case .queryFailed:      return "query_failed"
            case .developFailed:    return "develop_failed"
            }
        }
        return "unknown"
    }
}
