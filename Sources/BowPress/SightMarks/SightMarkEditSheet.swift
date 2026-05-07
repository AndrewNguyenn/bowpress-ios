import SwiftUI

/// Add-or-edit sheet for a single sight mark. When 3+ measured marks exist
/// for the bow with sufficient spread, the mark field shows a ghost-text
/// suggestion the archer can accept or override.
struct SightMarkEditSheet: View {
    enum Mode: Equatable {
        case add(bow: Bow)
        case edit(mark: SightMark, bow: Bow)

        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case (.add(let a), .add(let b)): return a.id == b.id
            case (.edit(let m1, _), .edit(let m2, _)): return m1.id == m2.id
            default: return false
            }
        }

        var bow: Bow {
            switch self {
            case .add(let b): return b
            case .edit(_, let b): return b
            }
        }

        var existing: SightMark? {
            if case .edit(let mark, _) = self { return mark }
            return nil
        }
    }

    let mode: Mode
    /// Other measured marks for this bow — used to fit the suggestion
    /// curve. The mark currently being edited (if any) is filtered out
    /// by the caller so its current value doesn't bias the prediction.
    let existingMarks: [SightMark]

    @Environment(LocalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial

    @State private var distanceText: String = ""
    @State private var distanceUnit: DistanceUnit = .yards
    @State private var markText: String = ""
    @State private var note: String = ""
    @State private var didSeed = false
    @State private var errorMessage: String?

    private var distanceValue: Double? {
        Double(distanceText.replacingOccurrences(of: ",", with: "."))
    }
    private var markValue: Double? {
        Double(markText.replacingOccurrences(of: ",", with: "."))
    }

    /// Suggestion shown as ghost text if the archer hasn't typed a mark yet.
    private var suggestion: SightMarkSuggestion? {
        guard let d = distanceValue, d > 0 else { return nil }
        let outcome = SightMarkSuggester.suggest(
            atDistance: d, unit: distanceUnit, from: existingMarks
        )
        if case .suggested(let s) = outcome { return s }
        return nil
    }

    private var canSave: Bool {
        guard let d = distanceValue, d > 0 else { return false }
        return markValue != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Distance") {
                    HStack {
                        TextField("e.g. 30", text: $distanceText)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $distanceUnit) {
                            Text("yd").tag(DistanceUnit.yards)
                            Text("m").tag(DistanceUnit.meters)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 110)
                    }
                }

                Section {
                    TextField(markPlaceholder, text: $markText)
                        .keyboardType(.decimalPad)
                        .font(.body.monospacedDigit())
                    if let s = suggestion, markText.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.tint)
                            Text("Suggested: \(String(format: "%.2f", s.mark))")
                                .font(.footnote)
                            Spacer()
                            Button("Use") {
                                markText = String(format: "%.2f", s.mark)
                            }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("Sight reading")
                } footer: {
                    Text(suggestionFooter)
                        .font(.caption2)
                }

                Section("Note") {
                    TextField("Optional — wind, light, etc.", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(mode.existing == nil ? "Add Sight Mark" : "Edit Sight Mark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: seed)
            .alert("Couldn't save mark", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var markPlaceholder: String {
        if let s = suggestion {
            return "Suggested \(String(format: "%.2f", s.mark))"
        }
        return "Required — single-pin tape, scope reading, click count"
    }

    private var suggestionFooter: String {
        guard let d = distanceValue, d > 0 else {
            return "Numeric reading from your sight. Multi-pin sights are out of scope for v1 — the suggester needs continuous values to interpolate."
        }
        switch SightMarkSuggester.suggest(atDistance: d, unit: distanceUnit, from: existingMarks) {
        case .suggested(let s):
            if s.residualStandardError == 0 {
                return "Suggestion based on \(s.sourceMarkCount) marks (exact fit)."
            }
            return "Suggestion based on \(s.sourceMarkCount) marks (residual ±\(String(format: "%.2f", s.residualStandardError)))."
        case .notEnoughMarks(let have):
            let need = SightMarkSuggester.minMarkCount - have
            return "Suggestions need \(need) more measured mark\(need == 1 ? "" : "s")."
        case .spreadTooSmall:
            return "Suggestions need at least 20 yards spread between marks."
        case .distanceOutOfRange:
            return "Distance is past the marked range — suggestions only work inside the curve."
        }
    }

    private func seed() {
        guard !didSeed else { return }
        didSeed = true
        if let m = mode.existing {
            distanceText = formatDistance(m.distance)
            distanceUnit = m.distanceUnit
            markText = String(format: "%.2f", m.mark)
            note = m.note ?? ""
        } else {
            distanceUnit = DistanceUnit.preferred(for: unitSystem)
        }
    }

    private func formatDistance(_ d: Double) -> String {
        d == d.rounded() ? String(format: "%.0f", d) : String(format: "%.1f", d)
    }

    private func save() {
        guard let d = distanceValue, d > 0, let m = markValue else { return }
        let now = Date()
        let mark: SightMark
        let isNew: Bool
        if let existing = mode.existing {
            mark = SightMark(
                id: existing.id,
                userId: existing.userId,
                bowId: existing.bowId,
                distance: d,
                distanceUnit: distanceUnit,
                mark: m,
                note: note.isEmpty ? nil : note,
                isSuggestion: false,  // editing it makes it measured
                createdAt: existing.createdAt,
                updatedAt: now
            )
            isNew = false
        } else {
            mark = SightMark(
                id: UUID().uuidString,
                userId: mode.bow.userId,
                bowId: mode.bow.id,
                distance: d,
                distanceUnit: distanceUnit,
                mark: m,
                note: note.isEmpty ? nil : note,
                isSuggestion: false,
                createdAt: now,
                updatedAt: now
            )
            isNew = true
        }
        do {
            try store.save(sightMark: mark)
            SyncService().syncSightMark(mark, isNew: isNew)
            dismiss()
        } catch {
            // Local SwiftData writes can fail (disk full, mid-flight migration,
            // model-context contention). Surface to the archer rather than
            // letting Save look like a no-op.
            errorMessage = error.localizedDescription
        }
    }
}
