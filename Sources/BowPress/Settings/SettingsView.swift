import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial
    var subscriptionManager: SubscriptionManager = .shared

    @State private var showSignOutConfirm: Bool = false
    @State private var isSigningOut: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header
                BPNavHeader(eyebrow: "BOWPRESS \u{00B7} ACCOUNT", title: "Settings") {
                    EmptyView()
                }

                VStack(alignment: .leading, spacing: 0) {
                    profileBlock
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // Group 1: Subscription, Notifications, Units
                    settingsGroup1
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // Group 2: Privacy, Terms, Sign out
                    settingsGroup2
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // Subscription / restore row (below groups, preserved)
                    subscriptionAccessRow
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // Colophon
                    colophon
                        .padding(.top, 26)
                        .padding(.bottom, 32)
                }
            }
        }
        .background(Color.appPaper)
        .navigationBarHidden(true)
        .task {
            await subscriptionManager.refreshEntitlement()
        }
        .confirmationDialog(
            "Sign out of BowPress?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive, action: confirmSignOut)
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Profile block

    @ViewBuilder
    private var profileBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let user = appState.currentUser {
                HStack(alignment: .center, spacing: 14) {
                    // Square avatar
                    ZStack {
                        Rectangle()
                            .fill(Color.appPondDk)
                            .frame(width: 54, height: 54)
                        Text(initials(for: user.name))
                            .font(.bpDisplay(22, italic: true, weight: .medium))
                            .foregroundStyle(Color.appPaper)
                    }

                    // Name + email
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.bpDisplay(20, italic: true, weight: .medium))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        Text(user.email.uppercased())
                            .font(.bpMono(10))
                            .tracking(10 * 0.04)
                            .foregroundStyle(Color.appInk3)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    NavigationLink {
                        AccountView()
                    } label: {
                        HStack(spacing: 2) {
                            Text("EDIT")
                                .font(.bpUI(11, weight: .semibold))
                                .tracking(11 * 0.18)
                                .textCase(.uppercase)
                            Text("\u{203A}")
                                .font(.bpDisplay(11, italic: true, weight: .medium))
                        }
                        .foregroundStyle(Color.appPondDk)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 18)

                Rectangle()
                    .fill(Color.appLine)
                    .frame(height: 1)
            } else {
                Text("Not signed in")
                    .font(.bpUI(14))
                    .foregroundStyle(Color.appInk3)
                    .padding(.bottom, 18)
                Rectangle()
                    .fill(Color.appLine)
                    .frame(height: 1)
            }
        }
    }

    // MARK: - Settings group 1: Subscription, Notifications, Units

    private var settingsGroup1: some View {
        BPCard(padding: 0) {
            VStack(spacing: 0) {
                settingsRow(
                    label: "Subscription",
                    value: subscriptionPlanName,
                    isDestructive: false,
                    destination: AnyView(PaywallView())
                )

                Rectangle().fill(Color.appLine2).frame(height: 1)

                // Notifications toggle row
                HStack(alignment: .center) {
                    Text("Push notifications")
                        .font(.bpDisplay(14, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                    Spacer()
                    HStack(spacing: 6) {
                        Text(notificationsEnabled ? "ON" : "OFF")
                            .font(.bpMono(10))
                            .tracking(10 * 0.04)
                            .foregroundStyle(Color.appInk3)
                        Toggle("", isOn: $notificationsEnabled)
                            .labelsHidden()
                            .tint(Color.appPond)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)

                Rectangle().fill(Color.appLine2).frame(height: 1)

                // Units row — toggles between Imperial and Metric
                Button {
                    unitSystem = unitSystem == .imperial ? .metric : .imperial
                } label: {
                    HStack(alignment: .center) {
                        Text("Units")
                            .font(.bpDisplay(14, italic: true, weight: .medium))
                            .foregroundStyle(Color.appInk)
                        Spacer()
                        HStack(spacing: 4) {
                            Text((unitSystem == .imperial ? "IMPERIAL" : "METRIC"))
                                .font(.bpMono(10))
                                .tracking(10 * 0.04)
                                .foregroundStyle(Color.appInk3)
                            Text("\u{203A}")
                                .font(.bpDisplay(16, italic: true, weight: .medium))
                                .foregroundStyle(Color.appPond)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Settings group 2: Privacy, Terms, Sign out

    private var settingsGroup2: some View {
        BPCard(padding: 0) {
            VStack(spacing: 0) {
                // Privacy policy
                Link(destination: URL(string: "https://bowpress.app/privacy")!) {
                    HStack(alignment: .center) {
                        Text("Privacy policy")
                            .font(.bpDisplay(14, italic: true, weight: .medium))
                            .foregroundStyle(Color.appInk)
                        Spacer()
                        Text("\u{203A}")
                            .font(.bpDisplay(16, italic: true, weight: .medium))
                            .foregroundStyle(Color.appPond)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }

                Rectangle().fill(Color.appLine2).frame(height: 1)

                // Terms of service
                Link(destination: URL(string: "https://bowpress.app/terms")!) {
                    HStack(alignment: .center) {
                        Text("Terms of service")
                            .font(.bpDisplay(14, italic: true, weight: .medium))
                            .foregroundStyle(Color.appInk)
                        Spacer()
                        Text("\u{203A}")
                            .font(.bpDisplay(16, italic: true, weight: .medium))
                            .foregroundStyle(Color.appPond)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }

                Rectangle().fill(Color.appLine2).frame(height: 1)

                // Sign out
                Button {
                    showSignOutConfirm = true
                } label: {
                    HStack(alignment: .center) {
                        Text("Sign out")
                            .font(.bpDisplay(14, italic: true, weight: .medium))
                            .foregroundStyle(Color.appMaple)
                        Spacer()
                        Text("\u{203A}")
                            .font(.bpDisplay(16, italic: true, weight: .medium))
                            .foregroundStyle(Color.appPond)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .disabled(isSigningOut)
            }
        }
    }

    // MARK: - Subscription / restore access row (preserved from original)

    @ViewBuilder
    private var subscriptionAccessRow: some View {
        BPCard(padding: 0) {
            VStack(spacing: 0) {
                NavigationLink {
                    PaywallView()
                } label: {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.entitlement?.isActive == true ? "View subscription plans" : "Upgrade to Pro")
                                .font(.bpDisplay(14, italic: true, weight: .medium))
                                .foregroundStyle(Color.appInk)
                            Text("unlock the full tuning engine")
                                .font(.bpUI(10))
                                .tracking(10 * 0.04)
                                .foregroundStyle(Color.appInk3)
                        }
                        Spacer()
                        Text("\u{203A}")
                            .font(.bpDisplay(16, italic: true, weight: .medium))
                            .foregroundStyle(Color.appPond)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }

                Rectangle().fill(Color.appLine2).frame(height: 1)

                Button {
                    Task { await subscriptionManager.restorePurchases() }
                } label: {
                    HStack(alignment: .center) {
                        Text("Restore purchases")
                            .font(.bpDisplay(14, italic: true, weight: .medium))
                            .foregroundStyle(Color.appInk)
                        Spacer()
                        Text("\u{203A}")
                            .font(.bpDisplay(16, italic: true, weight: .medium))
                            .foregroundStyle(Color.appPond)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Colophon

    private var colophon: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("est. arch")
                .font(.bpDisplay(11, italic: true, weight: .regular))
                .tracking(11 * 0.08)
                .foregroundStyle(Color.appInk3)
            Spacer().frame(width: 8)
            Rectangle()
                .fill(Color.appPond)
                .frame(width: 5, height: 5)
            Spacer().frame(width: 8)
            Text("kanazawa")
                .font(.bpDisplay(11, italic: true, weight: .regular))
                .tracking(11 * 0.08)
                .foregroundStyle(Color.appInk3)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let last = parts[parts.count - 1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var subscriptionPlanName: String {
        guard let entitlement = appState.entitlement, entitlement.isActive else {
            return "FREE"
        }
        switch entitlement.productId {
        case BowPressProduct.monthly: return "PRO MONTHLY"
        case BowPressProduct.annual:  return "PRO ANNUAL"
        default:                      return "BOWPRESS PRO"
        }
    }

    @ViewBuilder
    private func settingsRow(
        label: String,
        value: String,
        isDestructive: Bool,
        destination: AnyView
    ) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(alignment: .center) {
                Text(label)
                    .font(.bpDisplay(14, italic: true, weight: .medium))
                    .foregroundStyle(isDestructive ? Color.appMaple : Color.appInk)
                Spacer()
                HStack(spacing: 4) {
                    if !value.isEmpty {
                        Text(value.uppercased())
                            .font(.bpMono(10))
                            .tracking(10 * 0.04)
                            .foregroundStyle(Color.appInk3)
                    }
                    Text("\u{203A}")
                        .font(.bpDisplay(16, italic: true, weight: .medium))
                        .foregroundStyle(Color.appPond)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
    }

    private func confirmSignOut() {
        isSigningOut = true
        AuthService(appState: appState).signOut()
        isSigningOut = false
    }
}

// MARK: - Preview

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
