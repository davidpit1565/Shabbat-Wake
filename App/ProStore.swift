import Foundation
import StoreKit

/// Knows whether the person has Pro: an auto-renewing subscription, yearly or monthly.
@MainActor
final class ProStore: ObservableObject {
    /// Must match the subscriptions created in App Store Connect (one subscription group) and in `Config/Pro.storekit`.
    static let yearlyProductID = "com.shabbatwake.ios.pro.yearly"
    static let monthlyProductID = "com.shabbatwake.ios.pro.monthly"
    static let productIDs = [yearlyProductID, monthlyProductID]

    /// Pro is not charged for until this is turned on. While it is false every feature is open,
    /// so the app can be tested end to end. Turn it on once the subscriptions exist in App Store Connect.
    /// Debug builds (run from Xcode, with Config/Pro.storekit) show the real purchase flow so it can be tried.
    /// Release builds keep everything unlocked until the two subscriptions exist in App Store Connect.
    #if DEBUG
    static let isEnforced = true
    #else
    static let isEnforced = false
    #endif

    @Published private(set) var hasPro: Bool
    /// Yearly first, then monthly.
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPurchasing = false
    @Published private(set) var productsUnavailable = false
    @Published var message: String?

#if DEBUG
    /// Lets a developer see the locked state in a debug build. Not compiled into release builds.
    @Published var debugLocked = false {
        didSet { recompute() }
    }
#endif

    /// While Pro is only a preview, this pretends to be a free account so the locked features can be tried.
    @Published private(set) var previewFree = UserDefaults.standard.bool(forKey: ProStore.previewFreeKey)
    private static let previewFreeKey = "pro.previewFree.v1"

    func setPreviewFree(_ on: Bool) {
        previewFree = on
        UserDefaults.standard.set(on, forKey: Self.previewFreeKey)
        recompute()
    }

    private var subscribed: Bool
    private var updatesTask: Task<Void, Never>?
    private static let subscribedKey = "pro.subscribed.v1"

    init() {
        subscribed = UserDefaults.standard.bool(forKey: Self.subscribedKey)
        hasPro = (Self.isEnforced && !ScreenshotMode.isOn) ? subscribed : !UserDefaults.standard.bool(forKey: Self.previewFreeKey)
        WidgetSync.updatePro(hasPro)
    }

    var yearly: Product? { products.first { $0.id == Self.yearlyProductID } }
    var monthly: Product? { products.first { $0.id == Self.monthlyProductID } }

    /// How much the yearly plan saves against twelve monthly payments, as a whole percent, when both prices are known.
    var yearlySavingsPercent: Int? {
        guard let yearly, let monthly, monthly.price > 0 else { return nil }
        let full = monthly.price * 12
        guard full > yearly.price else { return nil }
        let saved = NSDecimalNumber(decimal: (full - yearly.price) / full * 100).doubleValue
        return Int(saved.rounded())
    }

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                        await self.refreshEntitlements()
                    }
                }
            }
        }
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { ($0.id == Self.yearlyProductID ? 0 : 1) < ($1.id == Self.yearlyProductID ? 0 : 1) }
            productsUnavailable = products.isEmpty
        } catch {
            products = []
            productsUnavailable = true
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    message = AppLanguage.text("The purchase couldn't be verified. You haven't been charged.")
                }
            case .pending:
                message = AppLanguage.text("Your purchase is waiting for approval.")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    /// Asks the App Store to re-send purchases made with this Apple ID, for example after reinstalling.
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = AppLanguage.text(subscribed ? "Pro is restored." : "No earlier purchase was found for this Apple ID.")
        } catch {
            message = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil,
               (transaction.expirationDate ?? .distantFuture) > .now {
                found = true
            }
        }
        subscribed = found
        UserDefaults.standard.set(found, forKey: Self.subscribedKey)
        recompute()
    }

    private func recompute() {
#if DEBUG
        if debugLocked { hasPro = false; WidgetSync.updatePro(false); return }
#endif
        hasPro = (Self.isEnforced && !ScreenshotMode.isOn) ? subscribed : !previewFree
        WidgetSync.updatePro(hasPro)
    }
}
