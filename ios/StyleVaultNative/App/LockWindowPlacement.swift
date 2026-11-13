/// Decide quando creare e chiudere la finestra del blocco, senza conoscere UIKit (si prova con oggetti semplici).
/// Se la scena cambia mentre la finestra esiste, la vecchia si chiude e ne nasce una sulla nuova:
/// altrimenti la persona resterebbe davanti a una copertura senza tasto Sblocca.
@MainActor
final class LockWindowPlacement<Scene: AnyObject, Window> {
    private let make: (Scene) -> Window
    private let dismiss: (Window) -> Void
    private weak var scene: Scene?
    private var wantsVisible = false
    private(set) var window: Window?

    init(make: @escaping (Scene) -> Window, dismiss: @escaping (Window) -> Void) {
        self.make = make
        self.dismiss = dismiss
    }

    func attach(to newScene: Scene) {
        if let current = scene, current === newScene { return }
        scene = newScene
        closeWindow()
        apply()
    }

    func setVisible(_ visible: Bool) {
        wantsVisible = visible
        apply()
    }

    private func apply() {
        if wantsVisible {
            guard window == nil, let scene else { return }
            window = make(scene)
        } else {
            closeWindow()
        }
    }

    private func closeWindow() {
        guard let existing = window else { return }
        window = nil
        dismiss(existing)
    }
}
