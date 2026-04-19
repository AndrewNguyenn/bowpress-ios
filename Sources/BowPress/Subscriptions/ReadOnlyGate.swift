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
struct ReadOnlyGateModifier: ViewModifier {
    let isReadOnly: Bool
    @State private var showingPaywall = false

    func body(content: Content) -> some View {
        content
            .environment(\.isReadOnly, isReadOnly)
            .safeAreaInset(edge: .top, spacing: 0) {
                if isReadOnly {
                    UpgradeBanner { showingPaywall = true }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                NavigationStack { PaywallView() }
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

    var body: some View {
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
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(Rectangle().frame(height: 0.5).foregroundStyle(.separator), alignment: .bottom)
        }
        .buttonStyle(.plain)
    }
}
