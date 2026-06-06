import SwiftUI
import UIKit
import Observation

/// First-run flow state. Owns the step machine, the in-progress username
/// the user is choosing, and the cached results of permission requests.
///
/// Username is intentionally drafted *before* sign-up. Onboarding hands the
/// chosen username to UserDefaults via `@AppStorage("onboarding_username")`
/// and SupabaseService picks it up the first time the user signs up. This
/// keeps the "no account, no fuss" promise from the mocks intact while
/// still letting the username they chose end up on their profile row.
@Observable
@MainActor
final class OnboardingStore {
    var step: Step = .welcome
    var usernameDraft: String
    var usernameSuggestions: [String]

    var isCheckingUsername = false
    /// nil = unchecked, true = available, false = taken
    var usernameAvailable: Bool? = nil

    /// In-flight availability check, retained so successive keystrokes
    /// can cancel each other and we only hit Supabase once the user
    /// has paused typing.
    private var pendingCheck: Task<Void, Never>?

    init() {
        let suggestions = Self.makeSuggestions()
        self.usernameSuggestions = suggestions
        self.usernameDraft = suggestions.first ?? "skywatcher"
    }

    enum Step: Int, CaseIterable {
        case welcome, howItWorks, camera, location, notifications, username, demo, finished

        /// Pages that show the progress-dots header. Welcome/demo/finished
        /// are full-bleed and skip the chrome (matches mocks).
        var showsProgressBar: Bool {
            switch self {
            case .howItWorks, .camera, .location, .notifications, .username: return true
            default: return false
            }
        }

        /// 1-indexed position inside the progress-dot range, or nil if hidden.
        var progressIndex: Int? {
            switch self {
            case .howItWorks: return 1
            case .camera: return 2
            case .location: return 3
            case .notifications: return 4
            case .username: return 5
            default: return nil
            }
        }

        static var progressTotal: Int { 5 }
    }

    func advance() {
        guard let i = Step.allCases.firstIndex(of: step), i + 1 < Step.allCases.count else { return }
        step = Step.allCases[i + 1]
        Self.tap()
    }

    func goBack() {
        guard let i = Step.allCases.firstIndex(of: step), i > 0 else { return }
        step = Step.allCases[i - 1]
        Self.tap()
    }

    /// Soft selection-style haptic on page transitions — feels tactile
    /// without competing with the system permission sheets that fire
    /// their own feedback. Generated once and discarded; cheap.
    private static func tap() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }

    func pick(_ suggestion: String) {
        usernameDraft = suggestion
        usernameAvailable = nil   // re-check needed if you re-submit
    }

    /// Trim, lowercase, strip leading @, collapse internal whitespace.
    func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("@") { s.removeFirst() }
        return s.lowercased()
    }

    /// Best-effort availability check. Username column is public-readable
    /// (migration 008 hides device_token/coords but leaves username), so
    /// we can `select id from profiles where username = ?` without auth.
    /// Falls back to optimistic "available" on any error — better than
    /// blocking onboarding behind a network hiccup.
    func checkAvailability() async {
        let cleaned = normalize(usernameDraft)
        guard cleaned.count >= 3 else {
            usernameAvailable = nil
            return
        }
        isCheckingUsername = true
        defer { isCheckingUsername = false }
        let taken = await SupabaseService.shared.isUsernameTaken(cleaned)
        usernameAvailable = !taken
    }

    /// Debounced variant — call this from the text-field onChange handler.
    /// Cancels any in-flight check, waits `delayMS` ms, then runs the
    /// real check. If the user keeps typing, the cancellation cascades
    /// before any Supabase call goes out, so we don't spam the API once
    /// per keystroke.
    func scheduleAvailabilityCheck(delayMS: UInt64 = 350) {
        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayMS * 1_000_000)
            if Task.isCancelled { return }
            await self?.checkAvailability()
        }
    }

    /// Pool we draw from for the @sky.name chips. Keep it small enough that
    /// re-rolls feel curated, large enough that two users on the same
    /// device after a re-install don't collide every time.
    private static let suggestionPool: [String] = [
        "driftingdragon", "sleepywhale", "nimbus.nova", "puff.pilot",
        "sky.gazer", "cumulus.captain", "wisp.watcher", "halocaster",
        "anvil.crowd", "fairweather", "noctilucent", "altostratus.kid",
        "stratos.sam", "cirrusly", "cottonbank", "vapor.trail"
    ]

    private static func makeSuggestions() -> [String] {
        Array(suggestionPool.shuffled().prefix(5))
    }

    func reshuffleSuggestions() {
        usernameSuggestions = Self.makeSuggestions()
        usernameDraft = usernameSuggestions.first ?? "skywatcher"
        usernameAvailable = nil
    }
}
