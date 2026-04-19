import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    var manager: SubscriptionManager = .shared

    @State private var didLoad = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                hero
                productList
                restoreButton
                legalFooter
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.lg)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("BowPress Pro")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didLoad else { return }
            didLoad = true
            await manager.loadProducts()
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "scope")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(Color.appAccent)
                .padding(.bottom, AppTheme.Spacing.xs)

            Text("Unlock the full tuning engine")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)

            Text("Unlimited sessions, advanced analytics, and personalised tuning suggestions.")
                .font(.subheadline)
                .foregroundStyle(Color.appText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.md)
        }
        .padding(.vertical, AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var productList: some View {
        if let error = manager.lastError, manager.products.isEmpty {
            errorState(error)
        } else if manager.products.isEmpty {
            loadingState
        } else {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(manager.products, id: \.id) { product in
                    ProductRow(
                        product: product,
                        disabled: manager.purchaseInFlight,
                        onTap: {
                            Task { await manager.purchase(product) }
                        }
                    )
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ProgressView()
            Text("Loading plans…")
                .font(.footnote)
                .foregroundStyle(Color.appText)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.lg)
        .appCardStyle()
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await manager.loadProducts() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.lg)
        .appCardStyle()
    }

    private var restoreButton: some View {
        Button {
            Task { await manager.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appAccent)
        }
        .padding(.top, AppTheme.Spacing.sm)
    }

    private var legalFooter: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text("Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account. Manage or cancel anytime in Settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: AppTheme.Spacing.md) {
                Link("Terms of Service", destination: URL(string: "https://bowpress.app/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://bowpress.app/privacy")!)
            }
            .font(.caption2)
        }
        .padding(.top, AppTheme.Spacing.md)
    }
}

// MARK: - Product Row

private struct ProductRow: View {
    let product: Product
    let disabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(periodDescription)
                        .font(.subheadline)
                        .foregroundStyle(Color.appText)
                    if let offer = trialDescription {
                        Text(offer)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(shortPeriod)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle(accent: Color.appAccent.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
        .accessibilityLabel(Text("Subscribe to \(product.displayName) at \(product.displayPrice)"))
    }

    private var periodDescription: String {
        guard let sub = product.subscription else { return product.description }
        return "Billed \(periodLabel(sub.subscriptionPeriod))"
    }

    private var shortPeriod: String {
        guard let sub = product.subscription else { return "" }
        return "/ \(shortPeriodLabel(sub.subscriptionPeriod))"
    }

    private var trialDescription: String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let days = daysIn(offer.period)
        return "\(days)-day free trial"
    }

    private func periodLabel(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:   return "daily"
        case .week:  return "weekly"
        case .month: return period.value == 1 ? "monthly" : "every \(period.value) months"
        case .year:  return "yearly"
        @unknown default: return ""
        }
    }

    private func shortPeriodLabel(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:   return "day"
        case .week:  return "week"
        case .month: return "month"
        case .year:  return "year"
        @unknown default: return ""
        }
    }

    private func daysIn(_ period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day:   return period.value
        case .week:  return period.value * 7
        case .month: return period.value * 30
        case .year:  return period.value * 365
        @unknown default: return period.value
        }
    }
}
