import SwiftUI

/// Page 06 — username draft. We don't actually create the account here
/// (no auth at this point); we cache the chosen handle in
/// @AppStorage("onboarding_username") and SupabaseService picks it up
/// the first time the user signs up via Settings.
struct UsernamePage: View {
    @Bindable var store: OnboardingStore
    var onContinue: () -> Void

    @AppStorage("onboarding_username") private var savedUsername: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CV.Color.accentBlue.opacity(0.14))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(CV.Color.accentBlue)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("ALMOST THERE")
                        .font(CV.Font.mono)
                        .foregroundStyle(CV.Color.textTertiary)
                        .tracking(1.5)
                    (Text("What should we ") + Text("call you?").italic())
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .foregroundStyle(CV.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            inputRow
                .padding(.horizontal, 24)
                .padding(.top, 24)

            availabilityLine
                .padding(.horizontal, 28)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("OR GRAB A SKY NAME")
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.textTertiary)
                    .tracking(1.5)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(store.usernameSuggestions, id: \.self) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)

            Spacer(minLength: 0)

            PrimaryCTA(title: "That's me — @\(store.normalize(store.usernameDraft))") {
                savedUsername = store.normalize(store.usernameDraft)
                onContinue()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .task {
            await store.checkAvailability()
        }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("@")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textSecondary)
                TextField("", text: $store.usernameDraft)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(CV.Color.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .onChange(of: store.usernameDraft) { _, _ in
                        // Clear stale state immediately, then schedule a
                        // debounced check — successive keystrokes cancel
                        // each other so we only hit Supabase once the
                        // user has paused typing.
                        store.usernameAvailable = nil
                        store.scheduleAvailabilityCheck()
                    }
                    .onSubmit { Task { await store.checkAvailability() } }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                CV.Color.accentBlue.opacity(store.usernameAvailable == true ? 0.55 : 0.2),
                                lineWidth: store.usernameAvailable == true ? 1.2 : 0.5
                            )
                    )
            )

            Button {
                store.reshuffleSuggestions()
                Task { await store.checkAvailability() }
            } label: {
                Image(systemName: "die.face.5")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Re-roll suggestions")
        }
    }

    @ViewBuilder
    private var availabilityLine: some View {
        HStack(spacing: 6) {
            if store.isCheckingUsername {
                ProgressView().controlSize(.mini).tint(CV.Color.textTertiary)
                Text("Checking…").font(CV.Font.caption).foregroundStyle(CV.Color.textTertiary)
            } else if let available = store.usernameAvailable {
                Circle()
                    .fill(available ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(
                    available
                    ? "@\(store.normalize(store.usernameDraft)) is available"
                    : "@\(store.normalize(store.usernameDraft)) is taken — try another"
                )
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textSecondary)
            } else if store.normalize(store.usernameDraft).count < 3 {
                Text("Three characters or more")
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textTertiary)
            } else {
                Color.clear.frame(height: 14)
            }
            Spacer()
        }
    }

    private func suggestionChip(_ suggestion: String) -> some View {
        let selected = store.normalize(store.usernameDraft) == suggestion
        return Button {
            store.pick(suggestion)
            Task { await store.checkAvailability() }
        } label: {
            Text("@\(suggestion)")
                .font(CV.Font.mono)
                .foregroundStyle(selected ? CV.Color.accentBlue : CV.Color.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        selected
                        ? CV.Color.accentBlue.opacity(0.12)
                        : Color.white.opacity(0.06)
                    )
                )
                .overlay(
                    Capsule().strokeBorder(
                        selected ? CV.Color.accentBlue.opacity(0.35) : Color.white.opacity(0.10),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
