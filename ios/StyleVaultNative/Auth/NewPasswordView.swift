import SwiftUI

/// Dopo il link dell'email "Password dimenticata?": si sceglie la nuova password e si entra.
struct NewPasswordView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var password = ""
    @State private var errorText: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("native.auth.newPassword")
                    .displayFont(26)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 60)
                if let email = auth.session?.user.email {
                    Text(verbatim: email).font(.subheadline).foregroundStyle(Palette.muted)
                }
                SecureField("native.auth.newPasswordField", text: $password,
                            prompt: Text("native.auth.newPasswordField").foregroundStyle(Palette.muted))
                    .textContentType(.newPassword)
                    .modifier(FieldBox())
                if let errorText {
                    Text(verbatim: errorText).font(.footnote).foregroundStyle(Palette.danger)
                }
                Button(action: save) {
                    Text("native.auth.saveAndEnter")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(Palette.bg)
                        .background(Palette.ink, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(busy || password.isEmpty)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private func save() {
        busy = true
        errorText = nil
        Task {
            defer { busy = false }
            do {
                try await auth.updatePassword(password)
            } catch {
                errorText = AuthErrorKind.from(error).localizedMessage
            }
        }
    }
}
