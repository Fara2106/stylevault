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
    @State private var router = TabRouter()

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
                placeholder("nav.outfit", .outfit, "sparkles")
                // Il + non ha una schermata: il foglio si apre da TabRouter.
                Color.clear.tabItem { Label(LocalizedStringKey("nav.add"), systemImage: "plus.circle.fill") }.tag(AppTab.add)
                placeholder("nav.calendar", .calendar, "calendar")
                ProfileView().tabItem { Label(LocalizedStringKey("nav.profile"), systemImage: "person") }.tag(AppTab.profile)
            }
        }
        .background(Palette.bg)
        .tint(Palette.accent)
        .sheet(isPresented: $router.isAddSheetPresented) {
            ItemFormView(mode: .add(router.addDestination))
        }
        .task(id: profiles.count) { _ = try? ProfileStore.current(in: context) }
    }

    private func placeholder(_ titleKey: String, _ tab: AppTab, _ symbol: String) -> some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            Text("native.comingSoon").foregroundStyle(Palette.muted)
        }
        .tabItem { Label(LocalizedStringKey(titleKey), systemImage: symbol) }
        .tag(tab)
    }
}
