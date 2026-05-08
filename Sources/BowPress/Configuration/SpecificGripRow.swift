import SwiftUI

/// Sheet-backed picker row for grip / limb identifiers on bow configs. Tap
/// the row → modal lists every value the archer has previously entered
/// across their bow configs, with options to pick, add a new one, or delete
/// from the catalog. The catalog is the de-duped union of values across
/// `appState.bowConfigs.values` — there's no separate persisted catalog
/// model, so "delete" here means clearing the value from any config that
/// referenced it (the row's `onDeleteSuggestion` callback).
///
/// Row label tells the archer what's currently selected; "None" when nil.
struct BowConfigSuggestRow: View {
    let label: String
    let placeholder: String
    @Binding var value: String

    /// De-duplicated catalog of previously-entered values (caller owns
    /// sourcing — typically `BowConfiguration.suggestions(...)`).
    let suggestions: [String]

    /// Removes `name` from every config that referenced it. Caller wires
    /// this to a write through `appState.bowConfigs` so the catalog
    /// re-derives correctly on next render.
    let onDeleteSuggestion: (String) -> Void

    /// Stub like "specific_grip" / "specific_limbs" for accessibility ids.
    let accessibilityKey: String

    @State private var isPickerPresented = false

    private var displayValue: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "None" : trimmed
    }

    var body: some View {
        Button {
            isPickerPresented = true
        } label: {
            LabeledContent(label) {
                HStack(spacing: 4) {
                    Text(displayValue)
                        .foregroundStyle(value.isEmpty ? .secondary : Color.appInk)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            // Without a contentShape the Button only hit-tests the visible
            // text — the empty space between the label and the trailing
            // chevron is dead. Same fix the SessionLogRow needed.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(accessibilityKey)_row")
        .sheet(isPresented: $isPickerPresented) {
            BowConfigSuggestPickerSheet(
                title: label,
                placeholder: placeholder,
                value: $value,
                suggestions: suggestions,
                onDeleteSuggestion: onDeleteSuggestion,
                accessibilityKey: accessibilityKey
            )
        }
    }
}

private struct BowConfigSuggestPickerSheet: View {
    let title: String
    let placeholder: String
    @Binding var value: String
    let suggestions: [String]
    let onDeleteSuggestion: (String) -> Void
    let accessibilityKey: String

    @Environment(\.dismiss) private var dismiss
    @State private var newEntry: String = ""
    @State private var pendingDelete: String?

    private var canAddNew: Bool {
        let trimmed = newEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // No duplicate-of-existing — selecting an existing entry is the
        // suggestions list's job, not "add new"'s.
        return !suggestions.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !suggestions.isEmpty {
                    Section("Saved \(title.lowercased())") {
                        ForEach(Array(suggestions.enumerated()), id: \.element) { index, name in
                            Button {
                                value = name
                                dismiss()
                            } label: {
                                HStack {
                                    Text(name).foregroundStyle(Color.appInk)
                                    Spacer()
                                    if name.caseInsensitiveCompare(value) == .orderedSame {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = name
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            // Index-keyed id (vs interpolating user-supplied
                            // strings) so UI tests stay stable against names
                            // with spaces, accents, or emoji. The label is
                            // still surfaced via the Button's text content.
                            .accessibilityIdentifier("\(accessibilityKey)_picker_row_\(index)")
                        }
                    }
                }

                Section("Add new") {
                    HStack(spacing: 8) {
                        TextField(placeholder, text: $newEntry)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("\(accessibilityKey)_picker_new_field")
                        Button("Add") {
                            // Use the same canonicalization the save path
                            // uses so what the user sees in the catalog
                            // matches what gets persisted (no near-duplicates
                            // from extra whitespace).
                            value = BowConfiguration.canonicalizeText(newEntry) ?? ""
                            dismiss()
                        }
                        .disabled(!canAddNew)
                    }
                }

                if !value.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            value = ""
                            dismiss()
                        } label: {
                            Text("Clear selection")
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Delete \(pendingDelete ?? "")?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { name in
                Button("Delete", role: .destructive) {
                    if value.caseInsensitiveCompare(name) == .orderedSame {
                        value = ""
                    }
                    onDeleteSuggestion(name)
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { _ in
                Text("Removes this entry from your saved list and clears it from any bow configs that referenced it. Past tuning history isn't changed.")
            }
        }
    }
}

/// Clear a catalog entry from every current bow config that references it.
/// Past tuning history (older config rows) is left alone — only the
/// catalog the picker sources from gets the entry pruned. Lifted out of
/// the two views (BowConfigEditView, BowDetailView) so a single fix
/// reaches both call sites and the API-sync semantics stay consistent.
///
/// `field` is `.specificGrip` or `.specificLimbs`. This routes through
/// LocalStore's force-clear methods (vs `save(config:)`, which coalesces
/// nil-on-update to defend against hydration). The local-only field
/// concept means there's no API call to make on the side — when the
/// backend learns these fields, this is the place to add the sync.
@MainActor
func clearCatalogValue(
    matching name: String,
    field: BowConfigCatalogField,
    appState: AppState,
    store: LocalStore,
    excludingBowId: String? = nil
) {
    let target = name.trimmingCharacters(in: .whitespacesAndNewlines)
    for (bowId, cfg) in appState.bowConfigs {
        if bowId == excludingBowId { continue }
        let current = (cfg[keyPath: field.keyPath])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard current.caseInsensitiveCompare(target) == .orderedSame else { continue }
        var updated = cfg
        updated[keyPath: field.keyPath] = nil
        switch field {
        case .specificGrip:  try? store.clearConfigSpecificGrip(id: cfg.id)
        case .specificLimbs: try? store.clearConfigSpecificLimbs(id: cfg.id)
        }
        appState.bowConfigs[bowId] = updated
    }
}

enum BowConfigCatalogField {
    case specificGrip
    case specificLimbs

    var keyPath: WritableKeyPath<BowConfiguration, String?> {
        switch self {
        case .specificGrip:  return \.specificGrip
        case .specificLimbs: return \.specificLimbs
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
    /// collection of configs, sourced via the `keyPath` (e.g. `\.specificGrip`).
    /// Used to populate `BowConfigSuggestRow.suggestions`. Unlike the prior
    /// chip flavor, the picker sheet doesn't filter the current value — the
    /// user can re-select to confirm or see it checkmarked.
    static func suggestions<C: Collection>(
        from configs: C,
        keyPath: KeyPath<BowConfiguration, String?>
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
        return ordered
    }
}
