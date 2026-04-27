import SwiftUI

/// Fraunces italic 16pt section title with an optional right-aligned aside
/// rendered as an Inter uppercase label.
struct BPSectionTitle: View {
    let title: String
    let aside: String?

    init(_ title: String, aside: String? = nil) {
        self.title = title
        self.aside = aside
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.bpDisplay(22, italic: true, weight: .medium))
                .foregroundStyle(Color.appInk)
            Spacer(minLength: 8)
            if let aside {
                Text(aside)
                    .font(.bpUI(11.5, weight: .semibold))
                    // 0.20em at 9.5pt
                    .tracking(9.5 * 0.20)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appInk3)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 16) {
            BPSectionTitle("Trend")
            BPSectionTitle("Suggestions", aside: "Last 14 days")
        }
        .padding()
    }
}
