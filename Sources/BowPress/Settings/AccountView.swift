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
                    verificationBadge(verified: user.emailVerified ?? false)
                }
            } else {
                Text("Not signed in").foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            NavigationLink("Edit Profile") { EditProfileView() }
            if appState.currentUser?.canChangePassword ?? true {
                NavigationLink("Change Password") { ChangePasswordView() }
            }
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

    private func verificationBadge(verified: Bool) -> some View {
        Text(verified ? "Verified" : "Unverified")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(verified ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            )
            .foregroundStyle(verified ? Color.green : Color.orange)
    }

    private func confirmSignOut() {
        isSigningOut = true
        AuthService(appState: appState).signOut()
        isSigningOut = false
    }
}

#Preview("Verified") {
    let state = AppState()
    state.currentUser = User(
        id: "u1", email: "archer@example.com", name: "Sage Archer",
        createdAt: Date(timeIntervalSince1970: 0), emailVerified: true
    )
    return NavigationStack { AccountView() }
        .environment(state)
}

#Preview("Unverified") {
    let state = AppState()
    state.currentUser = User(
        id: "u2", email: "new@example.com", name: "New Archer",
        createdAt: Date(timeIntervalSince1970: 0), emailVerified: false
    )
    return NavigationStack { AccountView() }
        .environment(state)
}

#Preview("Apple sign-in") {
    let state = AppState()
    state.currentUser = User(
        id: "u3", email: "apple@example.com", name: "Apple Archer",
        createdAt: Date(timeIntervalSince1970: 0), emailVerified: true,
        authProvider: .apple
    )
    return NavigationStack { AccountView() }
        .environment(state)
}

#Preview("Google sign-in") {
    let state = AppState()
    state.currentUser = User(
        id: "u4", email: "google@example.com", name: "Google Archer",
        createdAt: Date(timeIntervalSince1970: 0), emailVerified: true,
        authProvider: .google
    )
    return NavigationStack { AccountView() }
        .environment(state)
}
