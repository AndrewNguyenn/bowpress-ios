import Foundation
import StoreKit
import Observation

enum BowPressProduct {
    static let monthly = "com.andrewnguyen.bowpress.monthly"
    static let annual  = "com.andrewnguyen.bowpress.annual"

    static var all: [String] { [monthly, annual] }
}

@Observable
@MainActor
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    var products: [Product] = []
    var entitlement: Entitlement?
    var purchaseInFlight: Bool = false
    var lastError: String?

    weak var appState: AppState?

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Background listener for transaction updates that arrive outside a direct
        // purchase flow (renewals, Ask to Buy approvals, cross-device restores).
        // The singleton lives for the process lifetime, so we don't cancel in deinit.
        self.updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await self?.handleVerified(transaction)
                await transaction.finish()
            }
        }
    }

    // MARK: - Configuration

    func configure(appState: AppState) {
        self.appState = appState
        appState.entitlement = self.entitlement
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: BowPressProduct.all)
            self.products = fetched.sorted { $0.price < $1.price }
            self.lastError = nil
        } catch {
            self.lastError = "Could not load plans"
        }
    }

    // MARK: - Entitlement

    func refreshEntitlement() async {
        do {
            let entitlement = try await APIClient.shared.fetchEntitlement()
            self.entitlement = entitlement
            appState?.entitlement = entitlement
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        guard !purchaseInFlight else { return }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "Purchase could not be verified."
                    return
                }
                let jws = verification.jwsRepresentation
                let entitlement = try await APIClient.shared.verifyAppleTransaction(jws: jws)
                self.entitlement = entitlement
                appState?.entitlement = entitlement
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                lastError = "Purchase pending approval."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            for await result in Transaction.currentEntitlements {
                guard case .verified = result else { continue }
                let jws = result.jwsRepresentation
                let entitlement = try await APIClient.shared.verifyAppleTransaction(jws: jws)
                self.entitlement = entitlement
                appState?.entitlement = entitlement
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func handleVerified(_ transaction: Transaction) async {
        do {
            let jws = transaction.jsonRepresentation.base64EncodedString()
            let entitlement = try await APIClient.shared.verifyAppleTransaction(jws: jws)
            self.entitlement = entitlement
            appState?.entitlement = entitlement
        } catch {
            lastError = error.localizedDescription
        }
    }
}
