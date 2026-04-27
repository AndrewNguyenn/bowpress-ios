import SwiftUI

/// Edit affordance — uppercase Inter label with a trailing Fraunces italic
/// chevron. Defaults to "EDIT".
struct BPEditLink: View {
    let text: String
    let action: () -> Void

    init(_ text: String = "EDIT", action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(text)
                    .font(.bpUI(11, weight: .semibold))
                    // 0.18em at 11pt
                    .tracking(11 * 0.18)
                    .textCase(.uppercase)
                Text("\u{203A}") // ›
                    .font(.bpDisplay(14, italic: true, weight: .medium))
            }
            .foregroundStyle(Color.appPondDk)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 12) {
            BPEditLink { }
            BPEditLink("Change") { }
        }
        .padding()
    }
}
