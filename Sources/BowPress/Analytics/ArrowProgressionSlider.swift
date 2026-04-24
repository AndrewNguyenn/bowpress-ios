import SwiftUI

/// Scrub slider that controls how many arrows of a completed round are visible.
/// Renders tick marks at end boundaries and a caption describing the scrub position.
struct ArrowProgressionSlider: View {
    let totalArrows: Int
    /// Arrow-count values (1-based) at which each subsequent end begins.
    /// For a round with ends of size 6,6,6,6 this is [6, 12, 18].
    let endBoundaries: [Int]
    /// End number of the most-recently-visible arrow; nil when `visibleCount == 0`.
    let currentEnd: Int?
    let endCount: Int
    var isDisabled: Bool = false

    @Binding var visibleCount: Int

    private var sliderValue: Binding<Double> {
        Binding(
            get: { Double(visibleCount) },
            set: { visibleCount = Int($0.rounded()) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LiquidGlassSlider(
                value: sliderValue,
                range: 0...Double(max(totalArrows, 1)),
                step: 1,
                endBoundaries: endBoundaries,
                total: max(totalArrows, 1)
            )
            .frame(height: 34)

            Text(caption)
                .font(.bpMono(10))
                .appTracking(0.04, at: 10)
                .foregroundStyle(Color.appInk3)
                .animation(.none, value: visibleCount)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

}

// MARK: - LiquidGlassSlider
//
// Custom slider whose thumb is a frosted-glass circle — the iOS 26
// "Liquid Glass" treatment. SwiftUI's stock `Slider` doesn't expose the
// thumb as a customizable view; building it from primitives lets us
// render the thumb as `.ultraThinMaterial` with a faint white rim and
// soft shadow (the components of the glass look) while keeping the
// track in the Kenrokuen palette.
private struct LiquidGlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let endBoundaries: [Int]
    let total: Int

    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let span = range.upperBound - range.lowerBound
            let progress = span > 0
                ? (value - range.lowerBound) / span
                : 0
            let usableWidth = width - thumbSize
            let thumbX = CGFloat(progress) * usableWidth

            ZStack(alignment: .leading) {
                // Unfilled track
                Capsule()
                    .fill(Color.appLine)
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)
                // Filled track
                Capsule()
                    .fill(Color.appPondDk)
                    .frame(width: thumbX + thumbSize / 2, height: trackHeight)
                    .padding(.leading, thumbSize / 2 - thumbSize / 2)
                // End-boundary tick marks
                ForEach(endBoundaries, id: \.self) { boundary in
                    let frac = Double(boundary) / Double(total)
                    Rectangle()
                        .fill(Color.appInk3.opacity(0.55))
                        .frame(width: 1.5, height: 10)
                        .position(
                            x: thumbSize / 2 + CGFloat(frac) * usableWidth,
                            y: geo.size.height / 2
                        )
                        .allowsHitTesting(false)
                }
                // Liquid-glass thumb
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.7),
                                        Color.white.opacity(0.15),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        Circle()
                            .inset(by: 4)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0),
                                    ],
                                    center: .init(x: 0.35, y: 0.3),
                                    startRadius: 0,
                                    endRadius: thumbSize / 2
                                )
                            )
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 0.5)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                guard usableWidth > 0 else { return }
                                let raw = min(max(0, g.location.x - thumbSize / 2), usableWidth)
                                let newProgress = Double(raw / usableWidth)
                                var newVal = range.lowerBound + span * newProgress
                                if step > 0 {
                                    newVal = (newVal / step).rounded() * step
                                }
                                value = min(max(range.lowerBound, newVal), range.upperBound)
                            }
                    )
            }
            .frame(height: thumbSize)
        }
    }
}

extension ArrowProgressionSlider {
    private var caption_: Void { () }  // separator to keep diff context readable

    private var caption: String {
        if isDisabled {
            return "Clear the end filter to scrub the full round"
        }
        if visibleCount == 0 {
            return "No arrows yet"
        }
        if visibleCount >= totalArrows {
            let endSuffix = endCount == 1 ? "end" : "ends"
            return "All \(totalArrows) arrows · \(endCount) \(endSuffix)"
        }
        if let end = currentEnd {
            return "Shot \(visibleCount) of \(totalArrows) · End \(end)"
        }
        return "Shot \(visibleCount) of \(totalArrows)"
    }
}

#if DEBUG
#Preview("Default — all visible") {
    VStack {
        Spacer()
        ArrowProgressionSlider(
            totalArrows: 60,
            endBoundaries: [6, 12, 18, 24, 30, 36, 42, 48, 54],
            currentEnd: 10,
            endCount: 10,
            visibleCount: .constant(60)
        )
        Spacer()
    }
}

#Preview("Mid-scrub") {
    VStack {
        Spacer()
        ArrowProgressionSlider(
            totalArrows: 60,
            endBoundaries: [6, 12, 18, 24, 30, 36, 42, 48, 54],
            currentEnd: 3,
            endCount: 10,
            visibleCount: .constant(18)
        )
        Spacer()
    }
}

#Preview("Disabled") {
    VStack {
        Spacer()
        ArrowProgressionSlider(
            totalArrows: 60,
            endBoundaries: [6, 12, 18],
            currentEnd: 3,
            endCount: 10,
            isDisabled: true,
            visibleCount: .constant(24)
        )
        Spacer()
    }
}
#endif
