import SwiftUI

/// Two-step password-reset flow presented from the email sign-in screen.
///
/// Step 1 (`.requestCode`): collect email, call /auth/forgot-password.
/// The backend always returns 200 (enumeration defense), so we proceed to
/// step 2 regardless of whether the email actually exists.
///
/// Step 2 (`.confirmReset`): user enters the 6-digit code from the email
/// and a new password. On success the API returns a fresh AuthResponse and
/// the user is signed in immediately. Same error mapping as VerifyEmailView
/// (invalid_code / codeExpired / tooManyAttempts) so the UX is consistent.
struct ForgotPasswordView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var authService: AuthService
    var initialEmail: String = ""

    enum Step { case requestCode, confirmReset }

    @State private var step: Step = .requestCode
    @State private var email: String = ""
    @State private var code: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var infoMessage: String? = nil

    private var emailValid: Bool { email.contains("@") }
    private var codeValid: Bool { code.count == 6 && code.allSatisfy(\.isNumber) }
    private var passwordValid: Bool { newPassword.count >= 8 }
    private var passwordsMatch: Bool { newPassword == confirmPassword }

    private var canSubmit: Bool {
        switch step {
        case .requestCode: return emailValid && !isSubmitting
        case .confirmReset: return codeValid && passwordValid && passwordsMatch && !isSubmitting
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                fieldsSection
                submitSection
                if step == .confirmReset {
                    resendSection
                }
                if let errorMessage {
                    bannerSection(text: errorMessage, color: .red, icon: "exclamationmark.circle.fill")
                }
                if let infoMessage {
                    bannerSection(text: infoMessage, color: .secondary, icon: "envelope.fill")
                }
            }
            .navigationTitle(step == .requestCode ? "Forgot Password" : "Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if email.isEmpty { email = initialEmail }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(step == .requestCode ? "Reset your password" : "Enter the code we sent")
                    .font(.headline)
                Text(step == .requestCode
                     ? "Enter the email you signed up with. If we have an account on file, we'll email you a 6-digit reset code."
                     : "We sent a 6-digit code to \(email). The code expires in 10 minutes. Enter it below along with a new password.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var fieldsSection: some View {
        Section {
            switch step {
            case .requestCode:
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .accessibilityIdentifier("forgot_password_email_field")
            case .confirmReset:
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .accessibilityIdentifier("forgot_password_code_field")
                SecureField("New password", text: $newPassword)
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("forgot_password_new_password_field")
                SecureField("Confirm new password", text: $confirmPassword)
                    .textContentType(.newPassword)
            }
        } footer: {
            if step == .confirmReset && !confirmPassword.isEmpty && !passwordsMatch {
                Text("Passwords do not match.").foregroundStyle(.red)
            } else if step == .confirmReset && !newPassword.isEmpty && !passwordValid {
                Text("Password must be at least 8 characters.").foregroundStyle(.red)
            }
        }
    }

    private var submitSection: some View {
        Section {
            Button(action: submit) {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text(step == .requestCode ? "Send code" : "Reset password")
                            .font(.headline)
                    }
                    Spacer()
                }
            }
            .disabled(!canSubmit)
        }
    }

    private var resendSection: some View {
        Section {
            Button("Resend code", action: resendCode)
                .disabled(isSubmitting)
        }
    }

    private func bannerSection(text: String, color: Color, icon: String) -> some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(color)
                Text(text).foregroundStyle(color).font(.subheadline)
            }
        }
    }

    // MARK: - Actions

    private func submit() {
        errorMessage = nil
        infoMessage = nil
        isSubmitting = true

        switch step {
        case .requestCode:
            let target = email
            Task {
                do {
                    try await authService.forgotPassword(email: target)
                    await MainActor.run {
                        isSubmitting = false
                        step = .confirmReset
                        infoMessage = "If we have an account for \(target), a code is on its way."
                    }
                } catch {
                    await MainActor.run {
                        isSubmitting = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .confirmReset:
            let args = (email, code, newPassword)
            Task {
                do {
                    try await authService.resetPassword(email: args.0, code: args.1, newPassword: args.2)
                    await MainActor.run {
                        isSubmitting = false
                        dismiss()
                    }
                } catch let err as AuthError {
                    await MainActor.run {
                        isSubmitting = false
                        errorMessage = err.localizedDescription
                    }
                } catch {
                    await MainActor.run {
                        isSubmitting = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func resendCode() {
        errorMessage = nil
        infoMessage = nil
        isSubmitting = true
        let target = email
        Task {
            do {
                try await authService.forgotPassword(email: target)
                await MainActor.run {
                    isSubmitting = false
                    infoMessage = "A new code is on its way."
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview("Step 1") {
    let state = AppState()
    return ForgotPasswordView(authService: AuthService(appState: state))
        .environment(state)
}
