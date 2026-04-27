import SwiftUI

/// Flat rectangular card — the only card primitive in Kenrokuen.
/// 1px hairline, no radius, no shadow.
struct BPCard<Content: View>: View {
    let inset: Bool
    let padding: CGFloat
    let content: Content

    init(inset: Bool = false, padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.inset = inset
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(inset ? Color.appPaper2 : Color.appPaper)
            .overlay(Rectangle().strokeBorder(Color.appLine, lineWidth: 1))
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(spacing: 16) {
            BPCard {
                Text("Default card — paper bg, 1px hairline")
                    .font(.bpUI(14))
                    .foregroundStyle(Color.appInk2)
            }
            BPCard(inset: true) {
                Text("Inset card — paper2 bg")
                    .font(.bpUI(14))
                    .foregroundStyle(Color.appInk2)
            }
        }
        .padding()
    }
}
