import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignOutConfirm: Bool = false
    @State private var isSigningOut: Bool = false

    var body: some View {
        Form {
            identitySection
            actionsSection
            signOutSection
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Sign out of BowPress?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive, action: confirmSignOut)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var identitySection: some View {
        Section {
            if let user = appState.currentUser {
                LabeledContent("Name", value: user.name)
                HStack {
                    Text("Email")
                    Spacer()
                    Text(user.email).foregroundStyle(.secondary)
                }
            } else {
                Text("Not signed in").foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            NavigationLink("Edit Profile") { EditProfileView() }
            NavigationLink("Delete Account") { DeleteAccountView() }
                .foregroundStyle(.red)
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showSignOutConfirm = true
            } label: {
                HStack {
                    Spacer()
                    if isSigningOut {
                        ProgressView()
                    } else {
                        Text("Sign Out").fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(isSigningOut)
        }
    }

    private func confirmSignOut() {
        isSigningOut = true
        AuthService(appState: appState).signOut()
        isSigningOut = false
    }
}

#Preview("Apple sign-in") {
    let state = AppState()
    state.currentUser = User(
        id: "u3", email: "apple@example.com", name: "Apple Archer",
        createdAt: Date(timeIntervalSince1970: 0),
        authProvider: .apple
    )
    return NavigationStack { AccountView() }
        .environment(state)
}

#Preview("Google sign-in") {
    let state = AppState()
    state.currentUser = User(
        id: "u4", email: "google@example.com", name: "Google Archer",
        createdAt: Date(timeIntervalSince1970: 0),
        authProvider: .google
    )
    return NavigationStack { AccountView() }
        .environment(state)
}
