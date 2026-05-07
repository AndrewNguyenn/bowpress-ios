import SwiftUI

struct DeleteAccountView: View {
    @Environment(AppState.self) private var appState

    @State private var password: String = ""
    @State private var isDeleting: Bool = false
    @State private var showConfirmAlert: Bool = false
    @State private var errorMessage: String? = nil

    /// Only the email-auth path needs a password confirm. The email-auth UI
    /// was retired (no verified Resend domain) and existing email-auth users
    /// get linked to Apple/Google on next social sign-in (their passwordHash
    /// is cleared server-side). A nil `authProvider` from a cached pre-flag
    /// session would historically default to "email" — but with the email
    /// UI gone, defaulting nil to "no password needed" is the safer bet:
    /// worst case the server rejects the unauthenticated delete, best case
    /// (the typical case) the user can finish deleting their account.
    private var requiresPassword: Bool {
        appState.currentUser?.authProvider == .email
    }

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

            if requiresPassword {
                Section("Confirm Password") {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
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
                .disabled(deleteButtonDisabled)
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

    private var deleteButtonDisabled: Bool {
        if isDeleting { return true }
        return requiresPassword && password.isEmpty
    }

    private func confirmDelete() {
        errorMessage = nil
        isDeleting = true

        Task {
            do {
                try await APIClient.shared.deleteAccount(password: requiresPassword ? password : nil)
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

#Preview("Email account") {
    let state = AppState()
    state.currentUser = User(
        id: "u1", email: "a@example.com", name: "Sage Archer",
        createdAt: Date(timeIntervalSince1970: 0), emailVerified: true
    )
    return NavigationStack { DeleteAccountView() }
        .environment(state)
}

#Preview("Apple account") {
    let state = AppState()
    state.currentUser = User(
        id: "u2", email: "apple@example.com", name: "Apple Archer",
        createdAt: Date(timeIntervalSince1970: 0), emailVerified: true,
        authProvider: .apple
    )
    return NavigationStack { DeleteAccountView() }
        .environment(state)
}
