import SwiftUI

/// Launch splash shown while `LocalHydration` seeds the store. Animates a
/// sequence of arrows landing on the target face — starting in the outer
/// rings and tightening toward the center — with a heatmap blur growing
/// underneath. Lives as a `ZStack` overlay on `MainTabView` in ContentView;
/// fades out when `AppState.isHydrating` flips to false.
struct HydrationSplashView: View {

    @State private var arrowsLanded: Int = 0
    @State private var titleOpacity: Double = 0
    @State private var targetScale: CGFloat = 0.88

    /// 16 arrows in narrative "learning journey" order — wide/outer early,
    /// tightening toward center-X by the end. Each entry is (ring, zone,
    /// plotX, plotY) in the normalized -1…1 target space the heatmap uses.
    private static let arrowSequence: [ArrowPlot] = {
        func plot(_ id: Int, _ ring: Int, _ zone: ArrowPlot.Zone, _ x: Double, _ y: Double) -> ArrowPlot {
            ArrowPlot(
                id: "splash_\(id)",
                sessionId: "splash",
                bowConfigId: "splash",
                arrowConfigId: "splash",
                ring: ring,
                zone: zone,
                plotX: x,
                plotY: y,
                shotAt: Date(),
                excluded: false,
                notes: nil
            )
        }
        return [
            // Outer rings first — slightly chaotic spread
            plot( 0, 8, .nw, -0.42,  0.38),
            plot( 1, 8, .ne,  0.40, -0.28),
            plot( 2, 9, .w,  -0.32,  0.05),
            plot( 3, 8, .s,   0.08, -0.45),
            plot( 4, 9, .n,   0.05,  0.36),
            // Pulling toward center
            plot( 5, 9, .ne,  0.22,  0.18),
            plot( 6, 10, .nw, -0.18,  0.20),
            plot( 7, 9, .e,   0.26, -0.08),
            plot( 8, 10, .n,   0.02,  0.22),
            plot( 9, 10, .w, -0.18, -0.02),
            // Tight final group — 10s and Xs
            plot(10, 10, .center,  0.06,  0.10),
            plot(11, 11, .center, -0.04,  0.08),
            plot(12, 10, .center,  0.10, -0.05),
            plot(13, 11, .center,  0.02, -0.02),
            plot(14, 11, .center, -0.02,  0.04),
            plot(15, 11, .center,  0.04,  0.02),
        ]
    }()

    private var visibleArrows: [ArrowPlot] {
        Array(Self.arrowSequence.prefix(arrowsLanded))
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 6) {
                    Text("BowPress")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appAccent)
                    Text("Plotting your practice…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(titleOpacity)

                SplashTargetView(arrows: visibleArrows)
                    .frame(maxWidth: 280)
                    .aspectRatio(1, contentMode: .fit)
                    .scaleEffect(targetScale)
                    .padding(.horizontal, 40)

                Spacer()
                Spacer()
            }
        }
        .task { await runAnimation() }
    }

    private func runAnimation() async {
        withAnimation(.easeOut(duration: 0.5)) { titleOpacity = 1 }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { targetScale = 1.0 }

        // Slight initial pause so the target can settle before arrows land.
        try? await Task.sleep(for: .milliseconds(180))

        for i in 1...Self.arrowSequence.count {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                arrowsLanded = i
            }
            // Arrows land slightly faster as the group tightens — builds rhythm.
            let delayMs = i < 5 ? 110 : (i < 10 ? 85 : 65)
            try? await Task.sleep(for: .milliseconds(delayMs))
        }
    }
}

/// Target face + heatmap blur + animated arrow dots. Small, self-contained
/// cousin of `SessionHeatMapView` — duplicated rather than hoisted because
/// the splash has its own sizing/styling needs and we want zero risk of
/// coupling the real heatmap to launch-time animation concerns.
private struct SplashTargetView: View {
    let arrows: [ArrowPlot]

    var body: some View {
        Image("target_face")
            .resizable()
            .scaledToFit()
            .overlay {
                // Heatmap blob layer — grows denser as more arrows land.
                Canvas { context, size in
                    for (i, arrow) in arrows.enumerated() {
                        let pt = position(for: arrow, index: i, in: size)
                        let rect = CGRect(x: pt.x - 22, y: pt.y - 22, width: 44, height: 44)
                        context.fill(Path(ellipseIn: rect), with: .color(Color.appAccent.opacity(0.72)))
                    }
                }
                .drawingGroup()
                .blur(radius: arrows.count < 6 ? 14 : arrows.count < 12 ? 10 : 7)
                .animation(.easeInOut(duration: 0.4), value: arrows.count)
            }
            .overlay {
                // Crisp arrow dots on top.
                GeometryReader { geo in
                    ForEach(Array(arrows.enumerated()), id: \.element.id) { idx, arrow in
                        let pt = position(for: arrow, index: idx, in: geo.size)
                        ArrowLandingDot(ring: arrow.ring)
                            .position(pt)
                            .transition(.scale(scale: 0.2).combined(with: .opacity))
                    }
                }
            }
            .clipShape(Circle())
            .shadow(color: Color.appAccent.opacity(0.25), radius: 24, y: 6)
    }

    private func position(for arrow: ArrowPlot, index: Int, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        guard let x = arrow.plotX, let y = arrow.plotY else { return center }
        // plot space is -1…1; target visible radius is ~90% of half-width.
        let halfW = size.width / 2
        return CGPoint(
            x: center.x + CGFloat(x) * halfW,
            y: center.y - CGFloat(y) * halfW
        )
    }
}

private struct ArrowLandingDot: View {
    let ring: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(dotColor)
                .frame(width: 13, height: 13)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            Circle()
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                .frame(width: 13, height: 13)
        }
    }

    private var dotColor: Color {
        switch ring {
        case 11: return Color(red: 1.0, green: 0.85, blue: 0.0)
        case 10, 9: return Color(red: 1.0, green: 0.95, blue: 0.25)
        case 8, 7: return Color(red: 0.88, green: 0.28, blue: 0.22)
        default: return .gray
        }
    }
}

#Preview {
    HydrationSplashView()
        .environment(AppState())
}
