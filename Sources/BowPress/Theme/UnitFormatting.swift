import Foundation
import SwiftUI

// MARK: - Raw conversions

enum UnitConversion {
    static let inchToCm: Double    = 2.54
    static let inchToMm: Double    = 25.4
    static let ounceToGram: Double = 28.349523125
    static let grainToGram: Double = 0.06479891
}

// MARK: - Display formatting + parsing

enum UnitFormatting {

    // ─── Length (storage: inches, Double) ──────────────────────────────

    /// Renders a length stored in inches in the user's current system.
    /// - Parameter digits: significant digits *after* decimal in the active system.
    static func length(inches: Double, system: UnitSystem, digits: Int = 2) -> String {
        switch system {
        case .imperial:
            return "\(trimTrailingZeros(inches, digits: digits))\""
        case .metric:
            let cm = inches * UnitConversion.inchToCm
            return "\(trimTrailingZeros(cm, digits: 1)) cm"
        }
    }

    /// Length display without the unit suffix — used where the suffix is
    /// drawn separately (e.g. a TextField followed by a secondary label).
    static func lengthValue(inches: Double, system: UnitSystem, digits: Int = 2) -> String {
        switch system {
        case .imperial:
            return trimTrailingZeros(inches, digits: digits)
        case .metric:
            return trimTrailingZeros(inches * UnitConversion.inchToCm, digits: 1)
        }
    }

    static func lengthSuffix(_ system: UnitSystem) -> String {
        system == .imperial ? "\"" : "cm"
    }

    /// Parses a user-entered length string as the active system's unit
    /// and returns the canonical inches value.
    static func parseLength(_ text: String, system: UnitSystem) -> Double? {
        guard let v = Double(text.trimmingCharacters(in: .whitespaces)) else { return nil }
        switch system {
        case .imperial: return v
        case .metric:   return v / UnitConversion.inchToCm
        }
    }

    // ─── Sixteenths (storage: Int 1/16", e.g. nocking height) ──────────

    static func sixteenths(_ n: Int, system: UnitSystem) -> String {
        switch system {
        case .imperial:
            if n == 0 { return "0/16\"" }
            let sign = n > 0 ? "+" : "-"
            return "\(sign)\(abs(n))/16\""
        case .metric:
            if n == 0 { return "0 mm" }
            let mm = Double(n) * UnitConversion.inchToMm / 16.0
            let sign = mm > 0 ? "+" : ""
            return "\(sign)\(trimTrailingZeros(mm, digits: 1)) mm"
        }
    }

    // ─── MM length (storage: mm, Double — tiller / clicker) ────────────

    static func mmLength(_ mm: Double, system: UnitSystem, digits: Int = 1) -> String {
        switch system {
        case .imperial:
            let inches = mm / UnitConversion.inchToMm
            let sign = inches > 0 ? "+" : (inches < 0 ? "" : "")
            return "\(sign)\(trimTrailingZeros(inches, digits: 2))\""
        case .metric:
            let sign = mm > 0 ? "+" : (mm < 0 ? "" : "")
            return "\(sign)\(trimTrailingZeros(mm, digits: digits)) mm"
        }
    }

    // ─── Arrow mass (storage: grains, Int) ─────────────────────────────

    static func arrowMass(grains: Int, system: UnitSystem) -> String {
        switch system {
        case .imperial:
            return "\(grains) gr"
        case .metric:
            let g = Double(grains) * UnitConversion.grainToGram
            return "\(trimTrailingZeros(g, digits: 1)) g"
        }
    }

    static func arrowMassValue(grains: Int, system: UnitSystem) -> String {
        switch system {
        case .imperial:
            return "\(grains)"
        case .metric:
            return trimTrailingZeros(Double(grains) * UnitConversion.grainToGram, digits: 1)
        }
    }

    static func massSuffix(_ system: UnitSystem) -> String {
        system == .imperial ? "gr" : "g"
    }

    /// Parses a user-entered arrow mass string as the active system's unit
    /// and returns the canonical grains value.
    static func parseArrowMass(_ text: String, system: UnitSystem) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        switch system {
        case .imperial:
            return Int(trimmed)
        case .metric:
            guard let grams = Double(trimmed) else { return nil }
            return Int((grams / UnitConversion.grainToGram).rounded())
        }
    }

    // ─── Stabilizer weight (storage: ounces, Double) ───────────────────

    static func stabWeight(ounces: Double, system: UnitSystem) -> String {
        switch system {
        case .imperial:
            return "\(trimTrailingZeros(ounces, digits: 1)) oz"
        case .metric:
            let g = ounces * UnitConversion.ounceToGram
            // 10-gram increments are the metric step, so drop decimals entirely.
            return "\(Int(g.rounded())) g"
        }
    }

    // ─── Unit-less (degrees / percent) ─────────────────────────────────

    static func degrees(_ deg: Double, digits: Int = 1) -> String {
        "\(trimTrailingZeros(deg, digits: digits))°"
    }

    static func percent(_ pct: Double) -> String {
        "\(Int(pct.rounded()))%"
    }

    // ─── Private helpers ───────────────────────────────────────────────

    private static func trimTrailingZeros(_ value: Double, digits: Int) -> String {
        // Round to `digits` decimal places, then format with %g which strips
        // trailing zeros (28.50 → "28.5", 28.00 → "28", 2.125 → "2.125").
        let p = pow(10.0, Double(digits))
        let rounded = (value * p).rounded() / p
        return String(format: "%g", rounded)
    }
}

// MARK: - Unit-aware ranges + steps for Stepper / custom ± buttons

enum UnitRange {
    case drawLength, peepHeight, dLoopLength, braceHeight
    case arrowLength, fletchingLength, restDepth
    case pointWeight, totalWeight
    case fletchingOffset, gripAngle, stabAngleSmall, stabAngleLarge
    case frontStabWeight, rearStabWeight, vbarWeight
    case tiller, clicker
    case letOff

    /// Range expressed in the system's display unit.
    func displayRange(_ system: UnitSystem) -> ClosedRange<Double> {
        let (imp, met) = ranges
        return system == .imperial ? imp : met
    }

    /// Step expressed in the system's display unit.
    func displayStep(_ system: UnitSystem) -> Double {
        let (imp, met) = steps
        return system == .imperial ? imp : met
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    private var ranges: (imperial: ClosedRange<Double>, metric: ClosedRange<Double>) {
        switch self {
        case .drawLength:      return (17.0...37.0,  43.2...94.0)     // inches / cm
        case .peepHeight:      return (3.0...17.0,   7.6...43.2)
        case .dLoopLength:     return (0.1...5.0,    0.3...12.7)
        case .braceHeight:     return (5.0...12.0,   12.7...30.5)
        case .arrowLength:     return (18.0...36.0,  45.7...91.4)
        case .fletchingLength: return (1.0...5.0,    2.5...12.7)
        case .restDepth:       return (-5.0...5.0,   -12.7...12.7)
        case .pointWeight:     return (50...300,     3.2...19.4)      // grains / grams
        case .totalWeight:     return (100...800,    6.5...51.8)
        case .fletchingOffset: return (0.0...10.0,   0.0...10.0)
        case .gripAngle:       return (0.0...90.0,   0.0...90.0)
        case .stabAngleSmall:  return (0.0...10.0,   0.0...10.0)
        case .stabAngleLarge:  return (-90.0...90.0, -90.0...90.0)
        case .frontStabWeight: return (0.0...60.0,   0.0...1700.0)    // oz / g
        case .rearStabWeight:  return (0.0...60.0,   0.0...1700.0)
        case .vbarWeight:      return (0.0...30.0,   0.0...850.0)
        case .tiller:          return (-0.4...0.4,   -10.0...10.0)    // in / mm
        case .clicker:         return (-2.0...2.0,   -50.0...50.0)
        case .letOff:          return (40...99,      40...99)
        }
    }

    private var steps: (imperial: Double, metric: Double) {
        switch self {
        case .drawLength:      return (0.25,    0.5)    // 0.25" / 0.5 cm
        case .peepHeight:      return (0.1,     0.2)
        case .dLoopLength:     return (1.0/16,  0.1)
        case .braceHeight:     return (1.0/16,  0.1)
        case .arrowLength:     return (0.25,    0.5)
        case .fletchingLength: return (0.25,    0.5)
        case .restDepth:       return (0.25,    0.5)
        case .pointWeight:     return (5,       0.5)    // gr / g
        case .totalWeight:     return (1,       0.1)
        case .fletchingOffset: return (0.5,     0.5)
        case .gripAngle:       return (0.5,     0.5)
        case .stabAngleSmall:  return (1,       1)
        case .stabAngleLarge:  return (5,       5)
        case .frontStabWeight: return (0.5,     10)     // oz / g
        case .rearStabWeight:  return (0.5,     10)
        case .vbarWeight:      return (0.5,     10)
        case .tiller:          return (0.03125, 0.5)    // 1/32" / 0.5 mm
        case .clicker:         return (0.03125, 1)
        case .letOff:          return (1, 1)
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}

// MARK: - Binding helpers

/// Categories that map a canonical storage unit to a display unit.
enum UnitScale {
    /// Storage is inches; display is inches or cm.
    case inchToCm
    /// Storage is grains (Int); display is grains or grams.
    case grainToGram
    /// Storage is ounces; display is ounces or grams.
    case ounceToGram
    /// Storage is millimetres; display is millimetres or inches.
    case mmToInch
    /// Unit-less — no conversion (degrees, percent, counts).
    case identity

    func toDisplay(_ canonical: Double, system: UnitSystem) -> Double {
        guard system == .metric else {
            // Imperial display = canonical for most; mmToInch flips in imperial.
            if case .mmToInch = self { return canonical / UnitConversion.inchToMm }
            return canonical
        }
        switch self {
        case .inchToCm:    return canonical * UnitConversion.inchToCm
        case .grainToGram: return canonical * UnitConversion.grainToGram
        case .ounceToGram: return canonical * UnitConversion.ounceToGram
        case .mmToInch:    return canonical
        case .identity:    return canonical
        }
    }

    func toCanonical(_ display: Double, system: UnitSystem) -> Double {
        guard system == .metric else {
            if case .mmToInch = self { return display * UnitConversion.inchToMm }
            return display
        }
        switch self {
        case .inchToCm:    return display / UnitConversion.inchToCm
        case .grainToGram: return display / UnitConversion.grainToGram
        case .ounceToGram: return display / UnitConversion.ounceToGram
        case .mmToInch:    return display
        case .identity:    return display
        }
    }
}

extension Binding where Value == Double {
    /// Exposes a canonical-unit binding as a display-unit binding for Stepper / Slider.
    func displayed(in system: UnitSystem, scale: UnitScale) -> Binding<Double> {
        Binding<Double>(
            get: { scale.toDisplay(self.wrappedValue, system: system) },
            set: { self.wrappedValue = scale.toCanonical($0, system: system) }
        )
    }
}

extension Binding where Value == Int {
    /// Int variant for canonical values stored as Int (grains, counts). Rounds on write.
    func displayed(in system: UnitSystem, scale: UnitScale) -> Binding<Double> {
        Binding<Double>(
            get: { scale.toDisplay(Double(self.wrappedValue), system: system) },
            set: { self.wrappedValue = Int(scale.toCanonical($0, system: system).rounded()) }
        )
    }
}
