import SwiftData
import SwiftUI

/// Avviso mostrato sopra le tab quando la sincronizzazione iCloud non è attiva.
struct SyncNotice: View {
    let state: SyncState

    var body: some View {
        if let key {
            Text(LocalizedStringKey(key))
                .font(.footnote)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Palette.surface)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1) }
                .accessibilityIdentifier("sync-notice")
        }
    }

    private var key: String? {
        switch state {
        case .active: return nil
        case .unavailable: return "native.sync.off"
        case .temporaryStore: return "native.sync.temporary"
        }
    }
}

struct RootTabView: View {
    let syncMonitor: SyncMonitor

    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @Query private var items: [Item]
    @Query private var bodyPhotos: [BodyPhoto]
    @State private var router = TabRouter()
    @State private var isOnboardingOpen = false
    @AppStorage("onboarding.done") private var onboardingDone = false

    /// Solo a chi parte da zero: chi ha già capi o foto non deve rifare i primi passi.
    private var needsOnboarding: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // I test si ripetono sullo stesso simulatore: la scelta salvata dal giro prima non conta.
        if arguments.contains("-SVShowOnboarding") { return true }
        if arguments.contains("-SVMemoryStore") { return false }
        #endif
        // Con l'archivio temporaneo i dati ci sono ma non si vedono: i primi passi coprirebbero l'avviso.
        guard syncMonitor.state != .temporaryStore else { return false }
        return !onboardingDone && items.isEmpty && bodyPhotos.isEmpty
    }

    private var selection: Binding<AppTab> {
        Binding(get: { router.selected }, set: { router.select($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            SyncNotice(state: syncMonitor.state)
            TabView(selection: selection) {
                WardrobeView { router.openAdd(to: $0) }
                    .tabItem { Label(LocalizedStringKey("nav.wardrobe"), systemImage: "tshirt") }
                    .tag(AppTab.wardrobe)
                OutfitView { router.openAdd(to: .wardrobe) }
                    .tabItem { Label(LocalizedStringKey("nav.outfit"), systemImage: "sparkles") }
                    .tag(AppTab.outfit)
                // Il + non ha una schermata: il foglio si apre da TabRouter.
                Color.clear.tabItem { Label(LocalizedStringKey("nav.add"), systemImage: "plus.circle.fill") }.tag(AppTab.add)
                CalendarView()
                    .tabItem { Label(LocalizedStringKey("nav.calendar"), systemImage: "calendar") }
                    .tag(AppTab.calendar)
                ProfileView().tabItem { Label(LocalizedStringKey("nav.profile"), systemImage: "person") }.tag(AppTab.profile)
            }
        }
        .background(Palette.bg)
        .onAppear { isOnboardingOpen = needsOnboarding }
        .fullScreenCover(isPresented: $isOnboardingOpen) {
            OnboardingView {
                onboardingDone = true
                isOnboardingOpen = false
            }
        }
        .tint(Palette.accent)
        .sheet(isPresented: $router.isAddSheetPresented) {
            ItemFormView(mode: .add(router.addDestination))
        }
        .task(id: profiles.count) { _ = try? ProfileStore.current(in: context) }
        // I doppioni arrivano da iCloud dopo l'avvio: si riguarda ogni volta che cambia il numero dei capi.
        .task(id: items.count) { try? DuplicateStore.clean(in: context) }
    }
}
