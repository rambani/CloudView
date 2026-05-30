import SwiftUI

/// Lightweight settings sheet — currently the privacy / community
/// opt-in surface plus a way to exercise right-to-erasure. Reachable
/// from a long-press on the info button in ContentView.
///
/// The community toggle is the only knob we expose; camera / location /
/// notifications stay in iOS Settings per Apple HIG.
struct SettingsView: View {
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss

    // Mirror the persisted flag locally so the toggle re-renders the row
    // immediately and we can intercept the change to fire side effects.
    @State private var communityEnabled: Bool = ScanReportingService.shared.isEnabled

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Share anonymous cloud activity", isOn: $communityEnabled)
                        .tint(.blue)
                        .onChange(of: communityEnabled) { newValue in
                            ScanReportingService.shared.isEnabled = newValue
                            if newValue {
                                // User just opted in — register the cached
                                // device token with the backend so they
                                // start getting regional pings.
                                notificationService.registerWithBackendIfConsented()
                            } else {
                                // User just opted out — pull their record
                                // from the backend per the privacy policy.
                                notificationService.deleteFromBackend()
                            }
                        }
                } header: {
                    Text("Community")
                } footer: {
                    Text("When on, Cloudoodle sends an anonymous city-level count of the drawings you create so others can see what people are spotting near them. We never send your exact location, your account, or the cloud images. You can turn this off any time.")
                }

                Section("Privacy") {
                    Link("Privacy policy", destination: privacyPolicyURL)
                    Button(role: .destructive) {
                        notificationService.deleteFromBackend()
                        communityEnabled = false
                    } label: {
                        Text("Delete my data")
                    }
                }

                Section("About") {
                    LabeledContent("Version") {
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: doneButtonToolbar)
        }
    }

    // Pull the toolbar out into a separately-typed @ToolbarContentBuilder so
    // Swift doesn't have to disambiguate between the toolbar(content:) View
    // overload and the toolbar(content:) ToolbarContent overload at the
    // call site. Direct inline use produced "ambiguous use of 'toolbar(content:)'"
    // under iOS 16 SDK + Xcode 16.
    @ToolbarContentBuilder
    private func doneButtonToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }

    // TODO: point at the hosted policy URL once published.
    private var privacyPolicyURL: URL {
        URL(string: "https://github.com/rambani/CloudView/blob/main/docs/PRIVACY.md")!
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}
