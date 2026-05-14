import SwiftUI

private struct IsReadOnlyKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isReadOnly: Bool {
        get { self[IsReadOnlyKey.self] }
        set { self[IsReadOnlyKey.self] = newValue }
    }
}

/// Presents a persistent upgrade banner at the top and a PaywallView sheet when
/// the banner (or any gated action) is tapped. Exposes `\.isReadOnly` to children.
///
/// The banner is dismissable per-session — tapping the close affordance hides
/// it for the lifetime of the current process, but it returns on next launch
/// so users who briefly cleared it still get the upgrade nudge next time.
/// Reported as a bug by a free-tier user who couldn't navigate around the
/// always-on banner.
struct ReadOnlyGateModifier: ViewModifier {
    let isReadOnly: Bool
    @State private var showingPaywall = false
    @State private var dismissed = false

    func body(content: Content) -> some View {
        content
            .environment(\.isReadOnly, isReadOnly)
            .safeAreaInset(edge: .top, spacing: 0) {
                if isReadOnly && !dismissed {
                    UpgradeBanner(
                        onTap: { showingPaywall = true },
                        onDismiss: { dismissed = true }
                    )
                }
            }
            .sheet(isPresented: $showingPaywall) {
                NavigationStack { PaywallView() }
            }
            // If isReadOnly flips back on (subscription expired, sign-out, etc.)
            // reset the dismissed flag so the banner reappears next time it
            // matters. Without this, a user who dismissed once and later lost
            // entitlement would never see the nudge again this session.
            .onChange(of: isReadOnly) { _, newValue in
                if newValue { dismissed = false }
            }
    }
}

extension View {
    func readOnlyGate(_ isReadOnly: Bool) -> some View {
        modifier(ReadOnlyGateModifier(isReadOnly: isReadOnly))
    }
}

struct UpgradeBanner: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Lock + copy + Upgrade chip are one tap target opening the paywall.
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Read-only mode")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("Subscribe to log new sessions and edit equipment.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Upgrade")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.appAccent, in: Capsule())
                        .foregroundStyle(.white)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Separate close affordance with its own larger hit target so it
            // doesn't race the main tap. Hides the banner for this session.
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss upgrade banner")
            .accessibilityIdentifier("upgrade_banner_dismiss")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(.separator), alignment: .bottom)
        .accessibilityIdentifier("upgrade_banner")
    }
}
