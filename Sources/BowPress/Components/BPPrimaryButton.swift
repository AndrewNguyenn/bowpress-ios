import SwiftUI

/// Full-width primary CTA. Solid pond-dk rectangle, paper foreground, Fraunces
/// italic title with optional uppercase subtitle and trailing italic chevron.
struct BPPrimaryButton: View {
    let title: String
    let subtitle: String?
    let trailing: String
    let disabled: Bool
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        trailing: String = "\u{203A}",
        disabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.bpDisplay(20, italic: true, weight: .medium))
                        .lineLimit(1)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.bpUI(9, weight: .semibold))
                            // 0.20em at 9pt
                            .tracking(9 * 0.20)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.appPaper.opacity(0.72))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(trailing)
                    .font(.bpDisplay(32, italic: true, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(disabled ? Color.appLine : Color.appPondDk)
            .foregroundStyle(Color.appPaper)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(spacing: 14) {
            BPPrimaryButton(title: "Start session", subtitle: "50m · 72 arrows") { }
            BPPrimaryButton(title: "Continue", disabled: true) { }
        }
        .padding()
    }
}
