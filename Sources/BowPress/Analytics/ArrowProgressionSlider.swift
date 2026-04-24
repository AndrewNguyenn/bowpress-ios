import SwiftUI

/// Scrub slider that controls how many arrows of a completed round are visible.
/// Renders tick marks at end boundaries and a caption describing the scrub position.
///
/// Uses the stock SwiftUI `Slider`, which on iOS 26+ renders with Apple's native
/// Liquid Glass treatment on the thumb. The `.tint()` modifier colors the filled
/// portion of the track without replacing the material thumb.
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
            Slider(
                value: sliderValue,
                in: 0...Double(max(totalArrows, 1)),
                step: 1
            )
            .controlSize(.large)
            .tint(Color.appPondDk)
            .overlay(
                GeometryReader { geo in
                    ForEach(endBoundaries, id: \.self) { boundary in
                        let frac = Double(boundary) / Double(totalArrows)
                        Rectangle()
                            .fill(Color.appInk3.opacity(0.55))
                            .frame(width: 1.5, height: 12)
                            .position(
                                x: CGFloat(frac) * geo.size.width,
                                y: geo.size.height / 2
                            )
                    }
                }
                .allowsHitTesting(false)
            )

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
