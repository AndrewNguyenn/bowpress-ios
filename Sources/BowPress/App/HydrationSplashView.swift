import SwiftUI

// MARK: - Local hex helper
//
// AppTheme.swift owns the canonical `hex(_:)` but it's fileprivate. The two
// outermost ring fills (#d9e1d8 mist, #b8cdd0 haze) aren't exposed as named
// tokens, so we duplicate the helper here for the few one-off colors the
// splash needs.

private func splashHex(_ s: String) -> Color {
    var h = s.trimmingCharacters(in: .init(charactersIn: "#"))
    if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
    var rgb: UInt64 = 0
    Scanner(string: h).scanHexInt64(&rgb)
    let r = Double((rgb >> 16) & 0xFF) / 255
    let g = Double((rgb >>  8) & 0xFF) / 255
    let b = Double( rgb        & 0xFF) / 255
    return Color(red: r, green: g, blue: b)
}

// MARK: - HydrationSplashView
//
// Native SwiftUI port of the splash spec at
// bowpress-design-system/project/explorations/splash/index.html. Mirrors the
// 2.4s plot-in sequence: pond-gradient rings scale in, hairlines fade over,
// 12 arrows plot one-by-one (last is a maple-outlined flier), pond-dk
// crosshair settles on the centroid, wordmark fades up with a hairline rule,
// "ANALYZING YOUR DATA" + a pulsing maple dot, and bottom telemetry ticks in.
//
// ContentView keeps this view mounted while either AppState.isHydrating is
// true OR the splash hasn't reached its minimum-display gate (~2.6s), then
// fades it out with a 450ms opacity transition.

struct HydrationSplashView: View {

    /// Called once the animation has played long enough to "land" — ContentView
    /// uses this to gate dismissal so a fast hydrate doesn't truncate the motion.
    var onMinimumElapsed: (() -> Void)? = nil

    // Single-trigger flags. Each animated element applies its own
    // `.animation(... .delay(N), value: started)` so flipping `started` once
    // fans out into the staggered timeline.
    @State private var started = false

    // Spec coordinates live in a 200×200 viewBox; we render into a
    // `targetSize`pt square and scale uniformly.
    private let targetSize: CGFloat = 320
    private var scale: CGFloat { targetSize / 200 }
    private var center: CGPoint { CGPoint(x: targetSize / 2, y: targetSize / 2) }

    // MARK: Ring + arrow specs

    private struct RingSpec: Identifiable {
        let id: Int
        let r: CGFloat
        let fill: Color
        let delay: Double
    }

    private let rings: [RingSpec] = [
        .init(id: 0, r: 96, fill: splashHex("#d9e1d8"), delay: 0.00),
        .init(id: 1, r: 76, fill: splashHex("#b8cdd0"), delay: 0.08),
        .init(id: 2, r: 56, fill: .appPondLt,          delay: 0.16),
        .init(id: 3, r: 36, fill: .appPond,            delay: 0.24),
        .init(id: 4, r: 16, fill: .appPondDk,          delay: 0.32),
    ]

    private let hairlineRadii: [CGFloat] = [96, 86, 76, 66, 56, 46, 36, 26, 16, 8]

    private struct ArrowSpec: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let flier: Bool
    }

    private let arrows: [ArrowSpec] = [
        .init(id: 0,  x:  98, y:  96, flier: false),
        .init(id: 1,  x: 104, y: 102, flier: false),
        .init(id: 2,  x: 100, y: 108, flier: false),
        .init(id: 3,  x:  92, y: 103, flier: false),
        .init(id: 4,  x: 106, y:  93, flier: false),
        .init(id: 5,  x:  95, y:  88, flier: false),
        .init(id: 6,  x: 112, y: 109, flier: false),
        .init(id: 7,  x:  88, y: 112, flier: false),
        .init(id: 8,  x: 102, y:  84, flier: false),
        .init(id: 9,  x: 117, y:  96, flier: false),
        .init(id: 10, x:  85, y:  94, flier: false),
        .init(id: 11, x: 148, y:  72, flier: true),
    ]

    // MARK: Body

    var body: some View {
        ZStack {
            Color.appPaper.ignoresSafeArea()

            // Centered stack: target + wordmark
            VStack(spacing: 36) {
                target
                    .frame(width: targetSize, height: targetSize)
                wordmark
            }

            // Top header — absolute, paired with bottom telemetry
            VStack {
                header
                    .padding(.horizontal, 32)
                    .padding(.top, 44)
                Spacer()
                telemetry
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
        .task {
            // Single trigger fans out into all per-element staggered animations.
            started = true

            // 2.6s buys us through arrow 12 (≈2.12s + 0.5s plot) and the
            // centroid pulse-in at 2.3s, with a small grace pad so the
            // motion lands before MainTabView crossfades in.
            try? await Task.sleep(for: .milliseconds(2600))
            onMinimumElapsed?()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("BOWPRESS")
                .font(.bpUI(11.5, weight: .semibold))
                .tracking(10.5 * 0.32)
                .foregroundStyle(Color.appPondDk)
            Spacer()
            Text("v2.4 · SYNC")
                .font(.bpMono(11))
                .tracking(9 * 0.06)
                .foregroundStyle(Color.appInk3)
        }
        .opacity(started ? 1 : 0)
        .animation(.easeOut(duration: 0.45).delay(0.1), value: started)
    }

    // MARK: Target

    private var target: some View {
        ZStack {
            // Concentric pond-gradient rings, scale-in staggered 80ms.
            ForEach(rings) { ring in
                Circle()
                    .fill(ring.fill)
                    .frame(width: ring.r * 2 * scale, height: ring.r * 2 * scale)
                    .scaleEffect(started ? 1.0 : 0.1)
                    .opacity(started ? 1 : 0)
                    .animation(
                        .timingCurve(0.2, 0.7, 0.2, 1.0, duration: 1.4)
                            .delay(ring.delay),
                        value: started
                    )
            }

            // Hairline scoring-ring overlay — fades in over 0.5s starting at 0.5s.
            ZStack {
                ForEach(Array(hairlineRadii.enumerated()), id: \.offset) { _, r in
                    Circle()
                        .stroke(Color.appInk, lineWidth: 0.4)
                        .frame(width: r * 2 * scale, height: r * 2 * scale)
                }
            }
            .opacity(started ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.5), value: started)

            // Plotted arrows — bouncy plot, staggered 120ms starting at 0.8s.
            ForEach(arrows) { arrow in
                arrowDot(arrow)
                    .position(point(arrow.x, arrow.y))
                    .scaleEffect(started ? 1.0 : 2.6)
                    .opacity(started ? 1 : 0)
                    .animation(
                        .spring(response: 0.42, dampingFraction: 0.62)
                            .delay(0.80 + 0.12 * Double(arrow.id)),
                        value: started
                    )
            }

            // Centroid crosshair — pulses in at 2.3s.
            crosshair
                .position(point(100, 99))
                .scaleEffect(started ? 1.0 : 0.2)
                .opacity(started ? 1 : 0)
                .animation(.easeOut(duration: 1.0).delay(2.3), value: started)
        }
        .frame(width: targetSize, height: targetSize)
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }

    @ViewBuilder
    private func arrowDot(_ arrow: ArrowSpec) -> some View {
        let d: CGFloat = (arrow.flier ? 2.6 : 2.4) * 2 * scale
        if arrow.flier {
            Circle()
                .stroke(Color.appMaple, lineWidth: 1.2)
                .frame(width: d, height: d)
        } else {
            Circle()
                .fill(Color.appInk)
                .frame(width: d, height: d)
        }
    }

    private var crosshair: some View {
        let r: CGFloat = 6 * scale
        let arm: CGFloat = 7 * scale
        return ZStack {
            Circle()
                .stroke(Color.appPondDk, lineWidth: 0.9)
                .frame(width: r * 2, height: r * 2)
            Path { p in
                p.move(to: CGPoint(x: 0, y: -arm))
                p.addLine(to: CGPoint(x: 0, y: arm))
                p.move(to: CGPoint(x: -arm, y: 0))
                p.addLine(to: CGPoint(x: arm, y: 0))
            }
            .stroke(Color.appPondDk, lineWidth: 0.9)
            .frame(width: arm * 2, height: arm * 2)
        }
    }

    // MARK: Wordmark + sub

    private var wordmark: some View {
        VStack(spacing: 12) {
            BPWordmark(size: 36)
                .opacity(started ? 1 : 0)
                .offset(y: started ? 0 : 6)
                .animation(
                    .timingCurve(0.2, 0.7, 0.2, 1.0, duration: 0.7).delay(0.4),
                    value: started
                )

            // 48×1 hairline rule — scaleX 0→1 at 1.0s.
            Rectangle()
                .fill(Color.appPondDk)
                .frame(width: 48, height: 1)
                .scaleEffect(x: started ? 1 : 0, y: 1, anchor: .center)
                .animation(.easeOut(duration: 0.6).delay(1.0), value: started)

            HStack(spacing: 8) {
                PulsingMapleDot(size: 5)
                Text("ANALYZING YOUR DATA")
                    .font(.bpUI(11.5, weight: .semibold))
                    .tracking(10 * 0.26)
                    .foregroundStyle(Color.appInk3)
            }
            .opacity(started ? 1 : 0)
            .offset(y: started ? 0 : 6)
            .animation(.easeOut(duration: 0.6).delay(1.1), value: started)
        }
    }

    // MARK: Telemetry

    private var telemetry: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LAST SESSION")
                    .font(.bpUI(11, weight: .semibold))
                    .tracking(9 * 0.22)
                    .foregroundStyle(Color.appPondDk)
                HStack(spacing: 4) {
                    Text("10.4 avg")
                        .font(.bpDisplay(14, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                    Text("· 72% X")
                        .font(.bpMono(11))
                        .tracking(9 * 0.06)
                        .foregroundStyle(Color.appInk3)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("LOADING")
                    .font(.bpUI(11, weight: .semibold))
                    .tracking(9 * 0.22)
                    .foregroundStyle(Color.appPondDk)
                HStack(spacing: 4) {
                    Text("342 arrows")
                        .font(.bpDisplay(14, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                    Text("· 14 sess")
                        .font(.bpMono(11))
                        .tracking(9 * 0.06)
                        .foregroundStyle(Color.appInk3)
                }
            }
        }
        .opacity(started ? 1 : 0)
        .offset(y: started ? 0 : 6)
        .animation(.easeOut(duration: 0.6).delay(1.8), value: started)
    }
}

// MARK: - PulsingMapleDot
//
// 5pt maple square that loops opacity 0.25 ⇄ 1.0 every 1.1s. Driven by
// TimelineView so we don't keep state ourselves.

private struct PulsingMapleDot: View {
    let size: CGFloat
    private let period: Double = 1.1

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: period)) / period
            // Sine wave oscillator centered on (0.25 + 1.0)/2 = 0.625
            // amplitude (1.0 - 0.25)/2 = 0.375
            let opacity = 0.625 + 0.375 * sin(phase * 2 * .pi)
            Rectangle()
                .fill(Color.appMaple)
                .frame(width: size, height: size)
                .opacity(opacity)
        }
    }
}

#Preview {
    HydrationSplashView()
        .environment(AppState())
}
