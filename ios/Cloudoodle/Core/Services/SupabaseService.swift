import Foundation
import UIKit
import Supabase

enum SupabaseError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case uploadFailed(Error)
    case queryFailed(Error)
    case developFailed(Error)

    var errorDescription: String? {
        switch self {
        // In release builds there's nothing the user can do about a
        // missing backend config (the DEBUG-only Settings fields are
        // gone) — keep the copy honest about whose problem it is.
        case .notConfigured: return "Cloudoodle's backend isn't set up on this build. Please try again later."
        case .notAuthenticated: return "Sign in to share sightings."
        case .uploadFailed(let e): return "Upload failed: \(e.localizedDescription)"
        case .queryFailed(let e): return "Query failed: \(e.localizedDescription)"
        case .developFailed(let e): return "Couldn't develop this sky: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    @Published var currentUser: AppUser?
    @Published var isAuthenticated = false

    private var client: SupabaseClient?

    private var supabaseURL: String {
        if let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           !url.isEmpty, !url.hasPrefix("$(") { return url }
        return UserDefaults.standard.string(forKey: "supabase_url") ?? ""
    }
    private var supabaseKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
           !key.isEmpty, !key.hasPrefix("$(") { return key }
        return UserDefaults.standard.string(forKey: "supabase_anon_key") ?? ""
    }

    var isConfigured: Bool {
        !supabaseURL.isEmpty && !supabaseKey.isEmpty &&
        URL(string: supabaseURL) != nil
    }

    func configure() {
        guard isConfigured,
              let url = URL(string: supabaseURL) else { return }
        client = SupabaseClient(supabaseURL: url, supabaseKey: supabaseKey)
        Task { await refreshSession() }
    }

    // MARK: - Auth

    func signUp(email: String, password: String, username: String) async throws {
        guard let client else { throw SupabaseError.notConfigured }
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            let userId = response.user.id
            // Prefer an explicitly-typed username from the AuthForm; fall
            // back to the onboarding draft if the caller passed empty
            // (e.g. a future no-username flow that defers to onboarding).
            let chosen = username.isEmpty
                ? (UserDefaults.standard.string(forKey: "onboarding_username") ?? "")
                : username
            try await upsertProfile(id: userId, username: chosen)
            await refreshSession()
            Telemetry.signUp(success: true, method: .email)
        } catch {
            Telemetry.signUp(success: false, method: .email, error: error)
            throw error
        }
    }

    /// Sign in with Apple — exchanges the identity token from
    /// ASAuthorizationAppleIDProvider for a Supabase session via the
    /// built-in Apple OAuth provider (must also be enabled in Supabase
    /// Dashboard → Authentication → Providers → Apple).
    ///
    /// Apple only returns the user's name/email on the FIRST sign-in;
    /// callers should pass them through so we can write them into the
    /// profile row. On subsequent sign-ins both will be nil and the
    /// existing profile is left alone.
    func signInWithApple(
        idToken: String,
        nonce: String?,
        appleUserName: String?
    ) async throws {
        guard let client else { throw SupabaseError.notConfigured }
        do {
            _ = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            Telemetry.signIn(success: true, method: .apple)
        } catch {
            Telemetry.signIn(success: false, method: .apple, error: error)
            throw error
        }
        // First-time signers don't have a profile row yet — the
        // handle_new_user trigger inserts one with a sensible default
        // username (from the JWT's email). Prefer, in order:
        //   1. The name Apple returned on FIRST sign-in (Apple omits
        //      it on subsequent sign-ins by design).
        //   2. The username the user drafted during onboarding and
        //      stashed in @AppStorage. Letting that flow through here
        //      means a brand-new account inherits the handle the user
        //      already picked, instead of the default placeholder.
        let onboardingDraft = UserDefaults.standard.string(forKey: "onboarding_username") ?? ""
        let chosenUsername: String? = {
            if let n = appleUserName, !n.isEmpty { return n }
            if !onboardingDraft.isEmpty { return onboardingDraft }
            return nil
        }()
        if let name = chosenUsername {
            let userId = try await client.auth.session.user.id
            try? await upsertProfile(id: userId, username: name)
        }
        await refreshSession()
    }

    func signIn(email: String, password: String) async throws {
        guard let client else { throw SupabaseError.notConfigured }
        do {
            try await client.auth.signIn(email: email, password: password)
            await refreshSession()
            Telemetry.signIn(success: true, method: .email)
        } catch {
            Telemetry.signIn(success: false, method: .email, error: error)
            throw error
        }
    }

    func signOut() async throws {
        Telemetry.signOut()
        guard let client else { return }
        // Clear the device token on the outgoing profile before signing
        // out so a subsequent user signing in on this same device won't
        // receive pushes that were targeted at the previous account.
        // Without this, profile A keeps its device_token pointing at
        // this hardware indefinitely, and the notify-nearby-users
        // Edge Function will send "<shape> spotted near <A's city>"
        // pushes that land on the screen of whoever is logged in now.
        if let userId = currentUser?.id {
            let row: [String: AnyJSON] = ["device_token": .null]
            try? await client.from("profiles")
                .update(row)
                .eq("id", value: userId.uuidString)
                .execute()
        }
        try await client.auth.signOut()
        currentUser = nil
        isAuthenticated = false
        NotificationService.shared.invalidateTokenSync()
        // Auth state flipped — local reminder is now canonical again
        // for this device. Re-arm the local schedule.
        await DailyReminderService.shared.rescheduleIfNeeded()
    }

    func resetPassword(email: String) async throws {
        guard let client else { throw SupabaseError.notConfigured }
        try await client.auth.resetPasswordForEmail(email)
    }

    func deleteAccount() async throws {
        guard let client else { throw SupabaseError.notConfigured }
        guard currentUser != nil else { throw SupabaseError.notAuthenticated }
        do {
            // Edge Function deletes data via delete_user_account() RPC then removes the auth user.
            // We do not call the RPC directly — the Edge Function owns the whole sequence.
            try await client.functions.invoke("delete-account", options: .init())
            currentUser = nil
            isAuthenticated = false
            Telemetry.deleteAccount(success: true)
        } catch {
            Telemetry.deleteAccount(success: false, error: error)
            throw error
        }
    }

    private func refreshSession() async {
        guard let client else { return }
        do {
            let session = try await client.auth.session
            let profile = try await fetchProfile(id: session.user.id)
            currentUser = profile
            isAuthenticated = true
            // If the user granted notification permission before signing
            // in, the device token was captured in NotificationService
            // but the original syncDeviceToken() call from AppDelegate
            // would have early-returned (no currentUser). Sync it now
            // that we have one. Cheap no-op when the token isn't set yet.
            await NotificationService.shared.syncDeviceToken()
            // Server push is now the canonical reminder sender — tell
            // DailyReminderService to drop its local schedule (and to
            // sync the current prefs up so the cron knows when to fire).
            await DailyReminderService.shared.rescheduleIfNeeded()
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }

    // MARK: - Profile

    /// Returns whether the token actually landed on the profile row.
    /// DailyReminderService uses this to decide if the server push is
    /// deliverable before it suppresses the local notification.
    @discardableResult
    func updateDeviceToken(_ token: String) async -> Bool {
        guard let client, let userId = currentUser?.id else { return false }
        let row: [String: AnyJSON] = ["device_token": .string(token)]
        do {
            try await client.from("profiles")
                .update(row)
                .eq("id", value: userId.uuidString)
                .execute()
            return true
        } catch {
            return false
        }
    }

    /// Sync the user's daily-reminder preferences + their local
    /// timezone up to their profile row. The `daily-reminders` edge
    /// function reads these on every cron tick to decide who's due
    /// for a personalized regional-aggregate push.
    ///
    /// Silent no-op if Supabase isn't configured or the user isn't
    /// signed in (signed-out users get the on-device local notification
    /// instead). Best-effort; failures are swallowed.
    func updateReminderPrefs(
        enabled: Bool,
        hour: Int,
        minute: Int
    ) async {
        guard let client, let userId = currentUser?.id else { return }
        let localTime = String(format: "%02d:%02d", hour, minute)
        let row: [String: AnyJSON] = [
            "reminder_enabled": .bool(enabled),
            "reminder_local_time": .string(localTime),
            "timezone": .string(TimeZone.current.identifier)
        ]
        try? await client.from("profiles")
            .update(row)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    /// Ensures we have an authenticated user before calling
    /// `developPolaroid`. If the user hasn't signed in (anonymous
    /// or real) yet, create an anonymous Supabase user — they get
    /// a stable user_id we can attribute scans + metadata to, and
    /// they can later "upgrade" to a real account via Sign In with
    /// Apple or email/password without losing their stack.
    ///
    /// Requires Anonymous Sign-Ins to be enabled in the Supabase
    /// Dashboard under Authentication → Providers → Anonymous.
    func signInAnonymouslyIfNeeded() async throws {
        guard let client else { throw SupabaseError.notConfigured }
        if currentUser != nil { return }

        // A session can exist even while `currentUser` is nil — e.g.
        // the profile fetch inside refreshSession() failed on a
        // transient network error. NEVER sign in anonymously over a
        // live session: `signInAnonymously()` mints a brand-new user
        // and REPLACES the current session, silently orphaning a real
        // account (or a prior anonymous identity and its server-side
        // attribution). Re-adopt the existing session instead.
        if let session = try? await client.auth.session {
            currentUser = (try? await fetchProfile(id: session.user.id))
                ?? Self.placeholderUser(id: session.user.id)
            isAuthenticated = true
            return
        }

        do {
            let session = try await client.auth.signInAnonymously()
            // Anonymous users get no handle_new_user trigger, so
            // without this upsert there's no profiles row — and the
            // device-token + reminder-pref updates (`.update().eq()`)
            // would silently match zero rows. The server's develop
            // path upserts too (ignoreDuplicates), as a backstop.
            try? await upsertProfile(
                id: session.user.id,
                username: "watcher-\(session.user.id.uuidString.prefix(8).lowercased())"
            )
            currentUser = (try? await fetchProfile(id: session.user.id))
                ?? Self.placeholderUser(id: session.user.id)
            isAuthenticated = true
            // The token may have been captured before any user
            // existed; now there's a profile row to attach it to.
            await NotificationService.shared.syncDeviceToken()
            await DailyReminderService.shared.rescheduleIfNeeded()
        } catch {
            throw SupabaseError.notAuthenticated
        }
    }

    /// Local stand-in when the profile row can't be fetched right
    /// now — keeps the session usable; the real row syncs later.
    private static func placeholderUser(id: UUID) -> AppUser {
        AppUser(
            id: id,
            username: "",
            avatarURL: nil,
            city: nil,
            totalSightings: 0,
            streakDays: 0,
            createdAt: Date()
        )
    }

    /// Result returned by the `develop-polaroid` edge function.
    /// Matches the JSON shape the function emits one-to-one.
    struct DevelopResult: Decodable {
        let shapeName: String
        /// Weather-aware one-liner tying the shape to the real
        /// conditions ("Better find shelter, dragon — rain rolls in
        /// within the hour."). Empty when the server's quip pass
        /// failed; callers fall back to the on-device generator.
        let quip: String?
        let cloudType: String
        let weatherMood: String
        let watchabilityScore: Int
        let developedImageBase64: String

        enum CodingKeys: String, CodingKey {
            case shapeName            = "shape_name"
            case quip
            case cloudType            = "cloud_type"
            case weatherMood          = "weather_mood"
            case watchabilityScore    = "watchability_score"
            case developedImageBase64 = "developed_image_base64"
        }
    }

    /// Server-side AI proxy. The cropped image goes to our edge
    /// function (`develop-polaroid`) which holds the Gemini and
    /// Gemini API key as a Supabase secret and returns the developed
    /// PNG plus the shape metadata in a single response.
    ///
    /// This is the canonical scan path. The previous direct-to-
    /// Gemini + OpenAI client code is gone; users no
    /// longer need to bring their own API keys.
    ///
    /// `crop` is the smart-cropped image (typically 1024×1024).
    /// `city` is best-effort — passed through to the metadata row
    /// the function inserts on the user's behalf, and reflected
    /// onto `profiles.city` for the daily-reminders aggregation.
    /// `recentShapes` (newest first) gives the AI variety pressure
    /// so it avoids repeating the user's recent creatures.
    /// `weatherSummary` is a compact human-readable line about the
    /// current conditions — it powers the weather-aware quip.
    func developPolaroid(
        crop: UIImage,
        city: String?,
        recentShapes: [String] = [],
        weatherSummary: String? = nil
    ) async throws -> DevelopResult {
        try await signInAnonymouslyIfNeeded()
        guard let client else { throw SupabaseError.notConfigured }
        guard let jpegData = crop.jpegData(compressionQuality: 0.88) else {
            throw SupabaseError.uploadFailed(URLError(.badURL))
        }
        let body: [String: AnyJSON] = [
            "image_base64": .string(jpegData.base64EncodedString()),
            "city": city.map { .string($0) } ?? .null,
            "recent_shapes": .array(recentShapes.prefix(7).map { .string($0) }),
            "weather_summary": weatherSummary.map { .string(String($0.prefix(300))) } ?? .null,
        ]
        do {
            let response: DevelopResult = try await client.functions
                .invoke("develop-polaroid", options: .init(body: body))
            return response
        } catch {
            throw SupabaseError.developFailed(error)
        }
    }

    private func upsertProfile(id: UUID, username: String) async throws {
        guard let client else { throw SupabaseError.notConfigured }
        let row: [String: AnyJSON] = [
            "id": .string(id.uuidString),
            "username": .string(username),
            "total_sightings": .integer(0),
            "streak_days": .integer(0)
        ]
        try await client.from("profiles").upsert(row).execute()
    }

    private func fetchProfile(id: UUID) async throws -> AppUser {
        guard let client else { throw SupabaseError.notConfigured }
        let response: [AppUser] = try await client
            .from("profiles")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let profile = response.first else {
            throw SupabaseError.queryFailed(URLError(.cannotParseResponse))
        }
        return profile
    }
}
