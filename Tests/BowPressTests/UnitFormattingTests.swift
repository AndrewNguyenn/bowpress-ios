import XCTest
@testable import BowPress

/// Covers conversion round-tripping, parser symmetry, and rendering
/// for every unit family the app toggles between imperial and metric.
final class UnitFormattingTests: XCTestCase {

    // MARK: - Length (inches ↔ cm)

    func test_length_imperialRenderMatchesQuotedInches() {
        XCTAssertEqual(UnitFormatting.length(inches: 28.5, system: .imperial), "28.5\"")
        XCTAssertEqual(UnitFormatting.length(inches: 28.0, system: .imperial), "28\"")
        XCTAssertEqual(UnitFormatting.length(inches: 2.125, system: .imperial, digits: 3), "2.125\"")
    }

    func test_length_metricRenderUsesCm() {
        XCTAssertEqual(UnitFormatting.length(inches: 28.5, system: .metric), "72.4 cm")
        XCTAssertEqual(UnitFormatting.length(inches: 10.0, system: .metric), "25.4 cm")
    }

    func test_length_parseImperialReturnsInchesUnchanged() {
        XCTAssertEqual(UnitFormatting.parseLength("28.5", system: .imperial), 28.5)
        XCTAssertNil(UnitFormatting.parseLength("nonsense", system: .imperial))
    }

    func test_length_parseMetricConvertsBackToInches() {
        let inches = UnitFormatting.parseLength("72.39", system: .metric) ?? 0
        XCTAssertEqual(inches, 28.5, accuracy: 0.01)
    }

    func test_length_roundTripsWithinTolerance() {
        // Render canonical inches in each system, then reparse; imperial reparse
        // is exact, metric reparse loses ~1 mm because the display is rounded to
        // 0.1 cm. Tolerate the metric display-rounding loss explicitly.
        for canonical in stride(from: 5.0, through: 35.0, by: 0.5) {
            // Imperial: exact round-trip at 3 decimals.
            let impRendered = UnitFormatting.lengthValue(inches: canonical, system: .imperial, digits: 3)
            let impBack = UnitFormatting.parseLength(impRendered, system: .imperial) ?? -1
            XCTAssertEqual(impBack, canonical, accuracy: 0.001,
                           "imperial: \(canonical) → \(impRendered) → \(impBack)")

            // Metric: the 1-decimal cm display is the lossy step; reparse must
            // come back within ~0.5 mm (0.02").
            let metRendered = UnitFormatting.lengthValue(inches: canonical, system: .metric)
            let metBack = UnitFormatting.parseLength(metRendered, system: .metric) ?? -1
            XCTAssertEqual(metBack, canonical, accuracy: 0.02,
                           "metric: \(canonical) → \(metRendered) → \(metBack)")
        }
    }

    // MARK: - Sixteenths (stored as Int 1/16")

    func test_sixteenths_imperialRenderExact() {
        XCTAssertEqual(UnitFormatting.sixteenths(3,  system: .imperial), "+3/16\"")
        XCTAssertEqual(UnitFormatting.sixteenths(-7, system: .imperial), "-7/16\"")
        XCTAssertEqual(UnitFormatting.sixteenths(0,  system: .imperial), "0/16\"")
    }

    func test_sixteenths_metricRoundsToTenthOfMm() {
        XCTAssertEqual(UnitFormatting.sixteenths(3,   system: .metric), "+4.8 mm")
        XCTAssertEqual(UnitFormatting.sixteenths(16,  system: .metric), "+25.4 mm")
        XCTAssertEqual(UnitFormatting.sixteenths(-16, system: .metric), "-25.4 mm")
    }

    func test_sixteenths_storageUnchangedAcrossFlip() {
        // Nocking height stored as Int 1/16" never changes underfoot — only the display does.
        let stored = 5
        let impString = UnitFormatting.sixteenths(stored, system: .imperial)
        let metString = UnitFormatting.sixteenths(stored, system: .metric)
        XCTAssertEqual(impString, "+5/16\"")
        XCTAssertTrue(metString.hasPrefix("+"), "metric rendering of a positive value should lead with +")
    }

    // MARK: - MM length (tiller, clicker — stored in mm)

    func test_mmLength_metricPreservesMm() {
        XCTAssertEqual(UnitFormatting.mmLength(2.0,  system: .metric), "+2 mm")
        XCTAssertEqual(UnitFormatting.mmLength(-2.5, system: .metric), "-2.5 mm")
        XCTAssertEqual(UnitFormatting.mmLength(0.0,  system: .metric), "0 mm")
    }

    func test_mmLength_imperialConvertsToInches() {
        // 25.4 mm = exactly 1".
        let rendered = UnitFormatting.mmLength(25.4, system: .imperial)
        XCTAssertTrue(rendered.contains("1"), "25.4 mm should render as an inch-ish value")
        XCTAssertTrue(rendered.hasSuffix("\""), "imperial mmLength output is quoted inches")
    }

    // MARK: - Arrow mass (grains ↔ grams)

    func test_arrowMass_imperialRendersGrains() {
        XCTAssertEqual(UnitFormatting.arrowMass(grains: 110, system: .imperial), "110 gr")
    }

    func test_arrowMass_metricRendersGrams() {
        // 110 gr ≈ 7.1 g
        XCTAssertEqual(UnitFormatting.arrowMass(grains: 110, system: .metric), "7.1 g")
        XCTAssertEqual(UnitFormatting.arrowMass(grains: 0, system: .metric), "0 g")
    }

    func test_arrowMass_parseRoundTripStaysWithinOneGrain() {
        for grains in [50, 100, 110, 150, 220, 300] {
            let metricText = UnitFormatting.arrowMassValue(grains: grains, system: .metric)
            let reparsed = UnitFormatting.parseArrowMass(metricText, system: .metric) ?? -1
            XCTAssertEqual(reparsed, grains, accuracy: 1,
                           "round trip for \(grains) gr ↔ '\(metricText)' g")
        }
    }

    // MARK: - Stabilizer weight (ounces ↔ grams)

    func test_stabWeight_imperialShowsOz() {
        XCTAssertEqual(UnitFormatting.stabWeight(ounces: 6.0, system: .imperial), "6 oz")
        XCTAssertEqual(UnitFormatting.stabWeight(ounces: 0.5, system: .imperial), "0.5 oz")
    }

    func test_stabWeight_metricShowsGramsAsIntegers() {
        // 6 oz ≈ 170 g
        XCTAssertEqual(UnitFormatting.stabWeight(ounces: 6.0,  system: .metric), "170 g")
        XCTAssertEqual(UnitFormatting.stabWeight(ounces: 12.0, system: .metric), "340 g")
    }

    // MARK: - Degrees / percent (unit-less)

    func test_degrees_unchangedAcrossSystems() {
        XCTAssertEqual(UnitFormatting.degrees(5.0, digits: 0), "5°")
        XCTAssertEqual(UnitFormatting.degrees(5.5), "5.5°")
    }

    func test_percent_roundsToInteger() {
        XCTAssertEqual(UnitFormatting.percent(80), "80%")
        XCTAssertEqual(UnitFormatting.percent(79.7), "80%")
    }

    // MARK: - UnitScale round-trip

    func test_unitScale_inchToCm_roundTripsExact() {
        let scale = UnitScale.inchToCm
        for inches in stride(from: 1.0, through: 40.0, by: 0.25) {
            let cm = scale.toDisplay(inches, system: .metric)
            let back = scale.toCanonical(cm, system: .metric)
            XCTAssertEqual(back, inches, accuracy: 0.0001)
        }
    }

    func test_unitScale_identityOnImperial() {
        XCTAssertEqual(UnitScale.inchToCm.toDisplay(28.5, system: .imperial), 28.5)
        XCTAssertEqual(UnitScale.ounceToGram.toDisplay(6.0, system: .imperial), 6.0)
    }

    // MARK: - ShaftDiameter enum display

    func test_shaftDiameter_metricRendersAllCasesInMm() {
        for d in ArrowConfiguration.ShaftDiameter.allCases {
            let s = d.displayName(for: .metric)
            XCTAssertTrue(s.hasSuffix(" mm"),
                          "metric shaft diameter '\(s)' should end in ' mm' for case \(d)")
        }
    }

    func test_shaftDiameter_imperialKeepsInchCasesAsFractions() {
        XCTAssertEqual(ArrowConfiguration.ShaftDiameter.in19_64.displayName(for: .imperial), "19/64\"")
        XCTAssertEqual(ArrowConfiguration.ShaftDiameter.in27_64.displayName(for: .imperial), "27/64\"")
    }

    func test_shaftDiameter_imperialShowsDecimalInchesForMmOnlyCases() {
        // 3.2 mm ≈ 0.126"
        XCTAssertEqual(ArrowConfiguration.ShaftDiameter.mm3_2.displayName(for: .imperial), "0.126\"")
    }

    // MARK: - UnitRange

    func test_unitRange_drawLength_imperialAndMetricAgree() {
        let imp = UnitRange.drawLength.displayRange(.imperial)
        let met = UnitRange.drawLength.displayRange(.metric)
        XCTAssertEqual(imp.lowerBound * UnitConversion.inchToCm, met.lowerBound, accuracy: 0.5)
        XCTAssertEqual(imp.upperBound * UnitConversion.inchToCm, met.upperBound, accuracy: 0.5)
    }

    func test_unitRange_stepsAreDistinct() {
        XCTAssertNotEqual(UnitRange.drawLength.displayStep(.imperial),
                          UnitRange.drawLength.displayStep(.metric))
        XCTAssertNotEqual(UnitRange.frontStabWeight.displayStep(.imperial),
                          UnitRange.frontStabWeight.displayStep(.metric))
    }
}
