import SwiftUI

/// Free-text input row with horizontal autocomplete chips drawn from
/// previously-entered values across the user's bow configs. Used for
/// recurve/barebow grip names and limb identifiers — both have a small
/// fixed-by-the-archer universe of values that benefits from quick reuse
/// across bow configs.
struct BowConfigSuggestRow: View {
    let label: String
    let placeholder: String
    @Binding var value: String

    /// Pre-filtered, de-duplicated suggestions to display as chips. Caller
    /// owns sourcing them — typically `BowConfiguration.suggestions(...)`.
    /// Pass `[]` to hide the chip row.
    let suggestions: [String]

    /// Per-instance accessibility id stub (e.g. "specific_grip", "specific_limbs").
    let accessibilityKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(label) {
                TextField(placeholder, text: $value)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("\(accessibilityKey)_field")
            }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { name in
                            Button(name) { value = name }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}

extension BowConfiguration {
    /// Trim whitespace and collapse empty to nil so legacy rows don't acquire
    /// stray empty strings. Used at write time and in `hasMatchingValues` so
    /// equality treats `nil`, `""`, and `"   "` as identical.
    static func canonicalizeText(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Distinct, trimmed, case-insensitively-deduped values across a
    /// collection of configs, sourced via the `keyPath` (e.g.
    /// `\.specificGrip`). Use to populate `BowConfigSuggestRow.suggestions`.
    /// Filters out the value the user is currently typing (case-insensitive)
    /// so it doesn't appear as a redundant chip.
    static func suggestions<C: Collection>(
        from configs: C,
        keyPath: KeyPath<BowConfiguration, String?>,
        excluding currentInput: String = ""
    ) -> [String] where C.Element == BowConfiguration {
        var seen = Set<String>()
        var ordered: [String] = []
        for cfg in configs {
            guard let raw = cfg[keyPath: keyPath]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { continue }
            let key = raw.lowercased()
            if seen.insert(key).inserted {
                ordered.append(raw)
            }
        }
        let typing = currentInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ordered.filter { $0.lowercased() != typing }
    }

    // Back-compat shims — kept so call sites that took the grip-only API
    // before this generalization don't have to change in lockstep. Both
    // forward to the generic implementations.
    static func canonicalizeGrip(_ raw: String) -> String? {
        canonicalizeText(raw)
    }

    static func gripSuggestions<C: Collection>(
        from configs: C,
        excluding currentInput: String = ""
    ) -> [String] where C.Element == BowConfiguration {
        suggestions(from: configs, keyPath: \.specificGrip, excluding: currentInput)
    }
}
