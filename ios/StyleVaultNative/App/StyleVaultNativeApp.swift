import SwiftData
import SwiftUI

@main
struct StyleVaultNativeApp: App {
    // Creati una sola volta e tenuti per tutta la vita dell'app: il mainContext non trattiene il container.
    private let container: ModelContainer
    @State private var syncMonitor: SyncMonitor
    @State private var appLock: AppLock
    @State private var lockWindow: LockWindowController
    @State private var wasInBackground = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        let preferred: StoreMode = ProcessInfo.processInfo.arguments.contains("-SVMemoryStore") ? .memory : .cloud
        #else
        let preferred = StoreMode.cloud
        #endif
        let lock = Self.makeAppLock()
        _appLock = State(initialValue: lock)
        _lockWindow = State(initialValue: LockWindowController(lock: lock))
        let opened = StoreFactory.open(preferred: preferred)
        let monitor = SyncMonitor(health: opened.health)
        container = opened.container
        _syncMonitor = State(initialValue: monitor)
        monitor.start()
    }

    private static func makeAppLock() -> AppLock {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SVFakeLock") {
            // Suite dedicata: il blocco non deve filtrare negli altri test UI.
            let suite = "StyleVaultNativeFakeLock"
            let defaults = UserDefaults(suiteName: suite) ?? .standard
            let reset = ProcessInfo.processInfo.arguments.contains("-SVFakeLockReset")
            if reset { defaults.removePersistentDomain(forName: suite) }
            return AppLock(defaults: defaults, authenticator: FakeAuthenticator(failingCall: reset ? 2 : 1))
        }
        #endif
        return AppLock(defaults: .standard, authenticator: SystemAuthenticator())
    }

    var body: some Scene {
        WindowGroup {
            let covered = appLock.isLocked || appLock.isObscured
            RootTabView(syncMonitor: syncMonitor)
                // Finché è coperto il contenuto non si vede, non si tocca e VoiceOver non lo legge.
                // La vera LockView sta in una finestra propria (LockWindow), sopra anche ai fogli.
                .overlay { if covered { Palette.bg.ignoresSafeArea() } }
                .accessibilityHidden(covered)
                .allowsHitTesting(!covered)
                .background(WindowSceneReader { lockWindow.attach(to: $0) })
                .background(LockThemeSync(controller: lockWindow))
                .environment(appLock)
                .onChange(of: covered, initial: true) { _, value in lockWindow.setVisible(value) }
                .onChange(of: scenePhase) { _, phase in
                    appLock.sceneDidChange(to: phase)
                    if phase == .background { wasInBackground = true }
                    if phase == .active, wasInBackground {
                        // Al ritorno dal background chiede lo sblocco; il foglio di Face ID passa da .inactive, non da qui.
                        wasInBackground = false
                        Task { await appLock.unlock(reason: String(localized: "native.lock.reason")) }
                    }
                }
        }
        .modelContainer(container)
    }
}
