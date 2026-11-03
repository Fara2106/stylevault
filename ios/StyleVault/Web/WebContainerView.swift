import SwiftUI
import WebKit

/// Il sito StyleVault dentro l'app, o la schermata offline se manca la rete.
struct WebContainerView: View {
    @ObservedObject var store: WebViewStore

    var body: some View {
        ZStack {
            // A tutto schermo: il sito gestisce notch e barra Home con
            // env(safe-area-inset-*) (viewport-fit=cover)
            WebViewRepresentable(webView: store.webView)
                .ignoresSafeArea()
            if store.offline {
                OfflineView { store.load() }
            }
        }
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct OfflineView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash").font(.system(size: 36, weight: .light))
            Text("Sei offline").font(.custom("Georgia", size: 26))
            Text("StyleVault ha bisogno della rete per caricare il tuo guardaroba.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Riprova", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(.primary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
