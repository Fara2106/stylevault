import SwiftUI

/// Dopo il link dell'email "Password dimenticata?": si sceglie la nuova
/// password e poi si entra nell'app.
struct NewPasswordView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("StyleVault").font(.display(34)).foregroundStyle(Palette.ink)
                    .padding(.top, 60).padding(.bottom, 14)
                Text("Scegli una nuova password").font(.display(26)).foregroundStyle(Palette.ink)
                if let email = auth.session?.user.email {
                    Text(email).font(.subheadline).foregroundStyle(Palette.muted)
                }
                SecureField("Nuova password", text: $password)
                    .textContentType(.newPassword)
                    .modifier(FieldStyle())

                if let error {
                    Text(error).font(.footnote).foregroundStyle(Palette.danger).multilineTextAlignment(.center)
                }

                Button(action: save) {
                    Group { busy ? AnyView(ProgressView().tint(Palette.bg)) : AnyView(Text("Salva ed entra")) }
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .background(Palette.ink).foregroundStyle(Palette.bg)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .disabled(busy)
            }
            .padding(.horizontal, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private func save() {
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do { try await auth.updatePassword(password) } catch { self.error = AuthErrorKind.from(error).message }
        }
    }
}
