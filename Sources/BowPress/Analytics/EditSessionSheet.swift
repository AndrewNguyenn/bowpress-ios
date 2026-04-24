import SwiftUI

/// Edit sheet for a completed session. Allows the archer to amend notes and
/// feel tags after a session has ended — a common ask because tags/notes
/// often get skipped in the moment. Writes go to the API (reuses
/// `PUT /sessions/:id`) and LocalStore, and `onSaved` is invoked with the
/// updated session so the caller can refresh its view.
struct EditSessionSheet: View {
    let session: ShootingSession
    var onSaved: (ShootingSession) -> Void

    @Environment(LocalStore.self) private var store: LocalStore?
    @Environment(\.dismiss) private var dismiss

    @State private var notes: String = ""
    @State private var tagsText: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private let apiClient: BowPressAPIClient = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("edit_session_notes")
                }
                Section {
                    TextField("e.g. locked-in, back-tension", text: $tagsText, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("edit_session_tags")
                } header: {
                    Text("Feel Tags")
                } footer: {
                    Text("Separate tags with commas.")
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                }
            }
            .onAppear {
                notes = session.notes
                tagsText = session.feelTags.joined(separator: ", ")
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay {
                if isSaving {
                    ProgressView().controlSize(.large)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let parsedTags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var updated = session
        updated.notes = notes
        updated.feelTags = parsedTags

        // Persist locally first so the edit is durable even if the server
        // call fails; BackgroundSyncService will catch the pending state
        // on the next connectivity event.
        try? store?.save(session: updated)

        do {
            try await apiClient.updateSession(
                id: updated.id,
                notes: updated.notes,
                feelTags: updated.feelTags
            )
            try? store?.markSessionSynced(id: updated.id)
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
