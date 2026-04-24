import SwiftUI

/// Brand wordmark — "bow**press**" rendered in Fraunces italic with the
/// second syllable carrying the pond-dk emphasis. Used by the splash and
/// available for Settings footer / About / future surfaces.
///
/// Default size matches the splash (36pt). Tracking follows the spec
/// `letter-spacing: -0.01em`, scaled to point size.
struct BPWordmark: View {
    var size: CGFloat = 36
    var primary: Color = .appInk
    var emphasis: Color = .appPondDk

    var body: some View {
        (
            Text("bow").foregroundStyle(primary)
            + Text("press").foregroundStyle(emphasis)
        )
        .font(.bpDisplay(size, italic: true, weight: .medium))
        .tracking(-0.01 * size)
        .lineLimit(1)
        .fixedSize()
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(spacing: 24) {
            BPWordmark(size: 36)
            BPWordmark(size: 24)
            BPWordmark(size: 18)
        }
        .padding()
    }
}
