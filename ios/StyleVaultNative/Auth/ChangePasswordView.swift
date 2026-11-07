import SwiftUI

/// Dal Profilo, per chi entra con email e password.
struct ChangePasswordView: View {
    static let minimumLength = 6

    @EnvironmentObject private var auth: AuthService
    @State private var password = ""
    @State private var confirm = ""
    @State private var messageKey: LocalizedStringKey?
    @State private var isError = false
    @State private var busy = false

    private var mismatch: Bool { !confirm.isEmpty && password != confirm }
    private var canSave: Bool { password.count >= Self.minimumLength && password == confirm && !busy }

    var body: some View {
        Form {
            Section {
                SecureField("profile.newPassword", text: $password,
                            prompt: Text("profile.newPassword").foregroundStyle(Palette.muted))
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("password-new")
                SecureField("profile.confirmPassword", text: $confirm,
                            prompt: Text("profile.confirmPassword").foregroundStyle(Palette.muted))
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("password-confirm")
            } footer: {
                if mismatch {
                    Text("native.password.mismatch").foregroundStyle(Palette.danger)
                } else {
                    Text("native.password.minimum \(Self.minimumLength)").foregroundStyle(Palette.muted)
                }
            }
            Section {
                Button(action: save) { Text("common.save").frame(maxWidth: .infinity).bold() }
                    .disabled(!canSave)
                    .accessibilityIdentifier("password-save")
                if let messageKey {
                    Text(messageKey)
                        .font(.footnote)
                        .foregroundStyle(isError ? Palette.danger : Palette.muted)
                        .accessibilityIdentifier("password-message")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(Text("profile.changePassword"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.ink)
    }

    private func save() {
        busy = true
        messageKey = nil
        Task {
            defer { busy = false }
            do {
                try await auth.updatePassword(password)
                password = ""
                confirm = ""
                isError = false
                messageKey = "profile.passwordChanged"
            } catch {
                isError = true
                messageKey = "native.password.failed"
            }
        }
    }
}
