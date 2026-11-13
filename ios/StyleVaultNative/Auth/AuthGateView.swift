import SwiftData
import SwiftUI

/// Decide fra accesso, nuova password e app. Il contenuto resta lo stesso per chi entra con o senza account.
struct AuthGateView<Content: View>: View {
    @ObservedObject var auth: AuthService
    /// I test UI partono senza passare dall'accesso.
    let bypass: Bool
    @ViewBuilder let content: () -> Content
    @AppStorage("auth.skipped") private var skipped = false
    @Query private var profiles: [Profile]

    var body: some View {
        Group {
            switch AuthRoute.resolve(restoring: auth.restoring, recovering: auth.recovering,
                                     signedIn: auth.session != nil, skipped: skipped || bypass) {
            case .loading: Palette.bg.ignoresSafeArea()
            case .login: LoginView { skipped = true }
            case .newPassword: NewPasswordView()
            case .app: content()
            }
        }
        // Qui e non nelle tab: il tema scelto vale anche per l'accesso.
        .preferredColorScheme(ThemeStore.colorScheme(for: ProfileStore.survivor(of: profiles)?.theme ?? "system"))
    }
}
