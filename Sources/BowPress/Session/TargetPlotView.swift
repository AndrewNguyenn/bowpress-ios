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
    /// Real-world *scoring face* radius in millimetres (the printed WA
    /// face), per the standard spec. `mmPerNormUnit` divides this by
    /// `rings.first` to recover the displayed *canvas* radius — accounting
    /// for any white margin the asset draws beyond the scoring face.
    let realFaceRadiusMm: Double

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
        outerRingValue: 6,
        realFaceRadiusMm: 400      // 80cm WA compound face → 400mm radius
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
        outerRingValue: 1,
        realFaceRadiusMm: 610      // 122cm WA full face → 610mm radius
    )

    static func preset(for faceType: TargetFaceType) -> TargetGeometry {
        switch faceType {
        case .sixRing: return .sixRing
        case .tenRing: return .tenRing
        }
    }

    /// Real mm per 1.0 normalised display unit (where 1.0 = the canvas
    /// radius — the displayed circle, which may include white margin
    /// beyond the printed scoring face). Used to convert arrow shaft
    /// diameter from mm to display pt for both the rendered dot and the
    /// WA edge-rule scoring offset.
    ///
    /// `realFaceRadiusMm` is the scoring face radius. The displayed canvas
    /// extends out to `rings.first` in normalised units — for sixRing the
    /// asset shows 19% white margin beyond ring 6, so the canvas radius in
    /// mm is `400 / 0.808 ≈ 495`. For tenRing `rings.first == 1.0` and the
    /// canvas matches the scoring face exactly.
    ///
    /// Was previously `20 / ring10Outer`, which only matched a 40cm Vegas
    /// face — combined with a `max(..., 8)` floor on the dot size it made
    /// 4mm and 9mm shafts render identically and scored with an inflated
    /// edge radius (~5× too lenient).
    var mmPerNormUnit: Double {
        let canvasFraction = rings.first ?? 1.0
        guard canvasFraction > 0 else { return realFaceRadiusMm }
        return realFaceRadiusMm / canvasFraction
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

    /// Recompute a plot position so it lands inside the colored band of
    /// `targetRing`, preserving the angle from center. Used by the score
    /// keypad's "quick edit" path: if the archer corrects a score from 8
    /// → 6 without re-plotting, we don't want a blue dot stuck in the red
    /// zone (and the reverse). The angle is preserved; only the radial
    /// distance is shifted into the new ring's band.
    ///
    /// Returns nil when no snap is needed — misses, rings outside the
    /// geometry's valid range, OR when the existing radius already lands
    /// inside the target ring's band. The nil-when-in-band case is what
    /// keeps a same-score chip tap (or a 7→8 re-score where the dot was
    /// already at the boundary) from yanking the dot away from where the
    /// archer actually placed it.
    func snappedPosition(forRing targetRing: Int, from oldX: Double, _ oldY: Double) -> (x: Double, y: Double)? {
        guard targetRing > 0 else { return nil }
        let oldR = sqrt(oldX * oldX + oldY * oldY)

        // Resolve the new ring's band (inner..outer radii in normalized units).
        let bandOuter: Double
        let bandInner: Double
        if targetRing == xRingValue {
            bandOuter = xRadius
            bandInner = 0
        } else {
            let idx = targetRing - outerRingValue
            guard idx >= 0 && idx < rings.count else { return nil }
            bandOuter = rings[idx]
            bandInner = (idx == rings.count - 1) ? xRadius : rings[idx + 1]
        }

        // If the existing plot already sits inside the new band, leave it
        // alone — the archer's chosen position is fine and any snap here
        // would just move the dot for no visible-correctness gain.
        if oldR >= bandInner && oldR < bandOuter {
            return nil
        }

        // No usable angle at the exact center: pick a deterministic default
        // (straight up) so the snap doesn't crash. Otherwise preserve angle.
        let theta = oldR > 0.0001 ? atan2(oldY, oldX) : -.pi / 2
        let newR = (bandInner + bandOuter) / 2.0
        return (x: newR * cos(theta), y: newR * sin(theta))
    }

    /// Convenience wrapper for the common "I have an `ArrowPlot`-style
    /// (plotX, plotY) and need a zone" path. `plotY` is screen-down-positive
    /// throughout the persisted plot model; this helper does the y-flip and
    /// degree conversion so callers don't have to remember the convention.
    /// Used by the live plot path and the Quick Edit chip handler — both
    /// must agree on (x,y)→zone or the persisted zone drifts out of sync
    /// with the coordinates (issue #13).
    func zone(forPlotX x: Double, plotY y: Double) -> ArrowPlot.Zone {
        let normR = sqrt(x * x + y * y)
        let angleDeg = atan2(-y, x) * 180 / .pi
        return zone(for: normR, angle: angleDeg)
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
    /// Fired when the target transitions between unzoomed (1×) and zoomed
    /// states. Lets the parent fade out informational overlays that would
    /// otherwise sit underneath the magnified target.
    var onZoomChanged: ((Bool) -> Void)? = nil
    /// Fired on every drag update with a snapshot describing how to render
    /// the Pen magnifier in *global* screen coordinates. The caller renders
    /// `PenLensView(snapshot:)` at its own root z-level (typically via
    /// `PenLensOverlay(controller:)`) so the lens can extend over the
    /// entire screen viewport rather than being trapped inside the
    /// target's bounded frame. Optional only for tests and previews;
    /// production paths always wire it up.
    var onLensSnapshotChanged: ((PenLensSnapshot?) -> Void)? = nil
    var isEnabled: Bool = true
    var arrowDiameterMm: Double = 5.0
    var faceType: TargetFaceType = .sixRing

    // MARK: - Pen magnifier constants (design: explorations/Live Session - Tap-Drag-Release.html)

    /// Lens diameter as a fraction of the target face diameter. Design ships
    /// 240/320 = 0.75.
    private let lensSizeRatio: CGFloat = 0.75
    /// Magnification factor inside the lens. Design ships 2.5×.
    private let lensZoom: CGFloat = 2.5
    /// Vertical offset of the score stamp above the lens (in pt).
    private let stampOffset: CGFloat = 46

    private var geometry: TargetGeometry { TargetGeometry.preset(for: faceType) }

    // Confirmation overlay state
    @State private var confirmationText: String?
    @State private var confirmationPosition: CGPoint = .zero
    @State private var confirmationOpacity: Double = 0
    @State private var confirmationTask: Task<Void, Never>?

    /// True while a plot drag is in flight. Drives `markPinchInProgress`
    /// bookkeeping but doesn't trigger any rendering — the lens itself is
    /// owned by the caller via `PenLensController`.
    @State private var isPlotting: Bool = false

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
            // Arrow shaft diameter scaled to real-world mm on the drawn face.
            // No minimum clamp — the WA edge-rule scoring and the lens
            // footprint both read from this value, so floors here would
            // inflate the visible-overlap rule (4mm shafts would score like
            // 8mm shafts). A tiny floor (2pt) keeps the dot from collapsing
            // to nothing on very small displays but doesn't materially
            // change scoring for any real-world arrow.
            let arrowDotSize = max(
                CGFloat(arrowDiameterMm / geometry.mmPerNormUnit) * radius,
                2
            )
            // Slightly larger clamp for the visible dot label (so the index
            // number can fit), but only at the display layer — does not
            // feed scoring or lens math.
            let displayedDotSize = max(arrowDotSize, 8)
            let panLimit = max(0, radius * (currentZoom - 1))

            ZStack {
                // Scaled group: target + placed arrows share the same coord space
                // and both scale/pan together. Clip ONLY this layer so a
                // pinch-zoomed face can't spill, while leaving the Pen
                // magnifier free to extend outside the target's bounds.
                ZStack {
                    TargetFaceCanvas(faceType: faceType)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)

                    ForEach(Array(arrows.enumerated()), id: \.element.id) { idx, arrow in
                        if let pos = storedPosition(for: arrow, center: center, radius: radius) {
                            ArrowDot(number: idx + 1, ring: arrow.ring, size: displayedDotSize)
                                .position(pos)
                        }
                    }
                }
                .scaleEffect(currentZoom, anchor: .center)
                .offset(panOffset)
                .animation(.easeOut(duration: 0.15), value: committedZoom)
                .animation(.easeOut(duration: 0.15), value: committedPan)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

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

                // Pen magnifier — kept at the END of the ZStack and unclipped
                // so it can extend past the target's frame in any direction.
                // The lens floats just above the thumb's covering zone (~30pt)
                // with a small buffer so the dead center stays unobscured.
                // The lens body itself can overlap the thumb's outer rim;
                // that's by design — the surrounding magnified rings remain
                // readable around the thumb edges.
                //
                // Only renders at 1× — a pinch-zoomed face already provides
                // magnification; layering the lens on top creates a confusing
                // double-zoom.
            }
            .contentShape(Rectangle())
            .gesture(isEnabled ? combinedGesture(center: center, radius: radius,
                                                 arrowDotSize: arrowDotSize,
                                                 panLimit: panLimit, geo: geo) : nil)
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
                                 arrowDotSize: CGFloat, panLimit: CGFloat,
                                 geo: GeometryProxy) -> some Gesture {
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
                    if isPlotting { onLensSnapshotChanged?(nil) }
                    isPlotting = false
                    return
                }
                let ring = previewRing(at: value.location,
                                       center: center, radius: radius,
                                       arrowDotSize: arrowDotSize)
                isPlotting = true
                // Publishing the snapshot is the ONLY side effect of a drag
                // tick. No @State writes here — the lens position is
                // tracked by `PenLensController` which is `@Observable`, so
                // re-render scope stays inside `PenLensOverlay`.
                publishLensSnapshot(touchLocal: value.location, geo: geo,
                                    center: center, radius: radius,
                                    arrowDotSize: arrowDotSize,
                                    previewRing: ring)
            }
            .onEnded { value in
                if isPlotting { onLensSnapshotChanged?(nil) }
                isPlotting = false
                if pinchInProgress { return }
                let dotNormRadius = Double(arrowDotSize / 2) / Double(radius)

                // Pen magnifier commits at the finger position — same at 1×
                // and at pinch-zoom. No thumb-offset, no slop branching, no
                // drag-pickup-of-existing-arrow (use ArrowEditSheet for
                // corrections so a tap near a tight group can't accidentally
                // move the wrong arrow).
                handleTap(at: value.location, center: center, radius: radius,
                          arrowNormRadius: dotNormRadius)
            }

        return SimultaneousGesture(pinch, drag)
    }

    private func markPinchInProgress() {
        pinchCooldownTask?.cancel()
        pinchInProgress = true
    }

    private func publishLensSnapshot(touchLocal: CGPoint, geo: GeometryProxy,
                                     center: CGPoint, radius: CGFloat,
                                     arrowDotSize: CGFloat, previewRing: Int?) {
        guard let emit = onLensSnapshotChanged, !isZoomed else { return }
        let globalOrigin = geo.frame(in: .global).origin
        let touchGlobal = CGPoint(x: globalOrigin.x + touchLocal.x,
                                  y: globalOrigin.y + touchLocal.y)
        let faceOriginGlobal = CGPoint(x: globalOrigin.x + (center.x - radius),
                                       y: globalOrigin.y + (center.y - radius))
        emit(PenLensSnapshot(
            touchScreen: touchGlobal,
            faceOriginScreen: faceOriginGlobal,
            faceSize: radius * 2,
            arrowDotSize: arrowDotSize,
            faceType: faceType,
            arrows: arrows,
            previewRing: previewRing
        ))
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

    // MARK: - Tap Handling

    private func handleTap(at point: CGPoint, center: CGPoint, radius: CGFloat,
                           arrowNormRadius: Double) {
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

        // Normalized position stored with the arrow (-1…1 relative to center);
        // plotY is positive = down in screen coords (matches existing data).
        let normX = Double(dxTarget) / Double(radius)
        let normY = Double(dyTargetScreen) / Double(radius)
        let zone = geometry.zone(forPlotX: normX, plotY: normY)

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

    // MARK: - Pen magnifier

    /// Computes the ring that would be awarded if the archer released right
    /// now at `point` (unzoomed target-local coords). Uses the exact same
    /// math as `handleTap` — the design's lookup table is intentionally NOT
    /// used because its band thresholds are off by ~one ring relative to
    /// our `TargetGeometry.ring(for:)` data. Returns nil for a miss.
    private func previewRing(at point: CGPoint, center: CGPoint,
                             radius: CGFloat, arrowDotSize: CGFloat) -> Int? {
        let dxScreen = point.x - center.x
        let dyScreen = point.y - center.y
        let dxTarget = (dxScreen - panOffset.width) / currentZoom
        let dyTargetScreen = (dyScreen - panOffset.height) / currentZoom
        let dyMath = -dyTargetScreen
        let dist = sqrt(dxTarget * dxTarget + dyMath * dyMath)
        let normalizedDist = Double(dist / radius)
        let arrowNormRadius = Double(arrowDotSize / 2) / Double(radius)
        let scoringDist = max(0.0, normalizedDist - arrowNormRadius)
        return geometry.ring(for: scoringDist)
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
                context.stroke(Path(ellipseIn: rect), with: .color(dividerColor), lineWidth: 0.75)
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

    /// Solid ink-black hairline between rings. The visible line sits exactly
    /// at each ring's outer radius, which is also the WA edge-rule boundary
    /// — `TargetGeometry.ring(for:)` returns the inner (higher) ring number
    /// whenever `normalizedDist < ringRadius`, so an arrow whose visible
    /// edge touches the line scores the higher value.
    private func dividerStrokeColor(for faceType: TargetFaceType) -> Color {
        .appTargetInk
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

// MARK: - PenLensSnapshot + PenLensView (screen-level magnifier)
//
// Lets a parent render the Pen magnifier at its own root z-level so the
// lens can extend past the target's frame, sit above bottom action rows,
// and only get clipped by the actual screen viewport. TargetPlotView
// emits the snapshot via `onLensSnapshotChanged`; the parent stores it
// in @State and places `PenLensView(snapshot:)` at the top of its outer
// ZStack.

/// Holds the live lens snapshot. Made `@Observable` so only views that
/// actually read `.snapshot` (i.e. `PenLensOverlay`) re-render on each
/// drag tick — `SessionView.body` doesn't, which keeps the full
/// ScrollView contents from diffing 60+ times a second during a plot.
@Observable
final class PenLensController {
    var snapshot: PenLensSnapshot? = nil
}

/// Renders the live lens — kept separate so it's the only view that
/// observes the controller. Drops the implicit-opacity transition that
/// could blur the first frame of a movement against the body's
/// re-render cadence.
struct PenLensOverlay: View {
    let controller: PenLensController
    var body: some View {
        if let snap = controller.snapshot {
            PenLensView(snapshot: snap)
        }
    }
}

struct PenLensSnapshot: Equatable {
    /// Touch in global screen coords (where the user's finger is).
    let touchScreen: CGPoint
    /// Top-left of the target face in global screen coords. Used to map
    /// the face's local coord space + already-plotted arrows back into the
    /// screen-positioned lens content.
    let faceOriginScreen: CGPoint
    /// Edge length of the target face square (face is a circle inscribed
    /// in this square).
    let faceSize: CGFloat
    /// Arrow dot size at 1× scale for the current face geometry — same
    /// value TargetPlotView uses inside the lens math.
    let arrowDotSize: CGFloat
    let faceType: TargetFaceType
    let arrows: [ArrowPlot]
    /// Ring (1–11 or nil for miss) at the live touch point — drives the
    /// stamp label/color.
    let previewRing: Int?
}

struct PenLensView: View {
    let snapshot: PenLensSnapshot

    private let lensSizeRatio: CGFloat = 0.75
    private let lensZoom: CGFloat = 2.5
    private let stampOffset: CGFloat = 46
    private let thumbHalfPt: CGFloat = 30
    private let centerBuffer: CGFloat = 10

    var body: some View {
        GeometryReader { screen in
            let touch = snapshot.touchScreen
            let lensSize = max(120, snapshot.faceSize * lensSizeRatio)
            let lensRadius = lensSize / 2
            let zoomedFaceSize = snapshot.faceSize * lensZoom

            // Prefer above the finger; flip below only if the lens top would
            // clip the screen's top edge. This is the key difference from the
            // old in-target rendering: the lens can extend into header space
            // because we're laying it out in screen coords.
            let touchClearance = thumbHalfPt + centerBuffer
            let edgeBuffer: CGFloat = 4
            let preferredAboveY = touch.y - touchClearance
            let lensTopIfAbove = preferredAboveY - lensRadius
            let placeBelow = lensTopIfAbove < edgeBuffer
            let lensCenterY = placeBelow
                ? touch.y + touchClearance
                : preferredAboveY
            let lensCenterX = min(max(touch.x, lensRadius + edgeBuffer),
                                  screen.size.width - lensRadius - edgeBuffer)
            let lensCenter = CGPoint(x: lensCenterX, y: lensCenterY)

            // Translate the zoomed face so the touch (in face-local coords)
            // lands at the lens center.
            let touchFaceX = touch.x - snapshot.faceOriginScreen.x
            let touchFaceY = touch.y - snapshot.faceOriginScreen.y
            let contentOffsetX = lensRadius - touchFaceX * lensZoom
            let contentOffsetY = lensRadius - touchFaceY * lensZoom
            // Footprint ring visual size. The source `arrowDotSize` is
            // unclamped (so scoring math stays honest), which on a thin
            // shaft at 1× could be ~1pt and disappear into the lens
            // background. Apply an 8pt readability floor at the display
            // layer only — does not affect scoring or geometry math.
            let footprintSize = max(snapshot.arrowDotSize * lensZoom, 8)

            ZStack {
                // Lens body
                ZStack {
                    ZStack(alignment: .topLeading) {
                        TargetFaceCanvas(faceType: snapshot.faceType)
                            .frame(width: zoomedFaceSize, height: zoomedFaceSize)
                            .offset(x: contentOffsetX, y: contentOffsetY)
                        ForEach(Array(snapshot.arrows.enumerated()), id: \.element.id) { idx, arrow in
                            if let pos = arrowPositionInFace(arrow) {
                                ArrowDot(number: idx + 1, ring: arrow.ring,
                                         size: snapshot.arrowDotSize * lensZoom)
                                    .position(x: pos.x * lensZoom + contentOffsetX,
                                              y: pos.y * lensZoom + contentOffsetY)
                            }
                        }
                    }
                    .frame(width: lensSize, height: lensSize, alignment: .topLeading)
                    .background(Color.appPaper)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.appInk, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.34), radius: 16, y: 12)

                    // Maple footprint ring + pin.
                    ZStack {
                        Circle().fill(Color.appMaple.opacity(0.18))
                        Circle().strokeBorder(Color.appMaple, lineWidth: 2)
                        Circle().fill(Color.appMaple).frame(width: 3, height: 3)
                    }
                    .frame(width: footprintSize, height: footprintSize)
                }
                .frame(width: lensSize, height: lensSize)
                .position(lensCenter)

                // Score stamp — anchored above the lens (or below the lens
                // when flipped). Stamp position is clamped so it can't go
                // off the top of the screen.
                stamp
                    .position(x: lensCenterX,
                              y: max(stampOffset / 2,
                                     lensCenterY - lensRadius - stampOffset))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func arrowPositionInFace(_ arrow: ArrowPlot) -> CGPoint? {
        guard let px = arrow.plotX, let py = arrow.plotY else { return nil }
        let r = snapshot.faceSize / 2
        return CGPoint(x: r + CGFloat(px) * r, y: r + CGFloat(py) * r)
    }

    private var stamp: some View {
        let geometry = TargetGeometry.preset(for: snapshot.faceType)
        let (label, background): (String, Color) = {
            guard let ring = snapshot.previewRing else { return ("M", .appMaple) }
            if ring == geometry.xRingValue { return ("X", .appPondDk) }
            return ("\(ring)", .appInk)
        }()
        return Text(label)
            .font(.bpDisplay(28, italic: true, weight: .medium))
            .foregroundStyle(Color.appPaper)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(background)
            .overlay(Rectangle().strokeBorder(background, lineWidth: 1))
            .fixedSize()
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
