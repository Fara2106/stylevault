import AuthenticationServices
import SwiftUI

/// Login nativo: stile del sito, email/password, Google e Apple (se attivo).
struct LoginView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var registering = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("EST. 2026").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Palette.muted)
                    Text("StyleVault").font(.display(46)).foregroundStyle(Palette.ink)
                    Text("Il tuo guardaroba, sempre con te").font(.display(17).italic()).foregroundStyle(Palette.muted)
                }
                .padding(.top, 60)

                VStack(spacing: 14) {
                    Text(registering ? "Crea il tuo account" : "Bentornato").font(.display(26)).foregroundStyle(Palette.ink)
                    if registering {
                        field("Nome", text: $name).textContentType(.name)
                    }
                    field("Email", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(registering ? .newPassword : .password)
                        .modifier(FieldStyle())

                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Palette.danger).multilineTextAlignment(.center)
                    }

                    Button(action: submit) {
                        Group { busy ? AnyView(ProgressView().tint(Palette.bg)) : AnyView(Text(registering ? "Registrati" : "Accedi")) }
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .background(Palette.ink).foregroundStyle(Palette.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .disabled(busy)

                    if auth.googleAvailable {
                        Button(action: google) {
                            Text("Continua con Google").frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .foregroundStyle(Palette.ink)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border))
                        .disabled(busy)
                    }

                    if AppConfig.appleSignInEnabled {
                        SignInWithAppleButton(.continue) { _ in } onCompletion: { _ in }
                            .frame(height: 52)
                    }
                }

                Button {
                    registering.toggle()
                    error = nil
                } label: {
                    Text(registering ? "Hai già un account? **Accedi**" : "Non hai un account? **Registrati**")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
        .task { await auth.refreshProviders() }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text).modifier(FieldStyle())
    }

    private func submit() { run { [self] in
        if registering {
            try await auth.signUp(name: name, email: email, password: password)
        } else {
            try await auth.signIn(email: email, password: password)
        }
    } }

    private func google() { run { [auth] in try await auth.signInWithGoogle() } }

    private func run(_ work: @escaping () async throws -> Void) {
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do { try await work() } catch { self.error = AuthErrorKind.from(error).message }
        }
    }
}

private struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .padding(.horizontal, 14).frame(height: 52)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border))
    }
}
