import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss

    // API keys
    @AppStorage("gemini_api_key") private var geminiKey = ""
    @AppStorage("openai_api_key") private var openaiKey = ""
    @AppStorage("supabase_url") private var supabaseURL = ""
    @AppStorage("supabase_anon_key") private var supabaseAnonKey = ""

    // Display preferences
    @AppStorage("polaroid_show_shape_caption") private var showShapeCaption = true

    // Subscription
    @State private var subscriptions = SubscriptionService.shared
    @State private var showUpgrade = false

    // Daily reminder
    @State private var reminder = DailyReminderService.shared
    @State private var reminderEnabled = DailyReminderService.shared.enabled
    @State private var reminderTime = DailyReminderService.shared.reminderTime
    @State private var reminderPermissionDenied = false

    // Journal export
    @State private var isExporting = false
    @State private var exportURL: ExportArchive?
    @State private var exportError: String?

    /// Identifiable wrapper so the share sheet presents from an
    /// optional binding.
    struct ExportArchive: Identifiable {
        let url: URL
        var id: String { url.path }
    }

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
    @State private var showOpenAIKey = false
    @State private var showSupabaseKey = false
    @State private var legalSheet: LegalSheet?

    /// Driven by the rows under "Legal". One enum + identifier so
    /// SwiftUI can present a single sheet with whichever doc was tapped.
    enum LegalSheet: String, Identifiable {
        case privacy, terms
        var id: String { rawValue }
    }

    // Mirrors the gate in ContentView so the DEBUG "restart onboarding"
    // button flips the same UserDefaults key. The default value here is
    // never actually consulted — Settings is unreachable before the
    // onboarding cover finishes — so it's kept as `true` for
    // robustness if a future surface presents Settings on cold launch.
    @AppStorage("hasOnboarded") private var hasOnboarded = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        // Cloudoodle Unlimited — surfaces subscription
                        // status + the upgrade path. Subscribers see
                        // their plan; free users see the pitch.
                        SettingsSection(title: "Cloudoodle Unlimited", icon: "infinity") {
                            subscriptionRow
                        }

                        // Polaroid display preferences
                        SettingsSection(title: "Polaroid", icon: "photo.on.rectangle.angled") {
                            Toggle(isOn: $showShapeCaption) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Show shape name on Polaroid")
                                        .scaledFont(size: 14, weight: .medium)
                                        .foregroundStyle(CV.Color.textPrimary)
                                    Text("Faint italic caption inside the photo.")
                                        .font(CV.Font.caption)
                                        .foregroundStyle(CV.Color.textTertiary)
                                }
                            }
                            .tint(CV.Color.accent)
                        }

                        // Daily reminder
                        SettingsSection(title: "Daily Reminder", icon: "bell") {
                            reminderSection
                        }

                        // Your data — the journal lives only on this
                        // device until cloud sync exists; export is the
                        // way out (zip of every photo + a journal.txt).
                        SettingsSection(title: "Your Data", icon: "square.and.arrow.up.on.square") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Your Polaroids and notes are stored on this device. Export a .zip with every photo (developed + original) and a text file of your notes.")
                                    .font(CV.Font.caption)
                                    .foregroundStyle(CV.Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button {
                                    Task { await exportJournal() }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isExporting {
                                            ProgressView().tint(.black).scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "square.and.arrow.up")
                                        }
                                        Text(isExporting ? "Preparing…" : "Export Journal")
                                            .scaledFont(size: 14, weight: .semibold)
                                    }
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(Capsule().fill(CV.Color.accent))
                                }
                                .buttonStyle(.plain)
                                .disabled(isExporting)
                                if let exportError {
                                    Text(exportError)
                                        .font(CV.Font.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }

                        // The Gemini API key is now held as a
                        // secrets on the server (Supabase edge function
                        // `develop-polaroid`). Users no longer need to
                        // bring their own keys. The legacy DEBUG fields
                        // below let developers override the key on a
                        // dev build, but the production app never reads
                        // them — calls go through the proxy regardless.
                        #if DEBUG
                        SettingsSection(title: "AI Keys (DEBUG)", icon: "key") {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Gemini API Key — unused at runtime")
                                        .font(CV.Font.caption)
                                        .foregroundStyle(CV.Color.textTertiary)
                                    SecureRevealField(
                                        text: $geminiKey,
                                        isRevealed: $showAnthropicKey,
                                        placeholder: "AIza..."
                                    )
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("OpenAI API Key — fully retired (Gemini handles the develop now)")
                                        .font(CV.Font.caption)
                                        .foregroundStyle(CV.Color.textTertiary)
                                    SecureRevealField(
                                        text: $openaiKey,
                                        isRevealed: $showOpenAIKey,
                                        placeholder: "sk-..."
                                    )
                                }
                                Text("Both keys are held as Supabase secrets by the develop-polaroid edge function. The fields above are kept for legacy reference only.")
                                    .font(CV.Font.caption)
                                    .foregroundStyle(CV.Color.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        #endif

                        #if DEBUG
                        // Supabase URL + anon key are normally baked
                        // in at build time via Config.xcconfig — no
                        // user should ever see these fields. Kept
                        // behind DEBUG so devs can point a test build
                        // at a different Supabase project without
                        // rebuilding.
                        SettingsSection(title: "Backend (DEBUG)", icon: "server.rack") {
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
                                .scaledFont(size: 14, weight: .semibold)
                                .foregroundStyle(supabase.isConfigured ? CV.Color.accentBlue : CV.Color.textTertiary)
                                .disabled(!supabase.isConfigured)
                            }
                        }
                        #endif

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

                        // Legal — Privacy Policy + Terms. If a hosted URL
                        // is set in LegalLinks, opens Safari; otherwise
                        // pops a sheet rendering the bundled markdown.
                        SettingsSection(title: "Legal", icon: "doc.text") {
                            VStack(spacing: 0) {
                                LegalRow(
                                    title: "Privacy Policy",
                                    url: LegalLinks.privacyURL,
                                    onFallback: { legalSheet = .privacy }
                                )
                                Divider().background(Color.white.opacity(0.06))
                                LegalRow(
                                    title: "Terms of Service",
                                    url: LegalLinks.termsURL,
                                    onFallback: { legalSheet = .terms }
                                )
                            }
                        }

                        #if DEBUG
                        // Developer affordance — quick way to re-run the
                        // onboarding flow without uninstalling. Not shown
                        // in Release so real users can't accidentally
                        // wipe their onboarding state.
                        Button {
                            hasOnboarded = false
                            dismiss()
                        } label: {
                            Label("Restart onboarding (DEBUG)", systemImage: "arrow.counterclockwise")
                                .font(CV.Font.caption)
                                .foregroundStyle(CV.Color.textTertiary)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
                        #endif

                        // About — version + build for support / TestFlight
                        // diagnostics. Reads from Info.plist so it stays in
                        // sync with whatever the xcconfig is building.
                        VStack(spacing: 4) {
                            Text("Cloudoodle")
                                .scaledFont(size: 13, weight: .semibold)
                                .foregroundStyle(CV.Color.textTertiary)
                            Text("Find shapes in the sky")
                                .font(CV.Font.caption)
                                .foregroundStyle(CV.Color.textTertiary.opacity(0.6))
                            Text("v\(Self.appVersion) (\(Self.buildNumber))")
                                .font(CV.Font.mono)
                                .foregroundStyle(CV.Color.textTertiary.opacity(0.5))
                                .padding(.top, 2)
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
            .sheet(item: $legalSheet) { sheet in
                switch sheet {
                case .privacy: LegalView(title: "Privacy Policy", resourceName: "PrivacyPolicy")
                case .terms:   LegalView(title: "Terms of Service", resourceName: "TermsOfService")
                }
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheetView()
            }
            .sheet(item: $exportURL) { archive in
                ActivityViewSheet(items: [archive.url])
            }
        }
        .preferredColorScheme(.dark)
        .task { await subscriptions.refreshEntitlements() }
    }

    /// Daily reminder section. Toggle + time picker. When the user
    /// enables it for the first time we walk through requesting
    /// notification permission; if denied, we surface a small hint
    /// pointing them at the system Settings.
    @ViewBuilder
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $reminderEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me daily")
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundStyle(CV.Color.textPrimary)
                    Text("A quiet nudge to look up — only on days you haven't scanned.")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(CV.Color.accent)
            .onChange(of: reminderEnabled) { _, newValue in
                Task { await handleReminderToggle(newValue) }
            }

            if reminderEnabled {
                DatePicker(
                    "Time",
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .scaledFont(size: 14)
                .foregroundStyle(CV.Color.textPrimary)
                .tint(CV.Color.accent)
                .onChange(of: reminderTime) { _, newValue in
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    reminder.hour = comps.hour ?? 11
                    reminder.minute = comps.minute ?? 0
                }
            }

            if reminderPermissionDenied {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                    Text("Notifications are off for Cloudoodle. Enable them in the system Settings app to receive the reminder.")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Reminder source hint — explains why the wording the
            // user sees depends on whether they're signed in. (Who
            // sends the reminder is purely an auth question; the
            // subscription has nothing to do with it.)
            Text(SupabaseService.shared.isAuthenticated
                 ? "Sign-in active: the reminder summarizes what people near you saw today."
                 : "Sign in to get a reminder summarizing what people near you saw today; otherwise it's a warm-generic nudge.")
                .scaledFont(size: 11, design: .serif)
                .italic()
                .foregroundStyle(CV.Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func handleReminderToggle(_ newValue: Bool) async {
        if newValue {
            // First-time enable: make sure we have notification
            // permission before we promise the user we'll fire.
            let svc = NotificationService.shared
            await svc.checkAuthorizationStatus()
            if !svc.isAuthorized {
                let granted = await svc.requestPermission()
                if !granted {
                    reminderPermissionDenied = true
                    reminderEnabled = false
                    reminder.enabled = false
                    return
                }
            }
            reminderPermissionDenied = false
        }
        reminder.enabled = newValue
    }

    /// Subscription status row inside the "Cloudoodle Unlimited"
    /// section. Subscribers see active state + a link to manage in
    /// the system Subscriptions page; free users see the pitch +
    /// upgrade button.
    @ViewBuilder
    private var subscriptionRow: some View {
        if subscriptions.isSubscribed {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(CV.Color.accent)
                    Text("Unlimited active")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(CV.Color.textPrimary)
                    Spacer()
                }
                Text("Capture as many Polaroids as you'd like, every day. Thank you for supporting Cloudoodle.")
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link("Manage subscription", destination: url)
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(CV.Color.accentBlue)
                        .padding(.top, 4)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("One free Polaroid per day. Upgrade for unlimited captures and to support a tiny indie app.")
                    .scaledFont(size: 13, design: .serif)
                    .foregroundStyle(CV.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    showUpgrade = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("See plans")
                            .scaledFont(size: 14, weight: .semibold)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(CV.Color.accent))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private static var buildNumber: String {
        Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String ?? "?"
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

    private func exportJournal() async {
        isExporting = true
        exportError = nil
        do {
            let url = try await JournalStore.shared.exportArchive()
            exportURL = ExportArchive(url: url)
        } catch {
            exportError = "Couldn't build the export: \(error.localizedDescription)"
        }
        isExporting = false
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

/// Privacy Policy / Terms of Service row. If a hosted URL is set in
/// `LegalLinks`, the row renders as a `Link` (opens Safari). If not,
/// the row is a button that calls back to present the in-app
/// markdown viewer.
private struct LegalRow: View {
    let title: String
    let url: URL?
    let onFallback: () -> Void

    var body: some View {
        if let url {
            Link(destination: url) { rowContent }
                .buttonStyle(.plain)
        } else {
            Button(action: onFallback) { rowContent }
                .buttonStyle(.plain)
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Text(title)
                .scaledFont(size: 14)
                .foregroundStyle(CV.Color.textPrimary)
            Spacer()
            Image(systemName: url == nil ? "doc.text" : "arrow.up.right")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundStyle(CV.Color.textTertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

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
                .scaledFont(size: 13, weight: .semibold)
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
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundStyle(CV.Color.textPrimary)
                    Text("\(user.totalSightings) sightings · \(user.streakDays) day streak")
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textTertiary)
                }
                Spacer()
                Button("Sign Out", action: onSignOut)
                    .scaledFont(size: 14, weight: .medium)
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
                        .scaledFont(size: 13, weight: .medium)
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
                        .scaledFont(size: 15, weight: .semibold)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: CV.Radius.md).fill(CV.Color.accent))
            }
            .disabled(isLoading)

            // Apple requires Sign In with Apple as an option whenever
            // email/password auth is offered (App Review Guideline 4.8).
            // The button is rendered with the standard Apple-provided
            // style so it doesn't fall outside HIG.
            HStack(spacing: 8) {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5)
                Text("or")
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textTertiary)
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5)
            }
            .padding(.vertical, 2)

            SignInWithAppleButtonView()
                .frame(height: 44)

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
