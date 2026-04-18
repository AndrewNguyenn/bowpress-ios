import SwiftUI

// MARK: - Ring & Zone Thresholds

private enum TargetGeometry {
    // Pixel-measured boundaries in the 1470×1470 target_face.png (centre 735,735).
    // Color zones: yellow 0–238px, red 238–475px, blue 475–594px.
    // Yellow splits: X (0–60px) / ring 10 (60–119px) — user-confirmed X is half of old xRadius.
    // Red splits: ring 9 (119–238px) / ring 8 (238–357px ... wait re-mapped below).
    static let xRadius:   Double =  60.0 / 735.0   // 0.082 — X / 10 divider
    static let r10Radius: Double = 119.0 / 735.0   // 0.162 — 10 / 9 divider
    static let r9Radius:  Double = 238.0 / 735.0   // 0.324 — 9 / 8 divider (yellow→red)
    static let r8Radius:  Double = 357.0 / 735.0   // 0.485 — 8 / 7 divider (mid of red)
    static let r7Radius:  Double = 475.0 / 735.0   // 0.646 — 7 / 6 divider (red→blue)
    static let r6Radius:  Double = 594.0 / 735.0   // 0.808 — outer edge of ring 6 (blue→white)

    // Real mm per 1.0 normalised unit — used for the arrow-overlap scoring rule.
    static let mmPerNormUnit: Double = 20.0 / r10Radius  // ring 10 outer ≈ 20mm → ~123.5 mm

    /// Within the X ring, this distance from absolute centre is the "CENTER" zone.
    static let centerZoneRadius: Double = 0.04

    static func ring(for normalizedDist: Double) -> Int? {
        switch normalizedDist {
        case ..<xRadius:   return 11  // X (displayed as "X", scores 10)
        case ..<r10Radius: return 10
        case ..<r9Radius:  return 9
        case ..<r8Radius:  return 8
        case ..<r7Radius:  return 7
        case ..<r6Radius:  return 6
        default:           return nil
        }
    }

    static func zone(for normalizedDist: Double, angle: Double) -> ArrowPlot.Zone {
        // Angle is in degrees, 0 = right (east), going counter-clockwise.
        // We want 0 = North (top), clockwise.
        guard normalizedDist >= centerZoneRadius else { return .center }

        // Convert math angle (CCW from east) to compass bearing (CW from north)
        let bearing = (90 - angle).truncatingRemainder(dividingBy: 360)
        let compass = bearing < 0 ? bearing + 360 : bearing

        switch compass {
        case 337.5..<360, 0..<22.5:  return .n
        case 22.5..<67.5:             return .ne
        case 67.5..<112.5:            return .e
        case 112.5..<157.5:           return .se
        case 157.5..<202.5:           return .s
        case 202.5..<247.5:           return .sw
        case 247.5..<292.5:           return .w
        case 292.5..<337.5:           return .nw
        default:                      return .n
        }
    }
}

// MARK: - TargetPlotView

struct TargetPlotView: View {
    var arrows: [ArrowPlot]
    var onArrowPlotted: (Int, ArrowPlot.Zone, Double, Double) -> Void
    var isEnabled: Bool = true
    var arrowDiameterMm: Double = 5.0

    // Confirmation overlay state
    @State private var confirmationText: String?
    @State private var confirmationPosition: CGPoint = .zero
    @State private var confirmationOpacity: Double = 0
    @State private var confirmationTask: Task<Void, Never>?

    // Live drag preview — dot shown above thumb while placing
    @State private var dragPreviewPoint: CGPoint? = nil
    private let touchOffset: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            // WA 40cm target: ring 8 outer = 160mm → scale arrow to match
            let arrowDotSize = max(CGFloat(arrowDiameterMm) * (radius * 2) / 160.0, 8)

            ZStack {
                // MARK: Target face
                TargetFaceShape(radius: radius)
                    .position(center)

                // MARK: Placed arrows
                ForEach(Array(arrows.enumerated()), id: \.element.id) { idx, arrow in
                    if let pos = storedPosition(for: arrow, center: center, radius: radius) {
                        ArrowDot(number: idx + 1, ring: arrow.ring, size: arrowDotSize)
                            .position(pos)
                    }
                }

                // MARK: Drag preview
                if let preview = dragPreviewPoint {
                    Circle()
                        .strokeBorder(.white, lineWidth: 1.5)
                        .frame(width: arrowDotSize, height: arrowDotSize)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .position(preview)
                        .allowsHitTesting(false)
                }

                // MARK: Confirmation overlay
                if let text = confirmationText {
                    Text(text)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.72))
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        .position(confirmationPosition)
                        .opacity(confirmationOpacity)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Circle().size(CGSize(width: radius * 2, height: radius * 2))
                .offset(x: center.x - radius, y: center.y - radius))
            .gesture(
                isEnabled ? DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragPreviewPoint = CGPoint(x: value.location.x,
                                                   y: value.location.y - touchOffset)
                    }
                    .onEnded { value in
                        let placement = CGPoint(x: value.location.x,
                                                y: value.location.y - touchOffset)
                        // Use displayed dot radius so visual overlap matches scoring.
                        let dotNormRadius = Double(arrowDotSize / 2) / Double(radius)
                        handleTap(at: placement, center: center, radius: radius,
                                  arrowNormRadius: dotNormRadius)
                        dragPreviewPoint = nil
                    } : nil
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Tap Handling

    private func handleTap(at point: CGPoint, center: CGPoint, radius: CGFloat,
                           arrowNormRadius: Double) {
        let dx = point.x - center.x
        let dy = center.y - point.y  // flip y for standard math coords
        let dist = sqrt(dx * dx + dy * dy)
        let normalizedDist = Double(dist / radius)

        // Shift inward by the dot radius: if any visible part of the dot touches a higher ring, score it.
        let scoringDist = max(0.0, normalizedDist - arrowNormRadius)

        guard let ring = TargetGeometry.ring(for: scoringDist) else { return }

        let angle = atan2(Double(dy), Double(dx)) * 180 / .pi
        let zone = TargetGeometry.zone(for: normalizedDist, angle: angle)

        // Normalized position stored with the arrow (-1…1 relative to center)
        let normX = Double(dx) / Double(radius)
        let normY = Double(-dy) / Double(radius) // flip back: positive Y = down in screen coords

        // Show confirmation
        let ringLabel = ring == 11 ? "X" : "\(ring)"
        confirmationText = ringLabel
        confirmationPosition = clampedLabelPosition(for: point, in: CGPoint(x: 0, y: 0))
        showConfirmation(near: point)

        onArrowPlotted(ring, zone, normX, normY)
    }

    private func showConfirmation(near point: CGPoint) {
        confirmationTask?.cancel()
        confirmationPosition = CGPoint(x: point.x, y: max(point.y - 36, 24))
        confirmationOpacity = 1.0

        confirmationTask = Task {
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.3)) { confirmationOpacity = 0 }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            confirmationText = nil
        }
    }

    private func clampedLabelPosition(for point: CGPoint, in offset: CGPoint) -> CGPoint {
        CGPoint(x: point.x + offset.x, y: max((point.y + offset.y) - 36, 24))
    }

    // MARK: - Arrow Dot Position

    private func storedPosition(for arrow: ArrowPlot, center: CGPoint, radius: CGFloat) -> CGPoint? {
        if let px = arrow.plotX, let py = arrow.plotY {
            // plotY is stored with positive = down in screen coords (no flip needed)
            return CGPoint(x: center.x + CGFloat(px) * radius,
                           y: center.y + CGFloat(py) * radius)
        }
        // Legacy fallback: reconstruct from ring/zone
        let normR = normalizedRadius(for: arrow.ring, zone: arrow.zone)
        let angle = compassAngle(for: arrow.zone)
        let dx = CGFloat(normR) * radius * CGFloat(cos(angle))
        let dy = CGFloat(normR) * radius * CGFloat(sin(angle))
        return CGPoint(x: center.x + dx, y: center.y - dy)
    }

    private func normalizedRadius(for ring: Int, zone: ArrowPlot.Zone) -> Double {
        let jitter = pseudoJitter(for: ring)
        switch ring {
        case 11: return zone == .center ? 0.02 : (TargetGeometry.xRadius * 0.7) + jitter * 0.01
        case 10: return midpoint(TargetGeometry.xRadius, TargetGeometry.r10Radius) + jitter * 0.02
        case 9:  return midpoint(TargetGeometry.r10Radius, TargetGeometry.r9Radius) + jitter * 0.04
        case 8:  return midpoint(TargetGeometry.r9Radius, TargetGeometry.r8Radius) + jitter * 0.04
        case 7:  return midpoint(TargetGeometry.r8Radius, TargetGeometry.r7Radius) + jitter * 0.04
        case 6:  return midpoint(TargetGeometry.r7Radius, TargetGeometry.r6Radius) + jitter * 0.04
        default: return 0.5
        }
    }

    private func compassAngle(for zone: ArrowPlot.Zone) -> Double {
        // Returns math angle in radians (CCW from east)
        switch zone {
        case .center: return 0
        case .n:      return .pi / 2
        case .ne:     return .pi / 4
        case .e:      return 0
        case .se:     return -.pi / 4
        case .s:      return -.pi / 2
        case .sw:     return -.pi * 3 / 4
        case .w:      return .pi
        case .nw:     return .pi * 3 / 4
        }
    }

    private func midpoint(_ a: Double, _ b: Double) -> Double { (a + b) / 2 }

    /// Deterministic tiny offset so stacked arrows spread slightly.
    private func pseudoJitter(for ring: Int) -> Double {
        let seed = Double(ring * 3 + 7)
        return sin(seed) * 0.5 + 0.5  // 0…1
    }
}

// MARK: - Target Face

private struct TargetFaceShape: View {
    var radius: CGFloat

    var body: some View {
        Image("target_face")
            .resizable()
            .aspectRatio(1, contentMode: .fill)
            .frame(width: radius * 2, height: radius * 2)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

// MARK: - Arrow Dot

private struct ArrowDot: View {
    var number: Int
    var ring: Int
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(dotColor)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

            if size >= 12 {
                Text("\(number)")
                    .font(.system(size: max(size * 0.45, 7), weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
            }
        }
    }

    private var dotColor: Color {
        switch ring {
        case 11: return Color(red: 1.0,  green: 0.85, blue: 0.0)   // gold   (X, inner yellow)
        case 10: return Color(red: 1.0,  green: 0.95, blue: 0.2)   // yellow (outer yellow zone)
        case 9:  return Color(red: 1.0,  green: 0.95, blue: 0.2)   // yellow (still yellow zone)
        case 8:  return Color(red: 0.88, green: 0.28, blue: 0.22)  // red
        case 7:  return Color(red: 0.88, green: 0.28, blue: 0.22)  // red
        case 6:  return Color(red: 0.0,  green: 0.73, blue: 0.89)  // blue
        default: return .gray
        }
    }

    private var textColor: Color {
        ring >= 9 ? .black : .white
    }
}

// MARK: - Preview

#Preview {
    let arrows: [ArrowPlot] = [
        ArrowPlot(id: "1", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "ac1",
                  ring: 11, zone: .center, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "2", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "ac1",
                  ring: 10, zone: .ne, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "3", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "ac1",
                  ring: 9, zone: .w, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "4", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "ac1",
                  ring: 8, zone: .se, shotAt: Date(), excluded: false, notes: nil),
    ]

    VStack(spacing: 20) {
        TargetPlotView(arrows: arrows, onArrowPlotted: { ring, zone, _, _ in
            print("Plotted ring \(ring) zone \(zone)")
        })
        .frame(width: 320, height: 320)
        .padding()

        TargetPlotView(arrows: [], onArrowPlotted: { _, _, _, _ in }, isEnabled: false)
            .frame(width: 200, height: 200)
            .opacity(0.5)
    }
}
