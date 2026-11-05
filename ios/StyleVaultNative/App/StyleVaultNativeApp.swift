import SwiftData
import SwiftUI

@main
struct StyleVaultNativeApp: App {
    // Creati una sola volta e tenuti per tutta la vita dell'app: il mainContext non trattiene il container.
    private let container: ModelContainer
    @State private var syncMonitor: SyncMonitor

    init() {
        var preferred = StoreMode.cloud
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SVMemoryStore") { preferred = .memory }
        #endif
        let opened = StoreFactory.open(preferred: preferred)
        let monitor = SyncMonitor(health: opened.health)
        container = opened.container
        _syncMonitor = State(initialValue: monitor)
        monitor.start()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(syncMonitor: syncMonitor)
        }
        .modelContainer(container)
    }
}
