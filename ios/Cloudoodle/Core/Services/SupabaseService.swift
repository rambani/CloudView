import Foundation
import Supabase

enum SupabaseError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case uploadFailed(Error)
    case queryFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Configure Supabase URL and key in Settings."
        case .notAuthenticated: return "Sign in to share sightings."
        case .uploadFailed(let e): return "Upload failed: \(e.localizedDescription)"
        case .queryFailed(let e): return "Query failed: \(e.localizedDescription)"
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
        _ = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
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
        try await client.auth.signIn(email: email, password: password)
        await refreshSession()
    }

    func signOut() async throws {
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
    }

    func resetPassword(email: String) async throws {
        guard let client else { throw SupabaseError.notConfigured }
        try await client.auth.resetPasswordForEmail(email)
    }

    func deleteAccount() async throws {
        guard let client else { throw SupabaseError.notConfigured }
        guard currentUser != nil else { throw SupabaseError.notAuthenticated }
        // Edge Function deletes data via delete_user_account() RPC then removes the auth user.
        // We do not call the RPC directly — the Edge Function owns the whole sequence.
        try await client.functions.invoke("delete-account", options: .init())
        currentUser = nil
        isAuthenticated = false
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
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }

    // MARK: - Profile

    /// Best-effort availability check used during onboarding. Returns
    /// `true` if the row exists, `false` if it doesn't, and `false`
    /// (optimistic) on any network/auth error — better than blocking
    /// onboarding behind a transient hiccup. The `username` column is
    /// public-readable per migration 008.
    func isUsernameTaken(_ username: String) async -> Bool {
        guard let client else { return false }
        do {
            let rows: [TakenProbe] = try await client
                .from("profiles")
                .select("id")
                .eq("username", value: username)
                .limit(1)
                .execute()
                .value
            return !rows.isEmpty
        } catch {
            return false
        }
    }

    /// Tiny shape that matches the single `id` column we select in
    /// `isUsernameTaken` — full AppUser would require all the columns
    /// the public grant does NOT expose.
    private struct TakenProbe: Decodable { let id: UUID }

    func updateDeviceToken(_ token: String) async {
        guard let client, let userId = currentUser?.id else { return }
        let row: [String: AnyJSON] = ["device_token": .string(token)]
        try? await client.from("profiles")
            .update(row)
            .eq("id", value: userId.uuidString)
            .execute()
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

    // MARK: - Sightings

    func uploadSighting(
        _ sighting: CloudSighting,
        imageData: Data
    ) async throws -> CloudSighting {
        guard let client else { throw SupabaseError.notConfigured }
        guard isAuthenticated,
              let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }

        // Upload image to storage
        let filename = "\(userId)/\(sighting.id.uuidString).jpg"
        _ = try await client.storage
            .from("sighting-images")
            .upload(
                filename,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )

        let imageURL = try client.storage
            .from("sighting-images")
            .getPublicURL(path: filename)
            .absoluteString

        // Build drawing_paths as AnyJSON object for JSONB column
        let elementJSONs: [AnyJSON] = sighting.drawingElements.map { el in
            let pointsJSON: AnyJSON = .array(el.points.map { pair in
                .array(pair.map { .double($0) })
            })
            var obj: [String: AnyJSON] = [
                "points": pointsJSON,
                "smooth": .bool(el.smooth),
                "stroke_width": .double(el.strokeWidth)
            ]
            if let label = el.label { obj["label"] = .string(label) }
            return .object(obj)
        }
        let drawingPathsJSON: AnyJSON = .object([
            "elements": .array(elementJSONs),
            "label_x": .double(sighting.drawingLabelX),
            "label_y": .double(sighting.drawingLabelY)
        ])

        let row: [String: AnyJSON] = [
            "id": .string(sighting.id.uuidString),
            "user_id": .string(userId.uuidString),
            "image_url": .string(imageURL),
            "shape_name": .string(sighting.shapeName),
            "quip": .string(sighting.quip),
            "cloud_type": .string(sighting.cloudType),
            "weather_mood": .string(sighting.weatherMood),
            "watchability_score": .integer(sighting.watchabilityScore),
            "drawing_paths": drawingPathsJSON,
            "latitude": sighting.latitude.map { .double($0) } ?? .null,
            "longitude": sighting.longitude.map { .double($0) } ?? .null,
            "city": sighting.city.map { .string($0) } ?? .null,
            "country": sighting.country.map { .string($0) } ?? .null,
            "likes": .integer(0)
        ]

        try await client.from("sightings").insert(row).execute()

        // Increment user's total_sightings
        try await client.rpc("increment_sightings", params: ["user_id_input": userId.uuidString]).execute()

        // Rebuild the in-memory sighting with the server-assigned image URL
        // but preserve every field the caller supplied. The previous
        // shorthand called the analysis-based initializer, which silently
        // defaulted drawingElements / drawingLabelX / drawingLabelY back to
        // their initializer defaults (empty + 0.5 + 0.25) — drawing data
        // was lost on the in-memory return value even though the DB row
        // had it correctly. CaptureFlowView discards the return today, so
        // this is preventative; future callers that consume it (e.g. a
        // post-upload share/preview screen) will get the right values.
        return CloudSighting(
            id: sighting.id,
            userId: userId,
            imageURL: imageURL,
            localImageData: nil,
            analysis: sighting.analysis,
            drawingElements: sighting.drawingElements,
            drawingLabelX: sighting.drawingLabelX,
            drawingLabelY: sighting.drawingLabelY,
            latitude: sighting.latitude,
            longitude: sighting.longitude,
            city: sighting.city,
            country: sighting.country,
            likes: 0,
            isLikedByCurrentUser: false,
            createdAt: sighting.createdAt
        )
    }

    func fetchFeed(limit: Int = 30, offset: Int = 0) async throws -> [CloudSighting] {
        guard let client else { throw SupabaseError.notConfigured }
        let rows: [SightingRow] = try await client
            .from("sightings")
            .select("*")
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        let likedIds = await fetchLikedIds()
        return rows.map { $0.toSighting(isLiked: likedIds.contains($0.id)) }
    }

    func fetchNearbySightings(latitude: Double, longitude: Double, radiusKm: Double = 50) async throws -> [CloudSighting] {
        guard let client else { throw SupabaseError.notConfigured }
        let rows: [SightingRow] = try await client
            .rpc("sightings_within_radius", params: [
                "lat": latitude,
                "lon": longitude,
                "radius_km": radiusKm
            ])
            .execute()
            .value
        // Populate liked-by-current-user the same way fetchFeed does, so
        // SightingCards rendered from the nearby list show the correct
        // heart state and the like-toggle starts from the right value.
        let likedIds = await fetchLikedIds()
        return rows.map { $0.toSighting(isLiked: likedIds.contains($0.id)) }
    }

    func fetchCityStats() async throws -> [CityStats] {
        guard let client else { throw SupabaseError.notConfigured }
        struct CityRow: Codable {
            let city: String
            let country: String
            let count: Int
            let latitude: Double
            let longitude: Double
            let recentShapes: [String]
            enum CodingKeys: String, CodingKey {
                case city, country, count, latitude, longitude
                case recentShapes = "recent_shapes"
            }
        }
        let rows: [CityRow] = try await client
            .rpc("city_sighting_stats")
            .execute()
            .value
        return rows.map {
            CityStats(
                id: "\($0.city)-\($0.country)",
                city: $0.city,
                country: $0.country,
                count: $0.count,
                latitude: $0.latitude,
                longitude: $0.longitude,
                recentShapes: $0.recentShapes
            )
        }
    }

    func fetchUserSightings(userId: UUID, limit: Int = 50) async throws -> [CloudSighting] {
        guard let client else { throw SupabaseError.notConfigured }
        let rows: [SightingRow] = try await client
            .from("sightings")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        // Same fix as fetchNearbySightings — without this the profile grid
        // shows every heart in the unfilled state even on sightings the
        // viewer has liked.
        let likedIds = await fetchLikedIds()
        return rows.map { $0.toSighting(isLiked: likedIds.contains($0.id)) }
    }

    func reportSighting(id: UUID, reason: String) async throws {
        guard let client else { throw SupabaseError.notConfigured }
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        let row: [String: AnyJSON] = [
            "sighting_id": .string(id.uuidString),
            "reported_by": .string(userId.uuidString),
            "reason": .string(reason)
        ]
        try await client.from("sighting_reports").insert(row).execute()
    }

    func toggleLike(sightingId: UUID) async throws -> Bool {
        guard let client else { throw SupabaseError.notConfigured }
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        struct LikeResult: Codable { let liked: Bool }
        let result: LikeResult = try await client
            .rpc("toggle_like", params: [
                "p_sighting_id": sightingId.uuidString,
                "p_user_id": userId.uuidString
            ])
            .execute()
            .value
        return result.liked
    }

    private func fetchLikedIds() async -> Set<UUID> {
        guard let client, let userId = currentUser?.id else { return [] }
        struct LikeRow: Codable { let sightingId: UUID; enum CodingKeys: String, CodingKey { case sightingId = "sighting_id" } }
        let rows: [LikeRow] = (try? await client
            .from("sighting_likes")
            .select("sighting_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value) ?? []
        return Set(rows.map(\.sightingId))
    }
}
