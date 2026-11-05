import SwiftUI
import UIKit

/// Porta `LockView` in una finestra propria, sopra ogni altra (anche fogli e avvisi): così il blocco copre
/// qualunque presentazione modale senza chiuderla, e le bozze non si perdono.
@MainActor
final class LockWindowController {
    private let lock: AppLock
    private weak var scene: UIWindowScene?
    private var window: UIWindow?
    private var wantsVisible = false

    init(lock: AppLock) { self.lock = lock }

    func attach(to scene: UIWindowScene) {
        guard self.scene !== scene else { return }
        self.scene = scene
        apply()
    }

    func setVisible(_ visible: Bool) {
        wantsVisible = visible
        apply()
    }

    private func apply() {
        guard let scene else { return }
        if wantsVisible {
            guard window == nil else { return }
            let lockWindow = UIWindow(windowScene: scene)
            lockWindow.windowLevel = UIWindow.Level.alert + 1
            // Una vista nuova a ogni comparsa: la richiesta di sblocco parte una volta sola.
            lockWindow.rootViewController = UIHostingController(rootView: LockView().environment(lock))
            lockWindow.makeKeyAndVisible()
            window = lockWindow
        } else if let lockWindow = window {
            lockWindow.isHidden = true
            lockWindow.rootViewController = nil
            window = nil
            // Tastiera e fuoco tornano alla finestra principale.
            scene.windows.first { !$0.isHidden }?.makeKey()
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
