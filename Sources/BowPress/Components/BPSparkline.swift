import SwiftUI

/// Thin polyline over 3 dashed horizontal guides (top/mid/bottom), last
/// datum highlighted as a filled moss circle with a 1pt ink stroke.
struct BPSparkline: View {
    let points: [Double]
    let height: CGFloat
    let range: ClosedRange<Double>?

    init(points: [Double], height: CGFloat = 86, range: ClosedRange<Double>? = nil) {
        self.points = points
        self.height = height
        self.range = range
    }

    private var resolvedRange: ClosedRange<Double> {
        if let range { return range }
        guard let lo = points.min(), let hi = points.max(), lo != hi else {
            return 0...1
        }
        return lo...hi
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = resolvedRange
            let span = r.upperBound - r.lowerBound

            // Dashed horizontal guides.
            Path { p in
                for y in [0, h / 2, h] {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: w, y: y))
                }
            }
            .stroke(Color.appLine, style: StrokeStyle(lineWidth: 1, dash: [1, 4]))

            // Polyline.
            if points.count >= 2 {
                Path { p in
                    for (i, v) in points.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(points.count - 1)
                        let norm = span > 0 ? (v - r.lowerBound) / span : 0.5
                        let y = h - CGFloat(norm) * h
                        if i == 0 {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.appPondDk, lineWidth: 1.4)
            }

            // Last-point dot.
            if let last = points.last {
                let x = w
                let norm = span > 0 ? (last - r.lowerBound) / span : 0.5
                let y = h - CGFloat(norm) * h
                Circle()
                    .fill(Color.appMoss)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(Color.appInk, lineWidth: 1))
                    .position(x: x, y: y)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(spacing: 20) {
            BPSparkline(points: [9.1, 9.4, 9.0, 10.2, 9.6, 10.4, 10.1])
                .padding()
            BPSparkline(points: [6, 5, 7, 8, 6, 9, 10, 10], range: 0...10)
                .padding()
        }
    }
}
