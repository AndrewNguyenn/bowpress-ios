import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    var subscriptionManager: SubscriptionManager = .shared

    var body: some View {
        Form {
            accountSection
            subscriptionSection
            preferencesSection
        }
        .navigationTitle("Settings")
        .task {
            await subscriptionManager.refreshEntitlement()
        }
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if let user = appState.currentUser {
                NavigationLink {
                    AccountView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name).font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("Not signed in").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Subscription

    @ViewBuilder
    private var subscriptionSection: some View {
        Section("Subscription") {
            if let entitlement = appState.entitlement, entitlement.isActive {
                SubscriptionStatusCard(entitlement: entitlement)
            } else {
                NavigationLink {
                    PaywallView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Pro")
                                .font(.body.weight(.semibold))
                            Text("Unlock the full tuning engine")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
            }

            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
            }

            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #endif
                }
            } label: {
                Label("Manage Subscription", systemImage: "creditcard")
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section("Preferences") {
            NavigationLink {
                AboutView()
            } label: {
                settingsRow(title: "About", systemImage: "info.circle")
            }

            Link(destination: URL(string: "https://bowpress.app/privacy")!) {
                settingsRow(title: "Privacy Policy", systemImage: "hand.raised", trailing: "arrow.up.right.square")
            }
            .foregroundStyle(.primary)

            Link(destination: URL(string: "https://bowpress.app/terms")!) {
                settingsRow(title: "Terms of Service", systemImage: "doc.text", trailing: "arrow.up.right.square")
            }
            .foregroundStyle(.primary)

            Toggle(isOn: $notificationsEnabled) {
                Label("Notifications", systemImage: "bell")
            }
        }
    }

    @ViewBuilder
    private func settingsRow(title: String, systemImage: String, trailing: String? = nil) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if let trailing {
                Image(systemName: trailing).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - About

private struct AboutView: View {
    var body: some View {
        Form {
            Section("BowPress") {
                LabeledContent("Version", value: Self.version)
                LabeledContent("Build", value: Self.build)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    private static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }
}

#Preview {
    let state = AppState()
    state.currentUser = User(
        id: "u1",
        email: "archer@example.com",
        name: "Sage Archer",
        createdAt: Date(timeIntervalSince1970: 0),
        emailVerified: true
    )
    return NavigationStack { SettingsView() }
        .environment(state)
}
