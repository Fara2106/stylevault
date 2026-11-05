import SwiftData
import SwiftUI

@main
struct StyleVaultNativeApp: App {
    // Creati una sola volta e tenuti per tutta la vita dell'app: il mainContext non trattiene il container.
    private let container: ModelContainer
    @State private var syncMonitor: SyncMonitor
    @State private var appLock: AppLock
    @Environment(\.scenePhase) private var scenePhase

    init() {
        var preferred = StoreMode.cloud
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SVMemoryStore") { preferred = .memory }
        #endif
        var lockDefaults = UserDefaults.standard
        var authenticator: DeviceAuthenticating = SystemAuthenticator()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SVFakeLock") {
            // Suite dedicata: il blocco non deve filtrare negli altri test UI.
            let suite = "StyleVaultNativeFakeLock"
            lockDefaults = UserDefaults(suiteName: suite) ?? lockDefaults
            let reset = ProcessInfo.processInfo.arguments.contains("-SVFakeLockReset")
            if reset { lockDefaults.removePersistentDomain(forName: suite) }
            authenticator = FakeAuthenticator(cancelFirst: !reset)
        }
        #endif
        _appLock = State(initialValue: AppLock(defaults: lockDefaults, authenticator: authenticator))
        let opened = StoreFactory.open(preferred: preferred)
        let monitor = SyncMonitor(health: opened.health)
        container = opened.container
        _syncMonitor = State(initialValue: monitor)
        monitor.start()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView(syncMonitor: syncMonitor)
                if appLock.isLocked || appLock.isObscured { LockView() }
            }
            .environment(appLock)
            .onChange(of: scenePhase) { _, phase in appLock.sceneDidChange(to: phase) }
        }
        .modelContainer(container)
    }
}
