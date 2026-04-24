import SwiftUI

/// Monoline wireframe bow glyph — the design-system bow mark used in session
/// bow cards and equipment rows. Renders as a single stroked Path so it scales
/// crisply at any size and respects the current foreground style. No bitmap
/// assets; no SF Symbol.
///
/// Path comes from `bowpress-design-system/project/ui_kits/ios_app/SessionScreen.jsx`
/// (the bow icon in the Setup bow-card). Viewbox 0…32:
///   M8 3 C 4 4  6 8  6 13  … a curved compound-bow profile with small cam
///   arcs at the top and bottom of the riser and a horizontal arrow/rest line
///   running to the quiver side.
struct BPBowIcon: View {
    var size: CGFloat = 28
    var stroke: CGFloat = 1.3
    var tint: Color = .appPondDk

    var body: some View {
        Canvas { ctx, canvasSize in
            let scale = canvasSize.width / 32.0
            let s: (CGFloat, CGFloat) -> CGPoint = { x, y in
                CGPoint(x: x * scale, y: y * scale)
            }

            var path = Path()

            // Main riser curve — upper half: (8,3) bulging right to (14,16)
            path.move(to: s(8, 3))
            path.addCurve(
                to: s(14, 16),
                control1: s(12, 7),
                control2: s(14, 11)
            )
            // Main riser curve — lower half: (14,16) to (8,29)
            path.addCurve(
                to: s(8, 29),
                control1: s(14, 21),
                control2: s(12, 25)
            )

            // Top cam arc — (8,3) curves left then back at (8,10)
            path.move(to: s(8, 3))
            path.addCurve(
                to: s(8, 10),
                control1: s(6, 5),
                control2: s(6, 8)
            )

            // Bottom cam arc — (8,29) curves left then back at (8,22)
            path.move(to: s(8, 29))
            path.addCurve(
                to: s(8, 22),
                control1: s(6, 27),
                control2: s(6, 24)
            )

            // Upper string/limb stroke — (8,10) to (14,16)
            path.move(to: s(8, 10))
            path.addLine(to: s(14, 16))

            // Lower string/limb stroke — (8,22) to (14,16)
            path.move(to: s(8, 22))
            path.addLine(to: s(14, 16))

            // Horizontal rest/shelf — (14,16) to (28,16)
            path.move(to: s(14, 16))
            path.addLine(to: s(28, 16))

            ctx.stroke(
                path,
                with: .color(tint),
                style: StrokeStyle(
                    lineWidth: stroke,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        BPBowIcon(size: 28)
        BPBowIcon(size: 44, stroke: 1.4)
        BPBowIcon(size: 64, stroke: 1.6, tint: .appPond)
    }
    .padding()
    .background(Color.appPaper)
}
#endif
