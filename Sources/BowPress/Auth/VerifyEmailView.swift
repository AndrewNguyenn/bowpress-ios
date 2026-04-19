import SwiftUI

struct VerifyEmailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var authService: AuthService
    let email: String

    @State private var digits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?

    @State private var isSubmitting: Bool = false
    @State private var isResending: Bool = false
    @State private var resendCooldown: Int = 0
    @State private var cooldownTimer: Timer? = nil

    @State private var errorMessage: String? = nil
    @State private var infoMessage: String? = nil

    private var code: String { digits.joined() }
    private var canSubmit: Bool { code.count == 6 && !isSubmitting }

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                codeSection
                submitSection
                resendSection
                if let errorMessage {
                    banner(text: errorMessage, color: .red, icon: "exclamationmark.circle.fill")
                }
                if let infoMessage {
                    banner(text: infoMessage, color: .secondary, icon: "envelope.fill")
                }
            }
            .navigationTitle("Verify Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                focusedIndex = 0
            }
            .onDisappear {
                cooldownTimer?.invalidate()
                cooldownTimer = nil
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Check your email")
                    .font(.headline)
                Text("We sent a 6-digit code to \(email). The code expires in 10 minutes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var codeSection: some View {
        Section {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    digitField(for: i)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func digitField(for index: Int) -> some View {
        TextField("", text: Binding(
            get: { digits[index] },
            set: { newValue in handleDigit(input: newValue, at: index) }
        ))
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .multilineTextAlignment(.center)
        .font(.system(size: 24, weight: .semibold, design: .monospaced))
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(focusedIndex == index ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1.5)
        )
        .focused($focusedIndex, equals: index)
    }

    private var submitSection: some View {
        Section {
            Button(action: submit) {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Verify").font(.headline)
                    }
                    Spacer()
                }
            }
            .disabled(!canSubmit)
        }
    }

    private var resendSection: some View {
        Section {
            Button(action: resend) {
                if isResending {
                    ProgressView()
                } else if resendCooldown > 0 {
                    Text("Resend code in \(resendCooldown)s")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Resend code")
                }
            }
            .disabled(isResending || resendCooldown > 0)
        }
    }

    private func banner(text: String, color: Color, icon: String) -> some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(color)
                Text(text).foregroundStyle(color).font(.subheadline)
            }
        }
    }

    // MARK: - Input handling

    private func handleDigit(input: String, at index: Int) {
        let filtered = input.filter(\.isNumber)

        // Paste: user pasted a full/partial code
        if filtered.count > 1 {
            let chars = Array(filtered.prefix(6 - index))
            for (offset, char) in chars.enumerated() {
                let targetIndex = index + offset
                guard targetIndex < digits.count else { break }
                digits[targetIndex] = String(char)
            }
            let next = min(index + chars.count, 5)
            focusedIndex = chars.count + index >= 6 ? nil : next
            return
        }

        // Deletion
        if filtered.isEmpty {
            digits[index] = ""
            if index > 0 { focusedIndex = index - 1 }
            return
        }

        digits[index] = String(filtered.last!)
        if index < 5 {
            focusedIndex = index + 1
        } else {
            focusedIndex = nil
        }
    }

    // MARK: - Actions

    private func submit() {
        errorMessage = nil
        infoMessage = nil
        isSubmitting = true
        let submittedCode = code

        Task {
            do {
                try await authService.verifyEmail(email: email, code: submittedCode)
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch let err as AuthError {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = err.localizedDescription
                    if case .invalidCode = err { clearDigits() }
                    if case .tooManyAttempts = err { clearDigits() }
                    if case .codeExpired = err { clearDigits() }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resend() {
        errorMessage = nil
        infoMessage = nil
        isResending = true

        Task {
            do {
                try await authService.resendVerification(email: email)
                await MainActor.run {
                    isResending = false
                    infoMessage = "A new code is on its way."
                    startCooldown()
                }
            } catch {
                await MainActor.run {
                    isResending = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func clearDigits() {
        digits = Array(repeating: "", count: 6)
        focusedIndex = 0
    }

    private func startCooldown() {
        resendCooldown = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                if resendCooldown > 0 {
                    resendCooldown -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    VerifyEmailView(
        authService: AuthService(appState: state),
        email: "you@example.com"
    )
    .environment(state)
}
