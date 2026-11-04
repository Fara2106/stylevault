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
    @State private var retake: RetakeSession?
    @State private var avatar: AvatarSession?
    /// Posizione per il meteo (una richiesta alla volta, solo quando il sito la chiede)
    @State private var location = LocationProvider()
    @AppStorage(ThemeStore.key) private var theme = "system"

    var body: some View {
        Group {
            if auth.restoring {
                Palette.bg.ignoresSafeArea()
            } else if auth.session == nil {
                LoginView()
            } else if auth.recovering {
                NewPasswordView()
            } else if let missing = missingPhotos, !missing.isEmpty {
                BodyPhotosView(views: missing) {
                    missingPhotos = []
                    web.pushBodyPhotosChanged()
                }
            } else {
                WebContainerView(store: web)
            }
        }
        .onChange(of: auth.session?.accessToken) { _, _ in syncSession() }
        .onChange(of: auth.recovering) { _, _ in syncSession() }
        .onOpenURL { url in Task { await auth.handle(url) } }
        .onChange(of: auth.session?.user.id) { _, _ in Task { await checkPhotos() } }
        .onAppear {
            web.onMessage = { message in
                switch message {
                case .signOut: Task { await auth.signOut() }
                case let .openBodyPhotos(view):
                    retake = RetakeSession(views: view.map { [$0] } ?? BodyView.allCases)
                case let .openAvatar(request): avatar = AvatarSession(request: request)
                case let .themeChanged(setting): theme = setting
                case let .requestForecast(request):
                    Task {
                        if let forecast = await AppleWeather.forecast(for: request) { web.pushForecast(forecast) }
                    }
                case .requestLocation:
                    Task {
                        if let place = await location.currentPlace() { web.pushLocation(place) }
                    }
                default: break
                }
            }
            syncSession()
        }
        .task { await checkPhotos() }
        .fullScreenCover(item: $retake) { session in
            BodyPhotosView(views: session.views, leaveTitle: "Chiudi") {
                retake = nil
                web.pushBodyPhotosChanged()
            }
                .preferredColorScheme(ThemeStore.colorScheme(for: theme))
        }
        .fullScreenCover(item: $avatar) { session in
            AvatarView(request: session.request) { avatar = nil }
                .preferredColorScheme(ThemeStore.colorScheme(for: theme))
        }
        .preferredColorScheme(ThemeStore.colorScheme(for: theme))
    }

    /// Al sito solo sessioni valide: una scaduta la rinnova prima il nativo
    /// (se la rinnovassero entrambi, Supabase chiuderebbe la sessione).
    private func syncSession() {
        guard let session = auth.session, !session.isExpired, !auth.recovering else { return }
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

/// Un "rifai le foto" chiesto dal sito: una vista o tutte.
struct RetakeSession: Identifiable {
    let id = UUID()
    let views: [BodyView]
}

/// Un'apertura dell'avatar (ogni outfit è una nuova sessione).
struct AvatarSession: Identifiable {
    let id = UUID()
    let request: AvatarRequest
}
