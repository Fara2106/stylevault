import AuthenticationServices
import SwiftUI

/// L'accesso: Apple, Google, email e password, password dimenticata. Si può saltare.
struct LoginView: View {
    let onSkip: () -> Void

    @EnvironmentObject private var auth: AuthService
    @Environment(\.colorScheme) private var colorScheme
    @State private var registering = false
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var notice: String?
    @State private var busy = false
    @State private var appleNonce = AppleNonce()
    @FocusState private var passwordFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(verbatim: "StyleVault")
                    .font(.display(34))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 48)
                Text(registering ? "auth.registerSubtitle" : "auth.loginSubtitle")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .padding(.bottom, 10)

                SignInWithAppleButton(.continue) { request in
                    let nonce = AppleNonce()
                    appleNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = nonce.hashed
                } onCompletion: { apple($0) }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 52)
                    .disabled(busy)
                    .accessibilityIdentifier("login-apple")

                if auth.googleAvailable {
                    Button(action: google) {
                        Text("auth.google").frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .foregroundStyle(Palette.ink)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border))
                    .disabled(busy)
                    .accessibilityIdentifier("login-google")
                }

                TextField("auth.email", text: $email,
                          prompt: Text("auth.email").foregroundStyle(Palette.muted))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { passwordFocused = true }
                    .modifier(FieldBox())
                    .accessibilityIdentifier("login-email")
                SecureField("auth.password", text: $password,
                            prompt: Text("auth.password").foregroundStyle(Palette.muted))
                    .textContentType(registering ? .newPassword : .password)
                    .focused($passwordFocused)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .modifier(FieldBox())
                    .accessibilityIdentifier("login-password")

                if !registering {
                    Button("auth.forgotPassword", action: forgot)
                        .font(.footnote)
                        .tint(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("login-forgot")
                }
                if let errorText {
                    Text(verbatim: errorText)
                        .font(.footnote)
                        .foregroundStyle(Palette.danger)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("login-error")
                } else if auth.recoveryLinkFailed {
                    Text("native.auth.linkFailed")
                        .font(.footnote)
                        .foregroundStyle(Palette.danger)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("login-error")
                }
                if let notice {
                    Text(verbatim: notice)
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("login-notice")
                }

                Button(action: submit) {
                    Group {
                        if busy {
                            ProgressView().tint(Palette.bg)
                        } else {
                            Text(registering ? "auth.register" : "auth.login")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Palette.bg)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .accessibilityIdentifier("login-submit")

                Button {
                    registering.toggle()
                    errorText = nil
                    notice = nil
                } label: {
                    // La parte da toccare sta in inchiostro: tutta grigia sembrava una didascalia.
                    (Text(registering ? "auth.hasAccount" : "auth.noAccount").foregroundStyle(Palette.muted)
                        + Text(verbatim: " ")
                        + Text(registering ? "auth.login" : "auth.register").bold().foregroundStyle(Palette.ink))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .accessibilityIdentifier("login-toggle")

                Button("native.auth.skip", action: onSkip)
                    .font(.subheadline)
                    .tint(Palette.link)
                    .padding(.top, 8)
                    .accessibilityIdentifier("login-skip")

                HStack(spacing: 20) {
                    Link(destination: AppConfig.privacyURL) { Text("native.auth.privacy") }
                    Link(destination: AppConfig.supportURL) { Text("native.auth.support") }
                }
                .font(.caption.weight(.semibold))
                .tint(Palette.muted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg.ignoresSafeArea())
        .task { await auth.refreshProviders() }
    }

    private func submit() {
        let address = email.trimmingCharacters(in: .whitespaces)
        guard !address.isEmpty, !password.isEmpty else {
            notice = nil
            errorText = String(localized: "auth.errors.missing-fields")
            return
        }
        run { [auth, registering, password] in
            if registering {
                try await auth.signUp(name: "", email: address, password: password)
            } else {
                try await auth.signIn(email: address, password: password)
            }
        }
    }

    private func forgot() {
        let address = email.trimmingCharacters(in: .whitespaces)
        guard !address.isEmpty else {
            notice = nil
            errorText = String(localized: "native.auth.writeEmail")
            return
        }
        run { [auth] in
            try await auth.sendPasswordReset(email: address)
            notice = String(localized: "native.auth.resetSent \(address)")
        }
    }

    private func google() { run { [auth] in try await auth.signInWithGoogle() } }

    private func apple(_ result: Result<ASAuthorization, Error>) {
        run { [auth, appleNonce] in
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AppleTokenMissing()
            }
            try await auth.signInWithApple(credential: credential, nonce: appleNonce)
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        errorText = nil
        notice = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                try await work()
            } catch {
                let kind = AuthErrorKind.from(error)
                // Con un'email già usata si passa ad "Accedi", dove c'è "Password dimenticata?".
                if kind == .emailTaken { registering = false }
                errorText = kind.localizedMessage
            }
        }
    }
}
