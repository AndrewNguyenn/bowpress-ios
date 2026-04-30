import SwiftUI

// MARK: - Target Geometry

/// Normalised-radius ring geometry for a given target face.
///
/// `rings` lists the outer radius of each scoring ring, outer-most first, in
/// normalised units (1.0 = the outer edge of the face). `xRadius` is the
/// outer radius of the X ring (the inner-most ring, scores 10 but rendered
/// as "X"). Ring numbers start at `outerRingValue` for the outer-most ring
/// and count up inward; the X ring is always `xRingValue`.
struct TargetGeometry {
    let faceType: TargetFaceType
    /// Outer radius of each scoring ring, outer-most first (decreasing).
    /// Last entry is the outer radius of the ring just before the X.
    let rings: [Double]
    /// Outer radius of the X ring.
    let xRadius: Double
    /// Value of the outer-most ring (`6` for sixRing, `1` for tenRing).
    let outerRingValue: Int
    /// Value representing the X ring (always `11`).
    let xRingValue: Int = 11

    /// Pixel-measured boundaries in the 1470x1470 target_face.png (centre 735,735).
    /// Yellow 0-238px, red 238-475px, blue 475-594px. Yellow splits: X (0-60) /
    /// ring 10 (60-119). Matches the geometry stored against every pre-existing
    /// session, so legacy data stays interpretable.
    static let sixRing = TargetGeometry(
        faceType: .sixRing,
        rings: [
            594.0 / 735.0,  // ring 6  (blue outer)
            475.0 / 735.0,  // ring 7  (red outer / blue inner)
            357.0 / 735.0,  // ring 8  (mid red)
            238.0 / 735.0,  // ring 9  (yellow outer / red inner)
            119.0 / 735.0   // ring 10 (inner yellow / outer X)
        ],
        xRadius: 60.0 / 735.0,
        outerRingValue: 6
    )

    /// Standard WA 10-ring face — equal-width rings. X at 0.05, ring 10 at 0.10,
    /// ring 9 at 0.20, ... ring 1 at 1.00.
    static let tenRing = TargetGeometry(
        faceType: .tenRing,
        rings: [
            1.00,  // ring 1 (outer white)
            0.90,  // ring 2 (inner white)
            0.80,  // ring 3 (outer black)
            0.70,  // ring 4 (inner black)
            0.60,  // ring 5 (outer blue)
            0.50,  // ring 6 (inner blue)
            0.40,  // ring 7 (outer red)
            0.30,  // ring 8 (inner red)
            0.20,  // ring 9 (outer yellow)
            0.10   // ring 10 (inner yellow / outer X)
        ],
        xRadius: 0.05,
        outerRingValue: 1
    )

    static func preset(for faceType: TargetFaceType) -> TargetGeometry {
        switch faceType {
        case .sixRing: return .sixRing
        case .tenRing: return .tenRing
        }
    }

    /// Real mm per 1.0 normalised unit — used for the arrow-overlap scoring rule.
    /// The outer edge of ring 10 is 20mm from centre on the WA 40cm 10-ring face
    /// and on the compound 10-ring inner face. Ring 10's outer radius is the
    /// second-inner boundary on both presets.
    var mmPerNormUnit: Double {
        // ring 10 is the last entry in `rings` (inner-most scoring ring above X)
        guard let ring10Outer = rings.last, ring10Outer > 0 else { return 20.0 }
        return 20.0 / ring10Outer
    }

    /// Within the X ring, this distance from absolute centre is the "CENTER" zone.
    var centerZoneRadius: Double { 0.04 }

    /// Returns the ring number for a given normalised distance from centre,
    /// or `nil` for a miss (outside the outer-most scoring ring).
    /// Ring numbers are `outerRingValue` at the outside, counting up toward
    /// the centre; `xRingValue` (11) is the innermost X.
    func ring(for normalizedDist: Double) -> Int? {
        if normalizedDist < xRadius { return xRingValue }
        // `rings` lists outer-most (largest radius) first, so the array index
        // matches the offset from `outerRingValue`:
        //   rings[0] is the outer-most scoring ring (ring = outerRingValue)
        //   rings[N-1] is the inner-most scoring ring above X
        // Walk from inner-most to outer-most and return the first band whose
        // outer radius still contains the point.
        for idx in stride(from: rings.count - 1, through: 0, by: -1) {
            if normalizedDist < rings[idx] {
                return outerRingValue + idx
            }
        }
        return nil
    }

    func zone(for normalizedDist: Double, angle: Double) -> ArrowPlot.Zone {
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
    /// Fired when the user drags an existing arrow to a new position. Lets the
    /// archer fix a misclick before finishing the end without going through
    /// the per-arrow edit sheet. Reuses the same scoring math as `onArrowPlotted`.
    var onArrowReplotted: ((String, Int, ArrowPlot.Zone, Double, Double) -> Void)? = nil
    /// Fired when the target transitions between unzoomed (1×) and zoomed
    /// states. Lets the parent fade out informational overlays that would
    /// otherwise sit underneath the magnified target.
    var onZoomChanged: ((Bool) -> Void)? = nil
    var isEnabled: Bool = true
    var arrowDiameterMm: Double = 5.0
    var faceType: TargetFaceType = .sixRing

    private var geometry: TargetGeometry { TargetGeometry.preset(for: faceType) }

    // Confirmation overlay state
    @State private var confirmationText: String?
    @State private var confirmationPosition: CGPoint = .zero
    @State private var confirmationOpacity: Double = 0
    @State private var confirmationTask: Task<Void, Never>?

    // Single-finger drag preview — dot shown above thumb when dragging at 1x.
    @State private var dragPreviewPoint: CGPoint? = nil
    private let touchOffset: CGFloat = 80
    /// Below this translation magnitude the gesture is treated as a tap
    /// (place arrow at the raw tap point with no thumb offset).
    private let tapSlop: CGFloat = 8

    /// Id of the arrow currently being dragged-to-reposition. Set on the first
    /// drag movement past `tapSlop` if the gesture started on top of an
    /// existing arrow; cleared on release. While set, the arrow is hidden from
    /// the rendered list so the drag preview is the only thing the archer sees.
    @State private var movingArrowId: String? = nil

    // Pinch-zoom + pan state. `committed*` persists between gestures;
    // `live*` is @GestureState that auto-resets when the gesture ends.
    @GestureState private var liveMagnification: CGFloat = 1.0
    @State        private var committedZoom: CGFloat = 1.0
    @GestureState private var livePan: CGSize = .zero
    @State        private var committedPan: CGSize = .zero
    // Set true while a pinch is active; kept true briefly after so the
    // simultaneous drag's .onEnded doesn't fire a ghost tap at the last
    // finger position when the user releases a pinch.
    @State private var pinchInProgress: Bool = false
    @State private var pinchCooldownTask: Task<Void, Never>?

    private var currentZoom: CGFloat { committedZoom * liveMagnification }
    private var isZoomed: Bool { currentZoom > 1.01 }
    private var panOffset: CGSize {
        CGSize(width: committedPan.width + livePan.width,
               height: committedPan.height + livePan.height)
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            // Scale arrow to match real-world mm on the drawn face.
            let arrowDotSize = max(CGFloat(arrowDiameterMm / geometry.mmPerNormUnit) * radius, 8)
            let panLimit = max(0, radius * (currentZoom - 1))

            ZStack {
                // Scaled group: target + placed arrows share the same coord space
                // and both scale/pan together. Overlays (preview dot, confirmation)
                // stay in screen coords so they read at a fixed pixel size.
                ZStack {
                    TargetFaceCanvas(faceType: faceType)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)

                    ForEach(Array(arrows.enumerated()), id: \.element.id) { idx, arrow in
                        // Hide the arrow currently being dragged-to-reposition
                        // so the user only sees the drag preview, not a stale
                        // dot at the arrow's old location.
                        if arrow.id != movingArrowId,
                           let pos = storedPosition(for: arrow, center: center, radius: radius) {
                            ArrowDot(number: idx + 1, ring: arrow.ring, size: arrowDotSize)
                                .position(pos)
                        }
                    }
                }
                .scaleEffect(currentZoom, anchor: .center)
                .offset(panOffset)
                .animation(.easeOut(duration: 0.15), value: committedZoom)
                .animation(.easeOut(duration: 0.15), value: committedPan)

                // Drag preview ring under the finger so the user can see exactly
                // where the arrow will land. At 1x it sits 80pt above the finger
                // (so the thumb doesn't cover it); at zoom it sits at the finger
                // (no offset needed — the target is large enough to see clearly).
                // The ring is sized to match the *visible* arrow dot, which is
                // `arrowDotSize` at 1x and `arrowDotSize * currentZoom` at zoom.
                if let preview = dragPreviewPoint {
                    let previewSize = arrowDotSize * currentZoom
                    Circle()
                        .strokeBorder(.white, lineWidth: 1.5)
                        .frame(width: previewSize, height: previewSize)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .position(preview)
                        .allowsHitTesting(false)
                }

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
            .contentShape(Rectangle())
            .gesture(isEnabled ? combinedGesture(center: center, radius: radius,
                                                 arrowDotSize: arrowDotSize,
                                                 panLimit: panLimit) : nil)
            // Clip to the square frame so a zoomed-and-scaled target cannot
            // render outside the section. Preserves the natural
            // circle-in-square look at 1×; at higher zoom the scaled content
            // is contained within the original square footprint.
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityIdentifier("target_plot_canvas")
        .accessibilityLabel("Target face, \(faceType.label). Zoom \(Int(currentZoom * 100)) percent.")
        .onChange(of: isZoomed) { _, newValue in
            onZoomChanged?(newValue)
        }
    }

    // MARK: - Gesture composition

    private func combinedGesture(center: CGPoint, radius: CGFloat,
                                 arrowDotSize: CGFloat, panLimit: CGFloat) -> some Gesture {
        let pinch = MagnificationGesture()
            .updating($liveMagnification) { value, state, _ in state = value }
            .onChanged { _ in markPinchInProgress() }
            .onEnded { value in
                let newZoom = min(max(committedZoom * value, 1.0), 8.0)
                if newZoom <= 1.01 {
                    committedZoom = 1.0
                    committedPan = .zero
                } else {
                    committedZoom = newZoom
                    let newLimit = max(0, radius * (newZoom - 1))
                    committedPan = clampPan(committedPan, panLimit: newLimit)
                }
                scheduleClearPinchFlag()
            }

        let drag = DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pinchInProgress {
                    dragPreviewPoint = nil
                    return
                }
                // On the first sub-pixel of motion, decide whether the gesture
                // started on top of an existing arrow. If so, enter "moving"
                // mode and the release will replot that arrow instead of
                // placing a new one. Triggering on any non-zero translation
                // (rather than waiting for tapSlop) makes the pickup feel
                // instant — the original dot vanishes and the preview ring
                // appears at the finger as soon as the archer starts moving.
                let translationMag = hypot(value.translation.width, value.translation.height)
                if movingArrowId == nil && translationMag > 0 {
                    if let hitId = hitTestArrow(at: value.startLocation,
                                                center: center, radius: radius,
                                                dotSize: arrowDotSize) {
                        movingArrowId = hitId
                    }
                }

                if isZoomed {
                    // Show preview at the finger so the user can see exactly
                    // where the arrow will land — no thumb offset needed at
                    // zoom because the target is large enough to be visible
                    // around the finger.
                    dragPreviewPoint = value.location
                } else {
                    dragPreviewPoint = CGPoint(x: value.location.x,
                                               y: value.location.y - touchOffset)
                }
            }
            .onEnded { value in
                let movedId = movingArrowId
                dragPreviewPoint = nil
                movingArrowId = nil
                if pinchInProgress { return }
                let dotNormRadius = Double(arrowDotSize / 2) / Double(radius)

                if isZoomed {
                    // At zoom, both tap and drag place at the finger position
                    // (no offset). Pan-via-drag is intentionally absent — to
                    // navigate, pinch out and re-pinch in elsewhere.
                    handleTap(at: value.location, center: center, radius: radius,
                              arrowNormRadius: dotNormRadius, replotId: movedId)
                    return
                }
                // At 1x: short translation = tap (place directly, no offset);
                // longer translation = drag (place at finger-80pt preview point).
                let translationMag = hypot(value.translation.width, value.translation.height)
                let screenPoint: CGPoint = translationMag < tapSlop
                    ? value.location
                    : CGPoint(x: value.location.x, y: value.location.y - touchOffset)
                handleTap(at: screenPoint, center: center, radius: radius,
                          arrowNormRadius: dotNormRadius, replotId: movedId)
            }

        return SimultaneousGesture(pinch, drag)
    }

    private func markPinchInProgress() {
        pinchCooldownTask?.cancel()
        pinchInProgress = true
        // If the archer started a pinch from on top of an arrow, the drag
        // gesture may have already entered moving mode for that arrow's id.
        // Clear it so the dot doesn't briefly disappear during the pinch.
        movingArrowId = nil
    }

    private func scheduleClearPinchFlag() {
        pinchCooldownTask?.cancel()
        pinchCooldownTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run { pinchInProgress = false }
        }
    }

    private func clampPan(_ pan: CGSize, panLimit: CGFloat) -> CGSize {
        CGSize(
            width: min(max(pan.width, -panLimit), panLimit),
            height: min(max(pan.height, -panLimit), panLimit)
        )
    }

    // MARK: - Hit Testing

    /// Returns the id of the arrow whose visible (post-zoom) dot is closest to
    /// `point` and within finger-touch range, or `nil` if the gesture started
    /// on empty target space. Used to decide between placing a new arrow and
    /// dragging an existing one.
    private func hitTestArrow(at point: CGPoint, center: CGPoint, radius: CGFloat,
                              dotSize: CGFloat) -> String? {
        // Use the visible (post-zoom) dot radius plus a small finger-touch
        // buffer so users don't have to be pixel-perfect.
        let hitRadius = (dotSize * currentZoom) / 2 + 12
        var best: (id: String, dist: CGFloat)? = nil
        for arrow in arrows {
            guard let pos = storedPosition(for: arrow, center: center, radius: radius) else { continue }
            // storedPosition is in unscaled target coords; convert to screen
            // space using the same zoom + pan transform applied to the inner
            // ZStack so the hit area lines up with what the user sees.
            let screenX = center.x + (pos.x - center.x) * currentZoom + panOffset.width
            let screenY = center.y + (pos.y - center.y) * currentZoom + panOffset.height
            let dist = hypot(point.x - screenX, point.y - screenY)
            if dist <= hitRadius && (best == nil || dist < best!.dist) {
                best = (arrow.id, dist)
            }
        }
        return best?.id
    }

    // MARK: - Tap Handling

    private func handleTap(at point: CGPoint, center: CGPoint, radius: CGFloat,
                           arrowNormRadius: Double, replotId: String? = nil) {
        // Undo the zoom/pan applied to the inner ZStack so we recover the
        // unscaled target-space coordinate of the tap. Screen y is positive-down.
        let dxScreen = point.x - center.x
        let dyScreen = point.y - center.y
        let dxTarget = (dxScreen - panOffset.width)  / currentZoom
        let dyTargetScreen = (dyScreen - panOffset.height) / currentZoom
        // Math-y (positive = up) is the negation of screen-y.
        let dyMath = -dyTargetScreen

        let dist = sqrt(dxTarget * dxTarget + dyMath * dyMath)
        let normalizedDist = Double(dist / radius)

        // Shift inward by the dot radius: if any visible part of the dot touches a higher ring, score it.
        let scoringDist = max(0.0, normalizedDist - arrowNormRadius)

        guard let ring = geometry.ring(for: scoringDist) else { return }

        let angle = atan2(Double(dyMath), Double(dxTarget)) * 180 / .pi
        let zone = geometry.zone(for: normalizedDist, angle: angle)

        // Normalized position stored with the arrow (-1…1 relative to center);
        // plotY is positive = down in screen coords (matches existing data).
        let normX = Double(dxTarget) / Double(radius)
        let normY = Double(dyTargetScreen) / Double(radius)

        // Show confirmation
        let ringLabel = ring == 11 ? "X" : "\(ring)"
        confirmationText = ringLabel
        confirmationPosition = clampedLabelPosition(for: point, in: CGPoint(x: 0, y: 0))
        showConfirmation(near: point)

        if let replotId {
            onArrowReplotted?(replotId, ring, zone, normX, normY)
        } else {
            onArrowPlotted(ring, zone, normX, normY)
        }
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
        // Legacy fallback: reconstruct from ring/zone using this face's geometry.
        let normR = normalizedRadius(for: arrow.ring, zone: arrow.zone)
        let angle = compassAngle(for: arrow.zone)
        let dx = CGFloat(normR) * radius * CGFloat(cos(angle))
        let dy = CGFloat(normR) * radius * CGFloat(sin(angle))
        return CGPoint(x: center.x + dx, y: center.y - dy)
    }

    private func normalizedRadius(for ring: Int, zone: ArrowPlot.Zone) -> Double {
        let jitter = pseudoJitter(for: ring)
        if ring == geometry.xRingValue {
            return zone == .center ? 0.02 : (geometry.xRadius * 0.7) + jitter * 0.01
        }
        // Ring value -> index into `geometry.rings`.
        // outerRingValue corresponds to rings[0]; incrementing ring -> inward.
        let idx = ring - geometry.outerRingValue
        guard idx >= 0, idx < geometry.rings.count else { return 0.5 }
        let outer = geometry.rings[idx]
        let inner: Double = (idx == geometry.rings.count - 1) ? geometry.xRadius : geometry.rings[idx + 1]
        return midpoint(inner, outer) + jitter * 0.04
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

// MARK: - Target Face Canvas

/// Draws the concentric coloured rings for a given target face using SwiftUI
/// Canvas. Sized to fill whatever frame it's given; `radius` is derived from
/// `min(width, height) / 2`.
struct TargetFaceCanvas: View {
    var faceType: TargetFaceType

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let geo = TargetGeometry.preset(for: faceType)

            // Outer-most ring outward fill — paint the widest ring first, then
            // paint each inner ring on top so only the "annular" band of each
            // colour is visible.
            let colors = ringFillColors(for: faceType)

            // Face background: paint the outer-most ring as a filled disc.
            // Then overlay each inner ring as a smaller disc.
            for (idx, outerRadius) in geo.rings.enumerated() {
                let r = radius * CGFloat(outerRadius)
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(colors[idx]))
            }

            // X ring — inner-most yellow disc, same colour as ring 10.
            let xR = radius * CGFloat(geo.xRadius)
            let xRect = CGRect(x: center.x - xR, y: center.y - xR, width: xR * 2, height: xR * 2)
            context.fill(Path(ellipseIn: xRect), with: .color(.appTargetGold))

            // Thin stroked divider circles between every ring + X.
            let dividerRadii: [Double] = geo.rings + [geo.xRadius]
            let dividerColor = dividerStrokeColor(for: faceType)
            for rNorm in dividerRadii {
                let r = radius * CGFloat(rNorm)
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(dividerColor), lineWidth: 0.6)
            }

            // X tick: small cross at centre so the X ring reads as X even when shrunk.
            let tickR = radius * CGFloat(geo.xRadius) * 0.55
            var tick = Path()
            tick.move(to: CGPoint(x: center.x - tickR, y: center.y))
            tick.addLine(to: CGPoint(x: center.x + tickR, y: center.y))
            tick.move(to: CGPoint(x: center.x, y: center.y - tickR))
            tick.addLine(to: CGPoint(x: center.x, y: center.y + tickR))
            context.stroke(tick, with: .color(.appTargetInk.opacity(0.6)), lineWidth: 0.8)
        }
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }

    /// Colour of each ring (outer-most first), matching the ring order in
    /// `TargetGeometry.rings`. Every consecutive pair of rings in the WA face
    /// share a colour (outer/inner white, outer/inner black, ... ).
    private func ringFillColors(for faceType: TargetFaceType) -> [Color] {
        switch faceType {
        case .sixRing:
            // Colour bands on the compound 6-ring face, outer → inner:
            //   ring 6  → blue
            //   rings 7 → red (ring-7 outer band sits at the red-ring outer edge)
            //   ring 8  → red
            //   rings 9 → yellow
            //   ring 10 → yellow (outer yellow band; X ring is filled separately)
            return [
                .appTargetBlue,    // ring 6
                .appTargetRed,     // ring 7
                .appTargetRed,     // ring 8
                .appTargetYellow,  // ring 9
                .appTargetYellow   // ring 10
            ]
        case .tenRing:
            return [
                .appTargetWhite,   // ring 1
                .appTargetWhite,   // ring 2
                .appTargetBlack,   // ring 3
                .appTargetBlack,   // ring 4
                .appTargetBlue,    // ring 5
                .appTargetBlue,    // ring 6
                .appTargetRed,     // ring 7
                .appTargetRed,     // ring 8
                .appTargetYellow,  // ring 9
                .appTargetYellow   // ring 10
            ]
        }
    }

    private func dividerStrokeColor(for faceType: TargetFaceType) -> Color {
        switch faceType {
        case .sixRing: return .appTargetInk.opacity(0.25)
        case .tenRing: return .appTargetInk.opacity(0.25)
        }
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
                .overlay(
                    Circle()
                        .strokeBorder(outlineColor, lineWidth: outlineWidth)
                )
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
        case 11: return .appTargetGold      // X
        case 10: return .appTargetYellow
        case 9:  return .appTargetYellow
        case 8:  return .appTargetRed
        case 7:  return .appTargetRed
        case 6:  return .appTargetBlue
        case 5:  return .appTargetBlue      // 10-ring: ring 5 is the inner blue band
        case 4:  return .appTargetBlack
        case 3:  return .appTargetBlack
        case 2:  return .appTargetWhite
        case 1:  return .appTargetWhite
        default: return .gray
        }
    }

    /// White dots on the outer white rings need a dark border to be visible;
    /// black dots on the black rings need a light border for the same reason.
    private var outlineColor: Color {
        switch ring {
        case 1, 2:  return .appTargetInk.opacity(0.85)
        case 3, 4:  return .appTargetWhite.opacity(0.9)
        default:    return .clear
        }
    }

    private var outlineWidth: CGFloat {
        switch ring {
        case 1, 2, 3, 4: return 1.0
        default: return 0
        }
    }

    private var textColor: Color {
        switch ring {
        case 9, 10, 11: return .appTargetInk     // dark ink on yellow/gold
        case 1, 2:      return .appTargetInk     // dark ink on white
        case 3, 4:      return .white            // white on black
        default:        return .white
        }
    }
}

// MARK: - Preview

#Preview("6-Ring (compound)") {
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

    return VStack(spacing: 20) {
        TargetPlotView(arrows: arrows,
                       onArrowPlotted: { _, _, _, _ in },
                       faceType: .sixRing)
            .frame(width: 320, height: 320)
            .padding()
    }
}

#Preview("10-Ring (recurve)") {
    let arrows: [ArrowPlot] = [
        ArrowPlot(id: "1", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "ac1",
                  ring: 11, zone: .center, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "2", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "ac1",
                  ring: 8, zone: .ne, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "3", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "ac1",
                  ring: 5, zone: .w, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "4", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "ac1",
                  ring: 2, zone: .se, shotAt: Date(), excluded: false, notes: nil),
    ]

    return VStack(spacing: 20) {
        TargetPlotView(arrows: arrows,
                       onArrowPlotted: { _, _, _, _ in },
                       faceType: .tenRing)
            .frame(width: 320, height: 320)
            .padding()
    }
}
