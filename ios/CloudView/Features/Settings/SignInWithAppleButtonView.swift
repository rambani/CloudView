import SwiftUI
import AuthenticationServices
import CryptoKit

/// Sign In with Apple wrapped for SwiftUI. Drives the
/// SupabaseService.signInWithApple flow with a fresh per-request nonce.
///
/// Apple's docs require:
/// - SHA-256 hash of a random nonce passed to ASAuthorizationAppleIDProvider
/// - the raw nonce passed unhashed to the OAuth provider for verification
///
/// This view holds the raw nonce in @State for the lifetime of the
/// authorization request, then passes it through to Supabase.
struct SignInWithAppleButtonView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @State private var currentNonce: String?
    @State private var signInError: String?

    var body: some View {
        VStack(spacing: 6) {
            SignInWithAppleButton(.signIn) { request in
                let nonce = Self.randomNonceString()
                currentNonce = nonce
                request.nonce = Self.sha256(nonce)
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handle(result: result) }
            }
            .signInWithAppleButtonStyle(.white)
            .accessibilityLabel("Sign in with Apple")

            if let signInError {
                Text(signInError)
                    .font(CV.Font.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @MainActor
    private func handle(result: Result<ASAuthorization, Error>) async {
        signInError = nil
        guard let nonce = currentNonce else {
            signInError = "Sign-in setup error — try again."
            return
        }
        do {
            let auth = try result.get()
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                signInError = "Apple didn't return an identity token."
                return
            }
            // Apple only returns the full name on FIRST sign-in. Pass it
            // through so SupabaseService can write it to the new profile;
            // subsequent sign-ins leave the existing profile alone.
            let name: String? = {
                guard let pn = credential.fullName else { return nil }
                let parts = [pn.givenName, pn.familyName].compactMap { $0 }
                let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                return joined.isEmpty ? nil : joined
            }()
            try await supabase.signInWithApple(
                idToken: idToken,
                nonce: nonce,
                appleUserName: name
            )
        } catch {
            // The system cancellation case yields a non-actionable error —
            // suppress it so we don't flash a "you got an error" toast at
            // a user who deliberately backed out of the system sheet.
            if (error as NSError).domain == ASAuthorizationError.errorDomain
                && (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            signInError = error.localizedDescription
        }
    }

    // MARK: - Nonce helpers (Apple's recommended snippet)

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
