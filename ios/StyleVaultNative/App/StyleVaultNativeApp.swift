import SwiftData
import SwiftUI

@main
struct StyleVaultNativeApp: App {
    // Creati una sola volta e tenuti per tutta la vita dell'app: il mainContext non trattiene il container.
    private let container: ModelContainer
    @State private var syncMonitor: SyncMonitor
    @State private var cutoutWorker: CutoutWorker
    @State private var appLock: AppLock
    @State private var lockWindow: LockWindowController
    @StateObject private var auth = AuthService()
    @State private var wasInBackground = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SVInitCloudSchema") { CloudSchema.initialize() }
        if ProcessInfo.processInfo.arguments.contains("-SVShowLogin") {
            UserDefaults.standard.removeObject(forKey: "auth.skipped")
        }
        let preferred: StoreMode = ProcessInfo.processInfo.arguments.contains("-SVMemoryStore") ? .memory : .cloud
        if preferred == .memory {
            // Il dato in memoria riparte vuoto a ogni test: anche il luogo scelto deve ripartire da zero.
            UserDefaults.standard.removeObject(forKey: "outfit.place")
            UserDefaults.standard.removeObject(forKey: "outfit.place.position")
        }
        #else
        let preferred = StoreMode.cloud
        #endif
        let lock = Self.makeAppLock()
        _appLock = State(initialValue: lock)
        _lockWindow = State(initialValue: LockWindowController(lock: lock))
        let opened = StoreFactory.open(preferred: preferred)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SVSeedWardrobe") { DebugSeed.fill(opened.container.mainContext) }
        if ProcessInfo.processInfo.arguments.contains("-SVSeedBodyPhoto") { DebugSeed.fillBodyPhoto(opened.container.mainContext) }
        #endif
        let monitor = SyncMonitor(health: opened.health)
        container = opened.container
        _cutoutWorker = State(initialValue: CutoutWorker(context: opened.container.mainContext))
        _syncMonitor = State(initialValue: monitor)
        monitor.start()
    }

    private static var skipsLogin: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-SVMemoryStore") && !arguments.contains("-SVShowLogin")
        #else
        return false
        #endif
    }

    private static func makeLinkReader() -> any LinkReading {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SVFakeLink") { return FakeLinkReader() }
        #endif
        return SystemLinkReader()
    }

    private static func makeForecastLoader() -> any ForecastLoading {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-SVFakeForecast") { return FakeForecastLoader(fails: false) }
        if arguments.contains("-SVFakeForecastFail") { return FakeForecastLoader(fails: true) }
        #endif
        return OpenMeteoLoader()
    }

    private static func makeBodyPhotoAnalyzer() -> any BodyPhotoAnalyzing {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SVFakeBody") { return FakeBodyAnalyzer() }
        #endif
        return SystemBodyPhotoAnalyzer()
    }

    private static func makeAvatarRenderer() -> any AvatarRendering {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SVFakeBody") { return FakeAvatarRenderer() }
        #endif
        return SystemAvatarRenderer()
    }

    private static func makePositionProvider() -> any PositionProviding {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-SVFakePosition") { return FakePositionProvider(denied: false) }
        if arguments.contains("-SVFakePositionDenied") { return FakePositionProvider(denied: true) }
        #endif
        return SystemPositionProvider()
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
            AuthGateView(auth: auth, bypass: Self.skipsLogin) { RootTabView(syncMonitor: syncMonitor) }
                .environmentObject(auth)
                .onOpenURL { url in Task { await auth.handle(url) } }
                // Finché è coperto il contenuto non si vede, non si tocca e VoiceOver non lo legge.
                // La vera LockView sta in una finestra propria (LockWindow), sopra anche ai fogli.
                .overlay { if covered { Palette.bg.ignoresSafeArea() } }
                .accessibilityHidden(covered)
                .allowsHitTesting(!covered)
                .background(WindowSceneReader { lockWindow.attach(to: $0) })
                .background(LockThemeSync(controller: lockWindow))
                .environment(appLock)
                .environment(cutoutWorker)
                .environment(\.linkReader, Self.makeLinkReader())
                .environment(\.forecastLoader, Self.makeForecastLoader())
                .environment(\.positionProvider, Self.makePositionProvider())
                .environment(\.bodyPhotoAnalyzer, Self.makeBodyPhotoAnalyzer())
                .environment(\.avatarRenderer, Self.makeAvatarRenderer())
                .onChange(of: covered, initial: true) { _, value in lockWindow.setVisible(value) }
                .onChange(of: scenePhase, initial: true) { _, phase in
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
