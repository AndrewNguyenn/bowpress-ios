import SwiftUI

struct EmailAuthView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // Injected so the parent (AuthView) can share the single AuthService instance
    var authService: AuthService

    // MARK: - State

    enum Mode { case signIn, createAccount }

    @State private var mode: Mode = .signIn
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // MARK: - Validation

    private var emailValid: Bool { email.contains("@") }
    private var passwordValid: Bool { password.count >= 8 }
    private var passwordsMatch: Bool { password == confirmPassword }

    private var canSubmit: Bool {
        guard emailValid, passwordValid else { return false }
        if mode == .createAccount {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && passwordsMatch
        }
        return true
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    modePickerSection
                    fieldsSection
                    submitSection
                    if let message = errorMessage {
                        errorSection(message)
                    }
                }
                .disabled(isLoading)
                .scrollDismissesKeyboard(.interactively)

                if isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle(mode == .signIn ? "Sign In" : "Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var modePickerSection: some View {
        Section {
            Picker("Mode", selection: $mode) {
                Text("Sign In").tag(Mode.signIn)
                Text("Create Account").tag(Mode.createAccount)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                errorMessage = nil
                confirmPassword = ""
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    @ViewBuilder
    private var fieldsSection: some View {
        Section {
            if mode == .createAccount {
                TextField("Full Name", text: $name)
                    .textContentType(.name)
                    .autocorrectionDisabled()
            }

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)

            if mode == .createAccount {
                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
            }
        } footer: {
            if mode == .createAccount && !confirmPassword.isEmpty && !passwordsMatch {
                Text("Passwords do not match.")
                    .foregroundStyle(.red)
            } else if !password.isEmpty && !passwordValid {
                Text("Password must be at least 8 characters.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var submitSection: some View {
        Section {
            Button(action: submit) {
                Text(mode == .signIn ? "Sign In" : "Create Account")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
            .disabled(!canSubmit)
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(.white)
        }
    }

    // MARK: - Actions

    private func submit() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                switch mode {
                case .signIn:
                    try await authService.signIn(email: email, password: password)
                case .createAccount:
                    try await authService.signUp(
                        name: name.trimmingCharacters(in: .whitespaces),
                        email: email,
                        password: password
                    )
                }
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Sign In") {
    let state = AppState()
    EmailAuthView(authService: AuthService(appState: state))
        .environment(state)
}

#Preview("Create Account") {
    let state = AppState()
    let view = EmailAuthView(authService: AuthService(appState: state))
    view
        .environment(state)
}
