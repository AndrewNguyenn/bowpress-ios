import SwiftUI

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .autocorrectionDisabled()
            }

            if let errorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                        Text(errorMessage).foregroundStyle(.red).font(.subheadline)
                    }
                }
            }

            Section {
                Button(action: save) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if name.isEmpty, let current = appState.currentUser?.name {
                name = current
            }
        }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isSaving else { return false }
        return trimmed != appState.currentUser?.name
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                let user = try await APIClient.shared.updateProfile(name: trimmed)
                await MainActor.run {
                    appState.currentUser = user
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    let state = AppState()
    state.currentUser = User(
        id: "u1", email: "a@example.com", name: "Sage Archer",
        createdAt: Date(timeIntervalSince1970: 0), emailVerified: true
    )
    return NavigationStack { EditProfileView() }
        .environment(state)
}
