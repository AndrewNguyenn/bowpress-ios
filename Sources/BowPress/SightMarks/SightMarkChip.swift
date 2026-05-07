import SwiftUI

/// In-session chip showing the relevant sight mark for the active bow at
/// the session's target distance. Renders nothing when there's no useful
/// reading to show — better silent than a fabricated number.
struct SightMarkChip: View {
    var bowId: String?
    var distance: ShootingDistance?

    @Environment(LocalStore.self) private var store

    /// Re-fetched in body — `LocalStore.sightMarksMutationStamp` is read to
    /// subscribe to cross-screen edits, so the chip refreshes when the
    /// archer adds a mark in Equipment without leaving Session.
    private var marks: [SightMark] {
        guard let bowId else { return [] }
        _ = store.sightMarksMutationStamp
        return (try? store.fetchSightMarks(bowId: bowId)) ?? []
    }

    var body: some View {
        Group {
            if bowId != nil, let distance, let outcome = lookup(distance: distance) {
                switch outcome {
                case .measured(let mark):
                    chip(
                        icon: "scope",
                        label: "Sight mark",
                        value: format(mark.mark),
                        isSuggested: false
                    )
                case .suggested(let s):
                    chip(
                        icon: "sparkles",
                        label: "Suggested",
                        value: format(s.mark),
                        isSuggested: true
                    )
                }
            }
        }
    }

    private func chip(icon: String, label: String, value: String, isSuggested: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(isSuggested ? Color.secondary : Color.accentColor)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit().weight(.semibold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    // MARK: - Lookup

    private enum Outcome {
        case measured(SightMark)
        case suggested(SightMarkSuggestion)
    }

    private func lookup(distance: ShootingDistance) -> Outcome? {
        let (value, unit) = distanceValueAndUnit(distance)
        // Match in meters-space so a 54.68-yard mark satisfies a 50m session
        // (and vice versa). Tolerance ~5 cm — tight enough to avoid false
        // matches between adjacent shoot distances, loose enough to absorb
        // the imperial/metric rounding boundary.
        let targetMeters = value * unit.metersPerUnit
        let measuredMatch = marks.first { mark in
            !mark.isSuggestion
                && abs(mark.distanceInMeters - targetMeters) < 0.05
        }
        if let measured = measuredMatch {
            return .measured(measured)
        }
        let outcome = SightMarkSuggester.suggest(
            atDistance: value, unit: unit, from: marks
        )
        if case .suggested(let s) = outcome {
            return .suggested(s)
        }
        return nil
    }

    private func distanceValueAndUnit(_ d: ShootingDistance) -> (Double, DistanceUnit) {
        switch d {
        case .twentyYards:   return (20, .yards)
        case .fiftyMeters:   return (50, .meters)
        case .seventyMeters: return (70, .meters)
        }
    }
}
