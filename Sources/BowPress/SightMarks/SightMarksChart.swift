import SwiftUI
import Charts

/// Visualisation of measured marks plus the fitted quadratic curve.
/// Points that deviate noticeably from the fit are emphasised so the
/// archer can spot a bad mark by eye — the Royston-Heath approach.
struct SightMarksChart: View {
    let marks: [SightMark]
    let unit: DistanceUnit

    private var sortedMarks: [SightMark] {
        marks.sorted { $0.distanceInMeters < $1.distanceInMeters }
    }

    /// Coefficients of the fitted quadratic, in **meters** input space.
    private var fitCoefficients: (a: Double, b: Double, c: Double)? {
        let xs = sortedMarks.map { $0.distanceInMeters }
        let ys = sortedMarks.map { $0.mark }
        guard xs.count >= 3 else { return nil }
        return SightMarkSuggester.quadraticLeastSquares(xs: xs, ys: ys)
    }

    /// One residual standard deviation, used as the "outlier" threshold.
    /// Any single mark whose residual exceeds 1.5 × sigma is highlighted.
    private var outlierIds: Set<String> {
        guard let coeffs = fitCoefficients, sortedMarks.count >= 4 else { return [] }
        let residuals = sortedMarks.map { mark -> (id: String, r: Double) in
            let x = mark.distanceInMeters
            let yhat = coeffs.a + coeffs.b * x + coeffs.c * x * x
            return (mark.id, mark.mark - yhat)
        }
        let n = Double(residuals.count)
        let ssr = residuals.reduce(0) { $0 + $1.r * $1.r }
        let sigma = sqrt(ssr / max(1, n - 3))
        guard sigma > 0 else { return [] }
        return Set(residuals.filter { abs($0.r) > 1.5 * sigma }.map { $0.id })
    }

    /// Sample the fitted curve at ~50 evenly-spaced points across the
    /// marked distance range, returning (x_in_display_unit, predicted_y).
    private var fitSamples: [(x: Double, y: Double)] {
        guard let coeffs = fitCoefficients,
              let minX = sortedMarks.map(\.distanceInMeters).min(),
              let maxX = sortedMarks.map(\.distanceInMeters).max(),
              minX < maxX else { return [] }
        let n = 50
        let step = (maxX - minX) / Double(n)
        var out: [(Double, Double)] = []
        for i in 0...n {
            let xMeters = minX + Double(i) * step
            let y = coeffs.a + coeffs.b * xMeters + coeffs.c * xMeters * xMeters
            let xDisplay = xMeters / unit.metersPerUnit
            out.append((xDisplay, y))
        }
        return out
    }

    var body: some View {
        Chart {
            ForEach(fitSamples, id: \.x) { sample in
                LineMark(
                    x: .value("Distance", sample.x),
                    y: .value("Mark", sample.y)
                )
                .foregroundStyle(.tint.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
            ForEach(sortedMarks) { mark in
                let displayX = mark.distanceInMeters / unit.metersPerUnit
                PointMark(
                    x: .value("Distance", displayX),
                    y: .value("Mark", mark.mark)
                )
                .symbol(.circle)
                .symbolSize(outlierIds.contains(mark.id) ? 90 : 60)
                .foregroundStyle(outlierIds.contains(mark.id) ? Color.red : Color.primary)
            }
        }
        .chartXAxisLabel("Distance (\(unit.shortLabel))")
        .chartYAxisLabel("Mark")
    }
}
