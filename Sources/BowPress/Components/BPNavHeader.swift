import SwiftUI

/// Sticky-ish header: eyebrow + title + optional right-aligned meta,
/// closed by a 1px hairline. Meta is generic so callers can pass mono
/// telemetry, an edit link, etc.
struct BPNavHeader<Meta: View>: View {
    let eyebrow: String?
    let title: String
    let meta: Meta

    init(eyebrow: String? = nil, title: String, @ViewBuilder meta: () -> Meta) {
        self.eyebrow = eyebrow
        self.title = title
        self.meta = meta()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(.bpUI(11.5, weight: .semibold))
                            // 0.32em at 10.5pt
                            .tracking(10.5 * 0.32)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.appPondDk)
                    }
                    Text(title)
                        .font(.bpDisplay(40, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                meta
                    .font(.bpMono(12))
                    .foregroundStyle(Color.appInk3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle()
                .fill(Color.appLine)
                .frame(height: 1)
        }
        .background(Color.appPaper)
    }
}

extension BPNavHeader where Meta == EmptyView {
    init(eyebrow: String? = nil, title: String) {
        self.init(eyebrow: eyebrow, title: title) { EmptyView() }
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(spacing: 0) {
            BPNavHeader(eyebrow: "This morning", title: "Analytics") {
                Text("07:14 · 15/72")
            }
            Spacer()
        }
    }
}
