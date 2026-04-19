import SwiftUI

struct DeleteAccountView: View {
    @Environment(AppState.self) private var appState

    @State private var password: String = ""
    @State private var isDeleting: Bool = false
    @State private var showConfirmAlert: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Permanent Deletion", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.headline)
                    Text("This permanently deletes all your bows, sessions, and plots. This action cannot be undone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Confirm Password") {
                SecureField("Password", text: $password)
                    .textContentType(.password)
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
                Button(role: .destructive) {
                    showConfirmAlert = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete Account").fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(password.isEmpty || isDeleting)
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Are you absolutely sure?", isPresented: $showConfirmAlert) {
            Button("Delete Account", role: .destructive, action: confirmDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your account and all shooting data will be deleted permanently.")
        }
    }

    private func confirmDelete() {
        errorMessage = nil
        isDeleting = true

        Task {
            do {
                try await APIClient.shared.deleteAccount(password: password)
                await MainActor.run {
                    isDeleting = false
                    AuthService(appState: appState).signOut()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
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
    return NavigationStack { DeleteAccountView() }
        .environment(state)
}
