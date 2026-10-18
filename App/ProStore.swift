import Foundation
import StoreKit

/// Knows whether the person has Pro. One purchase, no subscription.
@MainActor
final class ProStore: ObservableObject {
    /// Must match the product created in App Store Connect and in `Config/Pro.storekit`.
    static let lifetimeProductID = "com.shabbatwake.ios.pro.lifetime"

    /// Pro is not charged for until this is turned on. While it is false every feature is open,
    /// so the app can be tested end to end. Turn it on once the product exists in App Store Connect.
    static let isEnforced = false

    @Published private(set) var hasPro: Bool
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isPurchasing = false
    @Published private(set) var productUnavailable = false
    @Published var message: String?

#if DEBUG
    /// Lets a developer see the locked state in a debug build. Not compiled into release builds.
    @Published var debugLocked = false {
        didSet { recompute() }
    }
#endif

    private var owned: Bool
    private var updatesTask: Task<Void, Never>?
    private static let ownedKey = "pro.owned.v1"

    init() {
        owned = UserDefaults.standard.bool(forKey: Self.ownedKey)
        hasPro = !Self.isEnforced || owned
        WidgetSync.updatePro(hasPro)
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
        await loadProduct()
    }

    func loadProduct() async {
        do {
            lifetimeProduct = try await Product.products(for: [Self.lifetimeProductID]).first
            productUnavailable = lifetimeProduct == nil
        } catch {
            lifetimeProduct = nil
            productUnavailable = true
        }
    }

    func purchase() async {
        guard let product = lifetimeProduct else {
            message = AppLanguage.text("The App Store isn't available right now. Please try again in a moment.")
            return
        }
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
            message = AppLanguage.text(owned ? "Pro is restored." : "No earlier purchase was found for this Apple ID.")
        } catch {
            message = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.lifetimeProductID,
               transaction.revocationDate == nil {
                found = true
            }
        }
        owned = found
        UserDefaults.standard.set(found, forKey: Self.ownedKey)
        recompute()
    }

    private func recompute() {
#if DEBUG
        if debugLocked { hasPro = false; WidgetSync.updatePro(false); return }
#endif
        hasPro = !Self.isEnforced || owned
        WidgetSync.updatePro(hasPro)
    }
}
