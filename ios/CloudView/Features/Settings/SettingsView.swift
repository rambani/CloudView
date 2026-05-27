import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss

    // API keys
    @AppStorage("gemini_api_key") private var geminiKey = ""
    @AppStorage("supabase_url") private var supabaseURL = ""
    @AppStorage("supabase_anon_key") private var supabaseAnonKey = ""

    // Auth form
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false
    @State private var isAuthLoading = false
    @State private var authError: String?
    @State private var resetEmailSent = false
    @State private var isDeletingAccount = false

    // UI
    @State private var showAnthropicKey = false
    @State private var showSupabaseKey = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        // Gemini section
                        SettingsSection(title: "AI Analysis", icon: "brain") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Google AI Studio API Key")
                                    .font(CV.Font.caption)
                                    .foregroundStyle(CV.Color.textTertiary)
                                SecureRevealField(
                                    text: $geminiKey,
                                    isRevealed: $showAnthropicKey,
                                    placeholder: "AIza..."
                                )
                                HStack(spacing: 4) {
                                    Image(systemName: geminiKey.isEmpty ? "exclamationmark.circle" : "checkmark.circle")
                                        .foregroundStyle(geminiKey.isEmpty ? .orange : .green)
                                    Text(geminiKey.isEmpty
                                         ? "Free at aistudio.google.com — 1,500 scans/day"
                                         : "Gemini Flash active · quips generated on-device")
                                        .foregroundStyle(CV.Color.textTertiary)
                                }
                                .font(CV.Font.caption)
                            }
                        }

                        // Supabase section
                        SettingsSection(title: "Community Backend", icon: "server.rack") {
                            VStack(alignment: .leading, spacing: 12) {
                                LabeledField(label: "Supabase URL", placeholder: "https://xxx.supabase.co", text: $supabaseURL)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Anon Key")
                                        .font(CV.Font.caption)
                                        .foregroundStyle(CV.Color.textTertiary)
                                    SecureRevealField(
                                        text: $supabaseAnonKey,
                                        isRevealed: $showSupabaseKey,
                                        placeholder: "eyJ..."
                                    )
                                }
                                Button("Apply & Reconnect") {
                                    supabase.configure()
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(supabase.isConfigured ? CV.Color.accentBlue : CV.Color.textTertiary)
                                .disabled(!supabase.isConfigured)
                            }
                        }

                        // Auth section
                        SettingsSection(title: supabase.isAuthenticated ? "Account" : "Sign In", icon: "person.circle") {
                            if supabase.isAuthenticated, let user = supabase.currentUser {
                                AuthenticatedView(
                                    user: user,
                                    isDeleting: isDeletingAccount,
                                    onSignOut: { Task { try? await supabase.signOut() } },
                                    onDeleteAccount: { Task { await deleteAccount() } }
                                )
                            } else {
                                AuthForm(
                                    email: $email,
                                    password: $password,
                                    username: $username,
                                    isSignUp: $isSignUp,
                                    isLoading: isAuthLoading,
                                    error: authError,
                                    resetEmailSent: resetEmailSent,
                                    onSubmit: { Task { await authenticate() } },
                                    onForgotPassword: { Task { await sendPasswordReset() } }
                                )
                            }
                        }

                        // About
                        VStack(spacing: 4) {
                            Text("CloudView")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(CV.Color.textTertiary)
                            Text("Find shapes in the sky")
                                .font(CV.Font.caption)
                                .foregroundStyle(CV.Color.textTertiary.opacity(0.6))
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CV.Color.accentBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func authenticate() async {
        isAuthLoading = true
        authError = nil
        resetEmailSent = false
        do {
            if isSignUp {
                try await supabase.signUp(email: email, password: password, username: username)
            } else {
                try await supabase.signIn(email: email, password: password)
            }
        } catch {
            authError = error.localizedDescription
        }
        isAuthLoading = false
    }

    private func sendPasswordReset() async {
        guard !email.isEmpty else {
            authError = "Enter your email address above, then tap Forgot Password."
            return
        }
        isAuthLoading = true
        authError = nil
        do {
            try await supabase.resetPassword(email: email)
            resetEmailSent = true
        } catch {
            authError = error.localizedDescription
        }
        isAuthLoading = false
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        do {
            try await supabase.deleteAccount()
        } catch {
            // Account deletion failed — user is still signed in, show error
            authError = "Couldn't delete account: \(error.localizedDescription)"
        }
        isDeletingAccount = false
    }
}

// MARK: - Supporting Views

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CV.Color.textSecondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: CV.Radius.md)
                    .fill(Color(white: 0.1))
            )
        }
    }
}

private struct SecureRevealField: View {
    @Binding var text: String
    @Binding var isRevealed: Bool
    let placeholder: String

    var body: some View {
        HStack {
            if isRevealed {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            } else {
                SecureField(placeholder, text: $text)
                    .font(.system(.body, design: .monospaced))
            }
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(CV.Color.textTertiary)
            }
        }
        .foregroundStyle(CV.Color.textPrimary)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.06)))
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textTertiary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .foregroundStyle(CV.Color.textPrimary)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.06)))
        }
    }
}

private struct AuthenticatedView: View {
    let user: AppUser
    let isDeleting: Bool
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CV.Color.textPrimary)
                    Text("\(user.totalSightings) sightings · \(user.streakDays) day streak")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textTertiary)
                }
                Spacer()
                Button("Sign Out", action: onSignOut)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CV.Color.accentBlue)
            }

            Divider().overlay(Color.white.opacity(0.08))

            Button {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 6) {
                    if isDeleting {
                        ProgressView().tint(.red).scaleEffect(0.7)
                    }
                    Text(isDeleting ? "Deleting account…" : "Delete Account")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            .disabled(isDeleting)
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Account and All Data", role: .destructive, action: onDeleteAccount)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and all your cloud sightings. This cannot be undone.")
            }
        }
    }
}

private struct AuthForm: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var username: String
    @Binding var isSignUp: Bool
    let isLoading: Bool
    let error: String?
    let resetEmailSent: Bool
    let onSubmit: () -> Void
    let onForgotPassword: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isSignUp {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .fieldStyle()
            }
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .fieldStyle()
            SecureField("Password", text: $password)
                .fieldStyle()

            if let error {
                Text(error)
                    .font(CV.Font.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if resetEmailSent {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Reset link sent — check your email.")
                }
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textSecondary)
            }

            Button(action: onSubmit) {
                HStack {
                    if isLoading { ProgressView().tint(.black).scaleEffect(0.8) }
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: CV.Radius.md).fill(CV.Color.accent))
            }
            .disabled(isLoading)

            HStack(spacing: 16) {
                Button {
                    withAnimation { isSignUp.toggle() }
                } label: {
                    Text(isSignUp ? "Already have an account? Sign In" : "New here? Create Account")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.accentBlue)
                }

                if !isSignUp {
                    Text("·").font(CV.Font.caption).foregroundStyle(CV.Color.textTertiary)
                    Button("Forgot password?", action: onForgotPassword)
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textTertiary)
                }
            }
        }
    }
}

extension View {
    func fieldStyle() -> some View {
        self
            .foregroundStyle(CV.Color.textPrimary)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.06)))
    }
}
