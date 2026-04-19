import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var currentFieldError: String? = nil
    @State private var generalError: String? = nil
    @State private var isSaving: Bool = false
    @State private var showSuccessToast: Bool = false

    // Test seam: preloads an error state for snapshot tests without mutating the view model.
    init(previewError: String? = nil) {
        _generalError = State(initialValue: previewError)
    }

    var body: some View {
        Form {
            Section("Current Password") {
                SecureField("Current password", text: $currentPassword)
                    .textContentType(.password)
                if let currentFieldError {
                    Text(currentFieldError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                SecureField("New password", text: $newPassword)
                    .textContentType(.newPassword)
            } header: {
                Text("New Password")
            } footer: {
                if !newPassword.isEmpty && newPassword.count < 8 {
                    Text("New password must be at least 8 characters.")
                        .foregroundStyle(.red)
                }
            }

            if let generalError {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                        Text(generalError).foregroundStyle(.red).font(.subheadline)
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
                            Text("Update Password").fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if showSuccessToast {
                toast(text: "Password updated")
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var canSave: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && !isSaving
    }

    private func save() {
        currentFieldError = nil
        generalError = nil
        isSaving = true

        Task {
            do {
                try await APIClient.shared.changePassword(current: currentPassword, new: newPassword)
                await MainActor.run {
                    isSaving = false
                    withAnimation { showSuccessToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation { showSuccessToast = false }
                        dismiss()
                    }
                }
            } catch let err as NSError where err.code == 401 {
                await MainActor.run {
                    isSaving = false
                    currentFieldError = "Current password incorrect"
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    generalError = error.localizedDescription
                }
            }
        }
    }

    private func toast(text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.8)))
    }
}

#Preview("Pristine") {
    NavigationStack { ChangePasswordView() }
}

#Preview("With error") {
    NavigationStack { ChangePasswordView(previewError: "Current password incorrect") }
}
