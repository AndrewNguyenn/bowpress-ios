import XCTest
@testable import BowPress

final class SightMarkSuggesterTests: XCTestCase {

    // MARK: - Fixture helpers

    private func mark(
        _ distance: Double,
        unit: DistanceUnit = .yards,
        mark: Double,
        suggested: Bool = false
    ) -> SightMark {
        SightMark(
            id: UUID().uuidString,
            userId: "u",
            arrowId: "a",
            distance: distance,
            distanceUnit: unit,
            mark: mark,
            note: nil,
            isSuggestion: suggested,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Gating: mark count

    func testReturnsNotEnoughMarksWhenEmpty() {
        let outcome = SightMarkSuggester.suggest(
            atDistance: 30, unit: .yards, from: []
        )
        XCTAssertEqual(outcome, .notEnoughMarks(have: 0))
    }

    func testReturnsNotEnoughMarksWithJustTwo() {
        let marks = [mark(20, mark: 22.0), mark(40, mark: 28.0)]
        let outcome = SightMarkSuggester.suggest(
            atDistance: 30, unit: .yards, from: marks
        )
        XCTAssertEqual(outcome, .notEnoughMarks(have: 2))
    }

    func testFiltersOutSuggestionsBeforeCounting() {
        // 2 measured + 1 suggested → only 2 measured, should fail count.
        let marks = [
            mark(20, mark: 22.0),
            mark(40, mark: 28.0),
            mark(30, mark: 25.0, suggested: true),
        ]
        let outcome = SightMarkSuggester.suggest(
            atDistance: 35, unit: .yards, from: marks
        )
        XCTAssertEqual(outcome, .notEnoughMarks(have: 2))
    }

    // MARK: - Gating: spread

    func testReturnsSpreadTooSmallWhenMarksClustered() {
        // 3 marks but only 5 yards apart — fails 20-yard spread rule.
        let marks = [mark(20, mark: 22.0), mark(22, mark: 23.0), mark(25, mark: 24.5)]
        let outcome = SightMarkSuggester.suggest(
            atDistance: 22, unit: .yards, from: marks
        )
        // Spread of 5 yards = ~4.572m
        if case .spreadTooSmall(let haveMeters) = outcome {
            XCTAssertEqual(haveMeters, 5.0 * 0.9144, accuracy: 1e-6)
        } else {
            XCTFail("expected spreadTooSmall, got \(outcome)")
        }
    }

    func testAcceptsExactly20YardSpread() {
        // 3 marks spanning exactly 20 yards — should fit (boundary case).
        let marks = [mark(20, mark: 22.0), mark(30, mark: 25.0), mark(40, mark: 28.0)]
        let outcome = SightMarkSuggester.suggest(
            atDistance: 30, unit: .yards, from: marks
        )
        if case .suggested(let s) = outcome {
            XCTAssertEqual(s.mark, 25.0, accuracy: 1e-6)
            XCTAssertEqual(s.sourceMarkCount, 3)
        } else {
            XCTFail("expected suggested, got \(outcome)")
        }
    }

    // MARK: - Gating: extrapolation buffer

    func testRefusesExtrapolationBeyondBuffer() {
        // 3 marks at 20, 30, 40 yards. Suggesting at 60 yards is way past
        // the 5-yard extrapolation buffer.
        let marks = [mark(20, mark: 22.0), mark(30, mark: 25.0), mark(40, mark: 28.0)]
        let outcome = SightMarkSuggester.suggest(
            atDistance: 60, unit: .yards, from: marks
        )
        if case .distanceOutOfRange(let lo, let hi) = outcome {
            XCTAssertEqual(lo, 20 * 0.9144, accuracy: 1e-6)
            XCTAssertEqual(hi, 40 * 0.9144, accuracy: 1e-6)
        } else {
            XCTFail("expected distanceOutOfRange, got \(outcome)")
        }
    }

    func testAllowsSmallExtrapolationWithinBuffer() {
        // 3 marks at 20, 30, 40. 44 yards is +4y past the upper edge,
        // within the 5-yard buffer — should still suggest.
        let marks = [mark(20, mark: 22.0), mark(30, mark: 25.0), mark(40, mark: 28.0)]
        let outcome = SightMarkSuggester.suggest(
            atDistance: 44, unit: .yards, from: marks
        )
        if case .suggested = outcome {
            // pass — only checking we didn't bail out
        } else {
            XCTFail("expected suggested, got \(outcome)")
        }
    }

    // MARK: - Math correctness

    func testFitsLinearMarksExactly() {
        // y = 0.5x + 12 — perfectly linear, quadratic fit reduces to it.
        let marks = (20...60).striding(by: 10).map { d in
            mark(Double(d), mark: 0.5 * Double(d) + 12.0)
        }
        let outcome = SightMarkSuggester.suggest(
            atDistance: 35, unit: .yards, from: marks
        )
        if case .suggested(let s) = outcome {
            XCTAssertEqual(s.mark, 0.5 * 35 + 12, accuracy: 1e-3)
            // Linear data fits exactly; residual ~ 0.
            XCTAssertEqual(s.residualStandardError, 0, accuracy: 1e-6)
            XCTAssertEqual(s.sourceMarkCount, 5)
        } else {
            XCTFail("expected suggested, got \(outcome)")
        }
    }

    func testFitsQuadraticDataExactly() {
        // y = 0.01x² + 0.3x + 15 — pure quadratic, exact fit with 3 points.
        let f: (Double) -> Double = { 0.01 * $0 * $0 + 0.3 * $0 + 15.0 }
        let marks = [20.0, 40.0, 60.0].map { d in mark(d, mark: f(d)) }
        let outcome = SightMarkSuggester.suggest(
            atDistance: 35, unit: .yards, from: marks
        )
        if case .suggested(let s) = outcome {
            // Note: the fit is in meters; the function above is in yards.
            // Convert: x_m = d * 0.9144 → recover y in fitted-meters frame.
            // We're solving y = f_m(x_m) where f_m collapses the yards
            // scaling into the coefficients. The predicted y at any
            // particular yardage should still match f(yards).
            XCTAssertEqual(s.mark, f(35), accuracy: 1e-3)
            XCTAssertEqual(s.residualStandardError, 0, accuracy: 1e-6)
        } else {
            XCTFail("expected suggested, got \(outcome)")
        }
    }

    func testReportsResidualStandardErrorForNoisyData() {
        // 4+ noisy points should produce a positive RSE.
        // y ≈ 0.5x + 12 with small noise.
        let pairs: [(Double, Double)] = [
            (20, 22.1), (30, 26.9), (40, 32.2), (50, 36.7), (60, 42.1),
        ]
        let marks = pairs.map { mark($0.0, mark: $0.1) }
        let outcome = SightMarkSuggester.suggest(
            atDistance: 45, unit: .yards, from: marks
        )
        if case .suggested(let s) = outcome {
            XCTAssertGreaterThan(s.residualStandardError, 0)
            XCTAssertLessThan(s.residualStandardError, 0.5)
            XCTAssertEqual(s.sourceMarkCount, 5)
        } else {
            XCTFail("expected suggested, got \(outcome)")
        }
    }

    // MARK: - Unit handling

    func testSpreadCheckIsUnitNormalized() {
        // 3 marks in meters spanning 20m — well above 18.288m threshold.
        let marks = [
            mark(20, unit: .meters, mark: 22.0),
            mark(30, unit: .meters, mark: 25.0),
            mark(40, unit: .meters, mark: 28.0),
        ]
        let outcome = SightMarkSuggester.suggest(
            atDistance: 30, unit: .meters, from: marks
        )
        if case .suggested = outcome {} else {
            XCTFail("expected suggested for 20m-spread metric marks, got \(outcome)")
        }
    }

    func testRejectsMetricMarksTooClustered() {
        // 3 marks spanning only 10m (~10.94yd) — fails 20yd spread rule.
        let marks = [
            mark(30, unit: .meters, mark: 22.0),
            mark(35, unit: .meters, mark: 24.0),
            mark(40, unit: .meters, mark: 26.0),
        ]
        let outcome = SightMarkSuggester.suggest(
            atDistance: 35, unit: .meters, from: marks
        )
        if case .spreadTooSmall = outcome {} else {
            XCTFail("expected spreadTooSmall, got \(outcome)")
        }
    }

    func testAcceptsMixedUnitsViaConversion() {
        // 20yd ≈ 18.288m, 50m, 70m — wildly mixed but legal.
        // Spread in meters: 70 - 18.288 = ~51.7m → well above threshold.
        let marks = [
            mark(20, unit: .yards, mark: 22.0),
            mark(50, unit: .meters, mark: 30.0),
            mark(70, unit: .meters, mark: 38.0),
        ]
        let outcome = SightMarkSuggester.suggest(
            atDistance: 50, unit: .meters, from: marks
        )
        if case .suggested(let s) = outcome {
            XCTAssertEqual(s.mark, 30.0, accuracy: 1e-3)  // exact 3-point fit
        } else {
            XCTFail("expected suggested, got \(outcome)")
        }
    }
}

private extension ClosedRange where Bound == Int {
    func striding(by step: Int) -> [Int] {
        Array(stride(from: lowerBound, through: upperBound, by: step))
    }
}
