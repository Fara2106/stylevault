import SwiftUI

/// Copre tutta la finestra quando l'app è bloccata o nascosta (selettore delle app).
struct LockView: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            if lock.isLocked {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill").font(.system(size: 40)).foregroundStyle(Palette.muted)
                    Text("native.lock.title").font(.headline).foregroundStyle(Palette.ink)
                    Button("native.lock.unlock") { Task { await unlock() } }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("unlock-button")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lock-screen")
        // Una sola richiesta quando compare: se la persona annulla resta il tasto Sblocca.
        // Al ritorno dal background la chiede l'App (qui la scena della finestra non segue quella dell'app).
        .task { if lock.isLocked { await unlock() } }
    }

    private func unlock() async {
        await lock.unlock(reason: String(localized: "native.lock.reason"))
    }
}
