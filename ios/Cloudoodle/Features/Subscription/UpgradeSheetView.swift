import SwiftUI
import StoreKit

/// Paywall sheet. Presented when a free user tries to take a second
/// Polaroid in a day, and from Settings under "Cloudoodle Unlimited".
/// The pitch is intentionally short — one sentence on what it is, two
/// price buttons (yearly tagged "Best value"), restore + legal links.
///
/// Reads `Product` objects from SubscriptionService so the displayed
/// prices are always the user's localized App Store prices (not
/// hardcoded "$4.99" strings that would be wrong in EUR/JPY/etc.).
struct UpgradeSheetView: View {
    @State private var subscriptions = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var purchasing = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.10, blue: 0.16),
                         Color(red: 0.02, green: 0.03, blue: 0.06)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                hero
                Spacer(minLength: 0)
                if subscriptions.products.isEmpty, !subscriptions.isLoadingProducts {
                    loadFailed
                } else if subscriptions.isLoadingProducts {
                    ProgressView().tint(.white.opacity(0.6))
                } else {
                    priceButtons
                }
                footer
                    .padding(.top, 14)
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .task { await subscriptions.loadProducts() }
        .alert("Couldn't complete purchase",
               isPresented: Binding(
                get: { subscriptions.purchaseError != nil },
                set: { if !$0 { subscriptions.clearPurchaseError() } }
               )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subscriptions.purchaseError ?? "")
        }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 14)
    }

    private var hero: some View {
        VStack(spacing: 18) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 44))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(CV.Color.accent)

            VStack(spacing: 10) {
                Text("Cloudoodle Unlimited")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(.white)

                Text("Capture as many skies as the day will give you.")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "infinity", text: "Unlimited Polaroids, every day")
                FeatureRow(icon: "wand.and.sparkles", text: "Every scan developed with AI")
                FeatureRow(icon: "heart.text.square", text: "Support a tiny indie app")
            }
            .padding(.top, 4)
        }
    }

    private var priceButtons: some View {
        VStack(spacing: 10) {
            if let yearly = subscriptions.yearlyProduct() {
                priceButton(product: yearly,
                            title: "Yearly",
                            subtitle: yearlySubtitle(yearly),
                            badge: "BEST VALUE",
                            primary: true)
            }
            if let monthly = subscriptions.monthlyProduct() {
                priceButton(product: monthly,
                            title: "Monthly",
                            subtitle: "billed monthly · cancel anytime",
                            badge: nil,
                            primary: false)
            }
        }
        .padding(.top, 22)
    }

    private func priceButton(product: Product,
                             title: String,
                             subtitle: String,
                             badge: String?,
                             primary: Bool) -> some View {
        Button {
            Task { await purchase(product) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(
                                    Capsule().fill(CV.Color.accent.opacity(0.25))
                                )
                                .foregroundStyle(CV.Color.accent)
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(primary ? .black.opacity(0.55) : .white.opacity(0.55))
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.system(size: 19, weight: .semibold, design: .serif))
            }
            .foregroundStyle(primary ? .black : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(primary ? CV.Color.accent : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(primary ? Color.clear : Color.white.opacity(0.12),
                                          lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(purchasing)
        .opacity(purchasing ? 0.6 : 1)
    }

    private var loadFailed: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.6))
            Text("Couldn't load subscription options")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Button("Try again") {
                Task { await subscriptions.loadProducts() }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(CV.Color.accent)
        }
        .padding(.top, 24)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button("Restore Purchases") {
                Task { await subscriptions.restorePurchases() }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))

            Text("Auto-renews until cancelled. Manage in Settings → Apple ID → Subscriptions.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            HStack(spacing: 14) {
                if let url = LegalLinks.termsURL {
                    Link("Terms", destination: url)
                }
                if let url = LegalLinks.privacyURL {
                    Link("Privacy", destination: url)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Purchase

    private func purchase(_ product: Product) async {
        purchasing = true
        defer { purchasing = false }
        let ok = await subscriptions.purchase(product)
        if ok { dismiss() }
    }

    /// "$39.99/yr · save 33%" — computed against the monthly price so
    /// the discount stays accurate if either tier's price moves later.
    private func yearlySubtitle(_ yearly: Product) -> String {
        guard let monthly = subscriptions.monthlyProduct() else {
            return "billed yearly · cancel anytime"
        }
        let monthlyAnnualized = monthly.price * 12
        guard monthlyAnnualized > 0 else { return "billed yearly · cancel anytime" }
        let saving = (monthlyAnnualized - yearly.price) / monthlyAnnualized
        let pct = Int((saving * 100).rounded())
        return pct > 0
            ? "billed yearly · save \(pct)% vs monthly"
            : "billed yearly · cancel anytime"
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CV.Color.accent)
                .frame(width: 22, alignment: .leading)
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }
}
