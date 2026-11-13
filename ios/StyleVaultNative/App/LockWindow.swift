import SwiftData
import SwiftUI
import UIKit

/// Porta `LockView` in una finestra propria, sopra ogni altra (anche fogli e avvisi): così il blocco copre
/// qualunque presentazione modale senza chiuderla, e le bozze non si perdono.
@MainActor
final class LockWindowController {
    private let placement: LockWindowPlacement<UIWindowScene, UIWindow>
    private var style = UIUserInterfaceStyle.unspecified

    init(lock: AppLock) {
        placement = LockWindowPlacement(
            make: { scene in
                let window = UIWindow(windowScene: scene)
                window.windowLevel = UIWindow.Level.alert + 1
                // Una vista nuova a ogni comparsa: la richiesta di sblocco parte una volta sola.
                let host = UIHostingController(rootView: LockView().environment(lock))
                // VoiceOver non deve raggiungere il contenuto (né il foglio) dietro il blocco.
                host.view.accessibilityViewIsModal = true
                window.rootViewController = host
                window.makeKeyAndVisible()
                return window
            },
            dismiss: { window in
                window.isHidden = true
                window.rootViewController = nil
                // Tastiera e fuoco tornano alla finestra principale.
                window.windowScene?.windows.first { !$0.isHidden && $0 !== window }?.makeKey()
            }
        )
    }

    func attach(to scene: UIWindowScene) {
        placement.attach(to: scene)
        placement.window?.overrideUserInterfaceStyle = style
    }

    func setVisible(_ visible: Bool) {
        placement.setVisible(visible)
        placement.window?.overrideUserInterfaceStyle = style
    }

    /// Segue il tema scelto nel Profilo; con "system" resta `.unspecified`.
    func setStyle(_ newStyle: UIUserInterfaceStyle) {
        style = newStyle
        placement.window?.overrideUserInterfaceStyle = newStyle
    }
}

/// Legge il tema dal Profilo (serve il contesto di SwiftData) e lo passa alla finestra del blocco.
struct LockThemeSync: View {
    let controller: LockWindowController
    @Query private var profiles: [Profile]

    var body: some View {
        let scheme = ThemeStore.colorScheme(for: ProfileStore.survivor(of: profiles)?.theme ?? "system")
        Color.clear
            .onChange(of: scheme, initial: true) { _, value in
                controller.setStyle(value == .dark ? .dark : value == .light ? .light : .unspecified)
            }
    }
}

/// Trova la `UIWindowScene` in cui sta la vista SwiftUI.
struct WindowSceneReader: UIViewRepresentable {
    let onScene: (UIWindowScene) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = Probe()
        view.onScene = onScene
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class Probe: UIView {
        var onScene: ((UIWindowScene) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene { onScene?(scene) }
        }
    }
}
