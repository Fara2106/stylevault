import SwiftUI

@main
struct StyleVaultApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var web = WebViewStore()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // Solo sviluppo: `simctl launch … -SVPreviewBodyPhotos` apre il primo
            // accesso senza login (nel simulatore non c'è un account di prova)
            if ProcessInfo.processInfo.arguments.contains("-SVPreviewBodyPhotos") {
                BodyPhotosView(views: BodyView.allCases) {}
            } else {
                RootView(web: web).environmentObject(auth)
            }
            #else
            RootView(web: web).environmentObject(auth)
            #endif
        }
    }
}

/// Login nativo → primo accesso (3 foto del corpo, se mancano) → sito.
/// La sessione nativa viene passata alla WebView, così non si fa login due
/// volte; il logout dal sito torna al login nativo.
struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @ObservedObject var web: WebViewStore
    @State private var missingPhotos: [BodyView]?
    @State private var retakePhotos = false
    @State private var avatar: AvatarSession?

    var body: some View {
        Group {
            if auth.restoring {
                Palette.bg.ignoresSafeArea()
            } else if auth.session == nil {
                LoginView()
            } else if let missing = missingPhotos, !missing.isEmpty {
                BodyPhotosView(views: missing) { missingPhotos = [] }
            } else {
                WebContainerView(store: web)
            }
        }
        .onChange(of: auth.session?.accessToken) { _, _ in syncSession() }
        .onChange(of: auth.session?.user.id) { _, _ in Task { await checkPhotos() } }
        .onAppear {
            web.onMessage = { message in
                switch message {
                case .signOut: Task { await auth.signOut() }
                case .openBodyPhotos: retakePhotos = true
                case let .openAvatar(request): avatar = AvatarSession(request: request)
                default: break
                }
            }
            syncSession()
        }
        .task { await checkPhotos() }
        .fullScreenCover(isPresented: $retakePhotos) {
            BodyPhotosView(views: BodyView.allCases) { retakePhotos = false }
        }
        .fullScreenCover(item: $avatar) { session in
            AvatarView(request: session.request) { avatar = nil }
        }
    }

    private func syncSession() {
        guard let session = auth.session else { return }
        web.injectSession(access: session.accessToken, refresh: session.refreshToken)
        if web.webView.url == nil { web.load() }
    }

    /// Se il profilo non si legge (rete, colonne mancanti) si entra comunque:
    /// le foto si possono fare dopo dal Profilo.
    private func checkPhotos() async {
        guard auth.session != nil else { missingPhotos = nil; return }
        let existing = (try? await ProfileService().loadBodyPhotos()) ?? [.front: AppConfig.siteURL, .side: AppConfig.siteURL, .back: AppConfig.siteURL]
        missingPhotos = BodyPhotosModel.needsOnboarding(existing: existing)
    }
}

/// Un'apertura dell'avatar (ogni outfit è una nuova sessione).
struct AvatarSession: Identifiable {
    let id = UUID()
    let request: AvatarRequest
}
