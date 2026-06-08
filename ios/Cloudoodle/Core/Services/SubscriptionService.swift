import Foundation
import Observation
import StoreKit

/// Tracks the user's daily Polaroid quota and Cloudoodle Unlimited
/// subscription status.
///
/// Free tier: one Polaroid per local day.
/// Unlimited: monthly or yearly auto-renewing subscription.
///
/// StoreKit 2 here. Two product IDs declared up front, both must be
/// created in App Store Connect (Subscriptions → "Cloudoodle Unlimited"
/// group) before the live build can purchase. For local testing the
/// .storekit file at `ios/Cloudoodle/Resources/StoreKit/Cloudoodle.storekit`
/// declares the same IDs and prices; set it on the Run scheme's
/// "StoreKit Configuration" option (xcodegen doesn't manage that yet).
@Observable
@MainActor
final class SubscriptionService {
    static let shared = SubscriptionService()

    /// Product identifiers — keep aligned with App Store Connect and
    /// the .storekit configuration file. Changing these strings is a
    /// breaking change for anyone with an active subscription.
    enum ProductID {
        static let monthly = "com.cloudoodle.unlimited.monthly"
        static let yearly  = "com.cloudoodle.unlimited.yearly"
        static let all: Set<String> = [monthly, yearly]
    }

    private(set) var products: [Product] = []
    private(set) var isSubscribed: Bool = false
    private(set) var isLoadingProducts = false
    private(set) var purchaseError: String?

    /// Local @AppStorage key for the date of the last successful scan.
    /// ISO-8601 date only, in the user's local timezone. Reset on
    /// midnight rollover, no server check.
    private let lastScanKey = "cloudoodle.lastScanDate"

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Watch StoreKit transaction stream for renewals / refunds /
        // changes made on another device. Without this, the gate
        // can't unlock mid-session when a purchase clears.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refreshEntitlements() }
    }

    // No deinit — this is a singleton (`shared`) that lives for the
    // entire app lifetime, so `updatesTask` never needs cleanup.
    // Adding a deinit here would also clash with Swift 6's strict
    // concurrency rules (deinits on @MainActor types can't touch
    // main-actor-isolated state without going nonisolated).

    // MARK: - Daily quota

    /// True when the free user has not yet consumed today's Polaroid.
    /// Subscribers always have quota; this returns true for them too.
    var hasQuotaToday: Bool {
        if isSubscribed { return true }
        return lastScanDate.map { !Calendar.current.isDateInToday($0) } ?? true
    }

    /// True only when a scan actually happened today, regardless of
    /// subscription status. Used by DailyReminderService to decide
    /// whether the user still needs nudging.
    var scannedToday: Bool {
        lastScanDate.map { Calendar.current.isDateInToday($0) } ?? false
    }

    /// Mark today's quota as spent. Called after a successful develop
    /// commit (independent of JournalStore so deleting the entry
    /// doesn't refund the quota — that'd be an obvious gaming vector).
    func recordScan() {
        let now = Date()
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastScanKey)
    }

    /// Human-readable "you've already scanned today" reason — used in
    /// the gated UI to explain why the camera isn't available.
    var nextResetMessage: String {
        let cal = Calendar.current
        guard let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) else {
            return "Come back tomorrow for a fresh sky."
        }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "Next sky available at midnight (\(f.string(from: next)) tomorrow)."
    }

    private var lastScanDate: Date? {
        let v = UserDefaults.standard.double(forKey: lastScanKey)
        return v > 0 ? Date(timeIntervalSince1970: v) : nil
    }

    // MARK: - Products

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: Array(ProductID.all))
            // Sort monthly first, yearly second — the upgrade sheet
            // assumes this order for layout.
            products = fetched.sorted { $0.id < $1.id }
        } catch {
            purchaseError = "Couldn't load subscription options. Check your connection."
        }
    }

    func monthlyProduct() -> Product? {
        products.first { $0.id == ProductID.monthly }
    }

    func yearlyProduct() -> Product? {
        products.first { $0.id == ProductID.yearly }
    }

    // MARK: - Purchase

    /// Kicks off a purchase. Returns true on success so the caller can
    /// dismiss the paywall; the entitlement check is handled inside.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .userCancelled:
                return false
            case .pending:
                // Ask-to-buy / SCA — entitlement will flip via
                // Transaction.updates when it clears. No-op here.
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = "Couldn't restore: \(error.localizedDescription)"
        }
    }

    /// Clear the surfaced purchase error — called by the paywall
    /// when the user dismisses the alert so it doesn't immediately
    /// re-fire on the next render.
    func clearPurchaseError() {
        purchaseError = nil
    }

    // MARK: - Entitlement check

    /// Replays the user's current entitlements. Sets `isSubscribed`
    /// based on whether any of our subscription products has an
    /// active, non-revoked transaction. Called on launch, after
    /// purchase, and on any transaction-stream update.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil,
               (transaction.expirationDate.map { $0 > Date() } ?? true) {
                active = true
                break
            }
        }
        isSubscribed = active
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}
