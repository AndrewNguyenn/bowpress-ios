import SwiftUI

/// Local hex helper — AppTheme's `hex(_:)` is fileprivate and the Impact-Map
/// pond ramp needs a handful of specific fills that aren't token'd. Scoped
/// `private` so it can't leak into the broader namespace.
private func bpTgtHex(_ s: String) -> Color {
    var h = s.trimmingCharacters(in: .init(charactersIn: "#"))
    if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
    var rgb: UInt64 = 0
    Scanner(string: h).scanHexInt64(&rgb)
    let r = Double((rgb >> 16) & 0xFF) / 255
    let g = Double((rgb >>  8) & 0xFF) / 255
    let b = Double( rgb        & 0xFF) / 255
    return Color(red: r, green: g, blue: b)
}

/// World Archery target face — flat, real ring colors, never reskinned.
/// Ring radii match the analytics-japanese.html reference at ratios of
/// 0.96, 0.86, 0.76, 0.66, 0.56, 0.46, 0.36, 0.26, 0.16, 0.08, 0.014 of
/// the rendered radius (size / 2).
///
/// Two styles:
///   • `.wa` (default) — real WA colors for the setup face picker + the
///     active session target. Data should never be drawn ON this face.
///   • `.impactMap` — pond-gradient quiet-rings variant used by the Analytics
///     Impact Map. Follows the spec's "data, not decoration" rule so centroids
///     and shift arrows read cleanly without clashing with WA paint.
struct BPTargetFace<Overlay: View>: View {
    enum FaceType {
        case tenRing
        case sixRing
    }

    enum Style {
        /// Real World Archery paint — white/black/blue/red/yellow. The default,
        /// used for every face-as-foreground-content surface.
        case wa
        /// Pond-gradient ring stack for the Impact Map — outer paper → deep
        /// pond → lacquer ink, with moss at the exact center. See lines 476–488
        /// of bowpress-design-system/project/explorations/analytics-japanese.html.
        case impactMap
    }

    let face: FaceType
    let style: Style
    let size: CGFloat
    let showCrosshair: Bool
    let overlay: Overlay

    init(
        face: FaceType = .tenRing,
        style: Style = .wa,
        size: CGFloat = 300,
        showCrosshair: Bool = false,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.face = face
        self.style = style
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
        if style == .impactMap {
            return impactMapRings
        }
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

    /// Pond-gradient ring stack for the Impact Map. Ratios from
    /// analytics-japanese.html lines 476–488 — outer paper mist → deep pond
    /// → lacquer ink, with a moss hairline X-ring and a moss center dot so
    /// the target reads as data, not decoration.
    private var impactMapRings: [Ring] {
        [
            Ring(ratio: 0.94, fill: bpTgtHex("#d9e1d8"), strokeColor: nil, strokeWidth: 0),
            Ring(ratio: 0.84, fill: bpTgtHex("#c9d4c9"), strokeColor: nil, strokeWidth: 0),
            Ring(ratio: 0.74, fill: bpTgtHex("#b2c3c2"), strokeColor: nil, strokeWidth: 0),
            Ring(ratio: 0.64, fill: bpTgtHex("#8fb3bf"), strokeColor: nil, strokeWidth: 0),
            Ring(ratio: 0.54, fill: bpTgtHex("#6d9aa8"), strokeColor: nil, strokeWidth: 0),
            Ring(ratio: 0.44, fill: bpTgtHex("#4a7989"), strokeColor: nil, strokeWidth: 0),
            Ring(ratio: 0.34, fill: bpTgtHex("#3a6878"), strokeColor: nil, strokeWidth: 0),
            Ring(ratio: 0.24, fill: bpTgtHex("#2d5a6b"), strokeColor: nil, strokeWidth: 0),
            Ring(ratio: 0.14, fill: bpTgtHex("#1e3e4a"), strokeColor: nil, strokeWidth: 0),
            Ring(ratio: 0.07, fill: bpTgtHex("#1f2a26"), strokeColor: nil, strokeWidth: 0),
            // X-ring moss hairline (r=3.2 at viewBox 200 → ratio 0.032).
            Ring(ratio: 0.032, fill: nil,  strokeColor: .appMoss, strokeWidth: 0.6),
            // center moss dot (r=0.8 at viewBox 200 → ratio 0.008).
            Ring(ratio: 0.008, fill: .appMoss, strokeColor: nil, strokeWidth: 0),
        ]
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
    init(
        face: FaceType = .tenRing,
        style: Style = .wa,
        size: CGFloat = 300,
        showCrosshair: Bool = false
    ) {
        self.init(face: face, style: style, size: size, showCrosshair: showCrosshair) { EmptyView() }
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(spacing: 24) {
            BPTargetFace(showCrosshair: true)
            BPTargetFace(face: .sixRing, size: 160)
            BPTargetFace(style: .impactMap, size: 200, showCrosshair: true)
        }
    }
}
