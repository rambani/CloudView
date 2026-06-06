import Foundation

/// Live URLs for the hosted Privacy Policy and Terms of Service. Until
/// these are hosted at a stable public URL, both stay `nil` and the
/// in-app `LegalView` renders the bundled markdown drafts instead.
///
/// When you have hosted URLs, fill these in. App Store Connect also
/// requires the privacy URL (Submission step, not optional), so the
/// constant has to be non-nil before the first submission.
enum LegalLinks {
    static let privacyURL: URL? = nil   // e.g., URL(string: "https://cloudoodle.app/privacy")
    static let termsURL:   URL? = nil   // e.g., URL(string: "https://cloudoodle.app/terms")
}
