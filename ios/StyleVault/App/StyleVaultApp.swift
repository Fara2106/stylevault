import SwiftUI

@main
struct StyleVaultApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var web = WebViewStore()

    var body: some Scene {
        WindowGroup {
            RootView(web: web).environmentObject(auth)
        }
    }
}

/// Login nativo → sito. La sessione nativa viene passata alla WebView,
/// così non si fa login due volte; il logout dal sito torna al login nativo.
struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @ObservedObject var web: WebViewStore

    var body: some View {
        Group {
            if auth.restoring {
                Palette.bg.ignoresSafeArea()
            } else if auth.session == nil {
                LoginView()
            } else {
                WebContainerView(store: web)
            }
        }
        .onChange(of: auth.session?.accessToken) { _, _ in syncSession() }
        .onAppear {
            web.onMessage = { message in
                if case .signOut = message { Task { await auth.signOut() } }
            }
            syncSession()
        }
    }

    private func syncSession() {
        guard let session = auth.session else { return }
        web.injectSession(access: session.accessToken, refresh: session.refreshToken)
        if web.webView.url == nil { web.load() }
    }
}
