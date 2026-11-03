import SwiftUI

@main
struct StyleVaultApp: App {
    @StateObject private var web = WebViewStore()

    var body: some Scene {
        WindowGroup {
            WebContainerView(store: web)
                .onAppear { web.load() }
        }
    }
}
