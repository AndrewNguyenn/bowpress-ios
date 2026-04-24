import SwiftUI

/// World Archery target face — flat, real ring colors, never reskinned.
/// Ring radii match the analytics-japanese.html reference at ratios of
/// 0.96, 0.86, 0.76, 0.66, 0.56, 0.46, 0.36, 0.26, 0.16, 0.08, 0.014 of
/// the rendered radius (size / 2).
struct BPTargetFace<Overlay: View>: View {
    enum FaceType {
        case tenRing
        case sixRing
    }

    let face: FaceType
    let size: CGFloat
    let showCrosshair: Bool
    let overlay: Overlay

    init(
        face: FaceType = .tenRing,
        size: CGFloat = 300,
        showCrosshair: Bool = false,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.face = face
        self.size = size
        self.showCrosshair = showCrosshair
        self.overlay = overlay()
    }

    private struct Ring {
        let ratio: CGFloat
        let fill: Color?
        let strokeColor: Color?
        let strokeWidth: CGFloat
    }

    /// Ratios from the SVG in analytics-japanese.html (svg viewBox 0 0 200 200,
    /// radii 96, 86, 76, 66, 56, 46, 36, 26, 16, 8, 1.4 — divided by 100
    /// produces the ratios used below, applied to `size / 2`).
    private var rings: [Ring] {
        switch face {
        case .tenRing:
            return [
                // outer white (rings 1–2)
                Ring(ratio: 0.96, fill: .appTgtWhite, strokeColor: .appInk, strokeWidth: 0.3),
                // hairline between 1–2
                Ring(ratio: 0.86, fill: nil,          strokeColor: .appInk, strokeWidth: 0.25),
                // black (rings 3–4)
                Ring(ratio: 0.76, fill: .appTgtBlack, strokeColor: nil,     strokeWidth: 0),
                // hairline between 3–4 (visible on black in cream)
                Ring(ratio: 0.66, fill: nil,          strokeColor: .appTgtWhite, strokeWidth: 0.25),
                // blue (rings 5–6)
                Ring(ratio: 0.56, fill: .appTgtBlue,  strokeColor: nil,     strokeWidth: 0),
                // hairline between 5–6
                Ring(ratio: 0.46, fill: nil,          strokeColor: .appInk, strokeWidth: 0.25),
                // red (rings 7–8)
                Ring(ratio: 0.36, fill: .appTgtRed,   strokeColor: nil,     strokeWidth: 0),
                // hairline between 7–8
                Ring(ratio: 0.26, fill: nil,          strokeColor: .appInk, strokeWidth: 0.25),
                // yellow (rings 9–10/X)
                Ring(ratio: 0.16, fill: .appTgtYellow, strokeColor: nil,    strokeWidth: 0),
                // X-ring hairline
                Ring(ratio: 0.08, fill: nil,          strokeColor: .appInk, strokeWidth: 0.25),
                // center dot
                Ring(ratio: 0.014, fill: .appInk,     strokeColor: nil,     strokeWidth: 0),
            ]
        case .sixRing:
            // Six-ring face starts at blue (compound / indoor). Outer zones
            // get shifted ratios. This is a deliberate simplification — full
            // WA five-color pattern reused from blue inward.
            return [
                Ring(ratio: 0.96, fill: .appTgtBlue,   strokeColor: nil,     strokeWidth: 0),
                Ring(ratio: 0.80, fill: nil,           strokeColor: .appInk, strokeWidth: 0.25),
                Ring(ratio: 0.66, fill: .appTgtRed,    strokeColor: nil,     strokeWidth: 0),
                Ring(ratio: 0.50, fill: nil,           strokeColor: .appInk, strokeWidth: 0.25),
                Ring(ratio: 0.34, fill: .appTgtYellow, strokeColor: nil,     strokeWidth: 0),
                Ring(ratio: 0.17, fill: nil,           strokeColor: .appInk, strokeWidth: 0.25),
                Ring(ratio: 0.014, fill: .appInk,      strokeColor: nil,     strokeWidth: 0),
            ]
        }
    }

    var body: some View {
        let r = size / 2
        ZStack {
            ForEach(rings.indices, id: \.self) { i in
                let ring = rings[i]
                let d = ring.ratio * size
                if let fill = ring.fill {
                    Circle()
                        .fill(fill)
                        .frame(width: d, height: d)
                }
                if let stroke = ring.strokeColor {
                    Circle()
                        .stroke(stroke, lineWidth: max(ring.strokeWidth, 0.5))
                        .frame(width: d, height: d)
                }
            }

            if showCrosshair {
                // Dashed ±11r maple circle (r = 11 in the 200-viewBox SVG →
                // ratio 0.11 of size) + center hairlines.
                Circle()
                    .stroke(Color.appMaple, style: StrokeStyle(lineWidth: 0.6, dash: [2, 2]))
                    .frame(width: size * 0.11, height: size * 0.11)
                    .opacity(0.7)
                Path { p in
                    let c = CGPoint(x: r, y: r)
                    let arm = size * 0.04
                    let gap = size * 0.03
                    p.move(to: CGPoint(x: c.x, y: c.y - gap - arm))
                    p.addLine(to: CGPoint(x: c.x, y: c.y - gap))
                    p.move(to: CGPoint(x: c.x, y: c.y + gap))
                    p.addLine(to: CGPoint(x: c.x, y: c.y + gap + arm))
                    p.move(to: CGPoint(x: c.x - gap - arm, y: c.y))
                    p.addLine(to: CGPoint(x: c.x - gap, y: c.y))
                    p.move(to: CGPoint(x: c.x + gap, y: c.y))
                    p.addLine(to: CGPoint(x: c.x + gap + arm, y: c.y))
                }
                .stroke(Color.appMaple, lineWidth: 0.6)
                .opacity(0.7)
            }

            overlay
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

extension BPTargetFace where Overlay == EmptyView {
    init(face: FaceType = .tenRing, size: CGFloat = 300, showCrosshair: Bool = false) {
        self.init(face: face, size: size, showCrosshair: showCrosshair) { EmptyView() }
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(spacing: 24) {
            BPTargetFace(showCrosshair: true)
            BPTargetFace(face: .sixRing, size: 160)
        }
    }
}
