import SwiftUI

struct SubscriptionStatusCard: View {
    let entitlement: Entitlement

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        if !entitlement.isActive {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(planName)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    if entitlement.inTrial {
                        trialBadge
                    }
                }

                if let expires = entitlement.expiresAt {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(renewalLabel(expires: expires))
                            .font(.subheadline)
                            .foregroundStyle(Color.appText)
                    }
                }

                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: entitlement.autoRenew ? "arrow.triangle.2.circlepath" : "pause.circle")
                        .foregroundStyle(entitlement.autoRenew ? Color.appAccent : Color.secondary)
                    Text(entitlement.autoRenew ? "Auto-renew on" : "Auto-renew off")
                        .font(.subheadline)
                        .foregroundStyle(Color.appText)
                }

                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        #if canImport(UIKit)
                        UIApplication.shared.open(url)
                        #endif
                    }
                } label: {
                    Text("Manage Subscription")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.sm)
                }
                .buttonStyle(.bordered)
                .tint(Color.appAccent)
                .padding(.top, AppTheme.Spacing.xs)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle(accent: Color.appAccent.opacity(0.5))
        }
    }

    private var planName: String {
        switch entitlement.productId {
        case BowPressProduct.monthly: return "BowPress Pro — Monthly"
        case BowPressProduct.annual:  return "BowPress Pro — Annual"
        default:                      return "BowPress Pro"
        }
    }

    private var trialBadge: some View {
        Text("TRIAL")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, 2)
            .background(Color.appAccentSubtle, in: Capsule())
            .foregroundStyle(Color.appAccent)
    }

    private func renewalLabel(expires: Date) -> String {
        let formatted = Self.dateFormatter.string(from: expires)
        if entitlement.autoRenew {
            return "Renews \(formatted)"
        } else {
            return "Expires \(formatted)"
        }
    }
}
