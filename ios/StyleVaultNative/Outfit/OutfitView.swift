import OSLog
import StyleVaultCore
import SwiftData
import SwiftUI

/// La schermata Outfit. Niente "Prova": arriva con la fase 6.
struct OutfitView: View {
    let onAddItem: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.forecastLoader) private var forecastLoader
    @Environment(\.positionProvider) private var positionProvider
    @Query(sort: \Item.createdAt) private var items: [Item]
    @Query(sort: \CalendarEntry.createdAt, order: .reverse) private var entries: [CalendarEntry]
    @Query(sort: \Outfit.createdAt, order: .reverse) private var savedOutfits: [Outfit]
    @Query private var profiles: [Profile]

    @State private var model = OutfitPageModel()
    @State private var isPositionAsked = false
    // Fogli e non pagine: entrando in una pagina la barra si riaccende e, tornando, resta uno spazio vuoto in cima.
    @State private var isCitySearchOpen = false
    @State private var isSavedOpen = false
    @State private var tryOn: TryOnSelection?
    @AppStorage(TemperatureText.storageKey) private var temperatureUnit = "auto"

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "outfit")

    private var today: String { CalendarMath.iso(.now) }
    private var pieces: [OutfitPiece] { items.map(\.piece) }
    private var itemsByID: [String: Item] { Item.byID(items) }
    private var recentWear: [RecentWear] { OutfitStore.recentWear(from: entries) }

    private var defaultCity: ForecastPlace {
        let profile = ProfileStore.survivor(of: profiles)
        return ForecastPlace(name: profile?.cityName ?? "Milano", latitude: profile?.cityLatitude ?? 45.4642,
                             longitude: profile?.cityLongitude ?? 9.19, isPosition: false)
    }

    private var place: ForecastPlace { model.place(defaultCity: defaultCity) }
    private var placeKey: String { "\(place.latitude),\(place.longitude),\(place.name)" }
    private var weather: DayForecast? { model.dayWeather(city: place.name, today: today) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    placeRow
                    placeNote
                    dayChips
                    occasionChips
                    weatherSection
                    // A guardaroba vuoto il tasto spento coprirebbe quello che serve davvero: aggiungere un capo.
                    if !items.isEmpty { generateSection }
                    results
                    savedLink
                }
                .padding(16)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .toolbar(sizeClass == .regular ? .automatic : .hidden, for: .navigationBar)
            .task(id: placeKey) { await model.loadForecast(for: place, using: forecastLoader) }
            .task(id: model.choice == .position) { await readPosition() }
            // Meteo pronto, altro giorno, altra occasione o capi nuovi: gli outfit si rifanno da soli.
            .task(id: autoGenerateKey) {
                model.generateIfNeeded(items: pieces, recentWear: recentWear, city: place.name, today: today)
            }
            .sheet(isPresented: $isCitySearchOpen) {
                NavigationStack {
                    CitySearchView(title: "outfit.location") { city in
                        model.choose(SavedCity(name: city.name, latitude: city.latitude, longitude: city.longitude))
                    }
                    .toolbar { SheetCloseButton(id: "city-close") { isCitySearchOpen = false } }
                }
                .tint(Palette.ink)
            }
            .sheet(isPresented: $isSavedOpen) {
                NavigationStack {
                    SavedOutfitsView()
                        .toolbar { SheetCloseButton(id: "saved-close") { isSavedOpen = false } }
                }
                .tint(Palette.ink)
            }
            .sheet(item: $tryOn) { selection in AvatarView(garments: selection) }
            .alert("native.outfit.position.title", isPresented: $isPositionAsked) {
                Button("common.cancel", role: .cancel) {}
                Button("native.outfit.position.continue") { model.chooseMyPosition() }
            } message: {
                Text("native.outfit.position.message")
            }
        }
        // L'accento sui tasti del messaggio non arriva a 4,5:1.
        .tint(Palette.ink)
    }

    private var autoGenerateKey: String {
        "\(weather?.date ?? "-")|\(model.outfits.isEmpty)|\(items.count)"
    }

    private func readPosition() async {
        guard model.choice == .position else { return }
        let found = await positionProvider.currentPlace(fallbackName: String(localized: "outfit.myPosition"))
        guard !Task.isCancelled else { return }
        if let found {
            model.receive(position: found)
        } else {
            model.positionUnavailable = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("nav.outfit").font(.display(30)).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("outfit-title")
            Text("outfit.subtitle").font(.footnote).foregroundStyle(Palette.muted)
        }
    }

    private var placeRow: some View {
        HStack(spacing: 8) {
            Button { isCitySearchOpen = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                    Text(verbatim: place.name).foregroundStyle(Palette.ink).lineLimit(1)
                    Spacer()
                }
                .padding(10)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("outfit-city")
            Chip(text: Text("outfit.myPosition"), isSelected: model.choice == .position) {
                // Il permesso si chiede qui, dopo aver detto a cosa serve e dove vanno le coordinate.
                // Di nuovo sul tasto si torna alla città del Profilo, anche dopo un permesso negato.
                if model.choice == .position {
                    model.useDefaultCity()
                } else {
                    isPositionAsked = true
                }
            }
            .accessibilityIdentifier("outfit-position")
        }
    }

    @ViewBuilder private var placeNote: some View {
        if model.placeKind == .manual {
            note(Text(verbatim: "\(place.name) · ") + Text("outfit.chosenByHand"))
        } else if model.choice == .position, model.placeKind == .fallback, model.positionUnavailable {
            note(Text("outfit.positionUnavailable \(place.name)")).accessibilityIdentifier("outfit-position-note")
        }
    }

    private func note(_ text: Text) -> some View {
        text.font(.footnote).foregroundStyle(Palette.muted)
    }

    private func dayLabel(_ index: Int) -> Text {
        switch index {
        case 0: return Text("outfit.today")
        case 1: return Text("outfit.tomorrow")
        default: return Text(verbatim: DayText.short(DayText.adding(index, to: today)))
        }
    }

    private var dayChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    Chip(text: dayLabel(index), isSelected: model.dayIndex == index) { model.select(day: index) }
                        .accessibilityIdentifier("outfit-day-\(index)")
                }
            }
            .padding(1)
        }
    }

    private var occasionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(text: Text("common.all"), isSelected: model.occasion == "all") { model.select(occasion: "all") }
                ForEach(Catalog.occasions) { occasion in
                    Chip(text: Text(LocalizedStringKey(occasion.labelKey)), isSelected: model.occasion == occasion.id) {
                        model.select(occasion: occasion.id)
                    }
                    .accessibilityIdentifier("outfit-occasion-\(occasion.id)")
                }
            }
            .padding(1)
        }
    }

    @ViewBuilder private var weatherSection: some View {
        if model.usesManualWeather(today: today) {
            manualWeather
        } else if let weather {
            WeatherCard(weather: weather, stale: model.forecast?.stale ?? false, fetchedAt: model.forecast?.fetchedAt)
            if let parts = weather.parts { DayStripView(parts: parts) }
        } else {
            ProgressView { Text("common.loading") }
                .frame(maxWidth: .infinity)
                .tint(Palette.ink)
        }
    }

    private var manualWeather: some View {
        @Bindable var model = model
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("outfit.manualWeather").font(.subheadline).foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("outfit-manual")
                Stepper(value: $model.manualTemperature, in: -30...50, step: 1) {
                    Text("outfit.manualTemp").font(.footnote).foregroundStyle(Palette.muted)
                    + Text(verbatim: "  \(TemperatureText.string(model.manualTemperature))").font(.subheadline).foregroundStyle(Palette.ink)
                }
                .accessibilityIdentifier("outfit-manual-temp")
                Toggle("outfit.manualRain", isOn: $model.manualRain)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("outfit-manual-rain")
            }
        }
    }

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                model.generate(items: pieces, recentWear: recentWear, city: place.name, today: today)
            } label: {
                Label(model.outfits.isEmpty ? "outfit.generateOutfit" : "outfit.regenerate", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(Palette.bg)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(weather == nil)
            .opacity(weather == nil ? 0.5 : 1)
            .accessibilityIdentifier("outfit-generate")
            if !model.lockedIDs.isEmpty {
                Label("outfit.regenerateHint", systemImage: "lock").font(.footnote).foregroundStyle(Palette.muted)
            }
            if let day = model.wornDay {
                Text("outfit.wornToday \(DayText.medium(day))")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("outfit-worn-message")
            }
        }
    }

    @ViewBuilder private var results: some View {
        if items.isEmpty {
            VStack(spacing: 12) {
                Text("wardrobe.emptyState").font(.headline).foregroundStyle(Palette.ink)
                EmptyWardrobeHint()
                Button("wardrobe.emptyAction", action: onAddItem)
                    .buttonStyle(InkButtonStyle())
                    .accessibilityIdentifier("outfit-empty-add")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else if model.outfits.isEmpty, weather != nil {
            VStack(spacing: 6) {
                Text("outfit.noOutfits").font(.headline).foregroundStyle(Palette.ink)
                Text("outfit.noItemsForOutfit").font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ForEach(model.outfits) { outfit in
                VStack(alignment: .leading, spacing: 8) {
                    OutfitCardView(outfit: outfit, items: itemsByID, lockedIDs: model.lockedIDs, saved: model.isSaved(outfit),
                                   wornLabel: wornLabel(for: outfit), onToggleLock: model.toggleLock, onSave: { save(outfit) }, onTryOn: { tryOn = .from(outfit, items: itemsByID) }, onWear: { wear(outfit) })
                    advice(for: outfit)
                }
            }
        }
    }

    @ViewBuilder private func advice(for outfit: GeneratedOutfit) -> some View {
        if let weather {
            let list = OutfitAdvisor.advice(for: outfit, weather: weather, recentWear: recentWear, occasion: model.occasion).prefix(4)
            if !list.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("outfit.adviceTitle").font(.caption).foregroundStyle(Palette.muted)
                    ForEach(Array(list.enumerated()), id: \.offset) { _, entry in
                        Text(verbatim: "· \(entry.text(itemNames: itemsByID.mapValues(\.name)))")
                            .font(.footnote)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 4)
                .accessibilityIdentifier("outfit-advice")
            }
        }
    }

    @ViewBuilder private var savedLink: some View {
        if !savedOutfits.isEmpty {
            Button { isSavedOpen = true } label: {
                HStack {
                    Text("native.outfit.saved.title")
                    Spacer()
                    Text(verbatim: "\(savedOutfits.count)").foregroundStyle(Palette.muted)
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.muted)
                }
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("outfit-saved-link")
        }
    }

    private func wornLabel(for outfit: GeneratedOutfit) -> LocalizedStringKey? {
        guard model.isWorn(outfit) else { return nil }
        return (model.wornDay ?? today) <= today ? "calendar.worn" : "calendar.planned"
    }

    private func ids(of outfit: GeneratedOutfit) -> [UUID] { outfit.pieces.compactMap { UUID(uuidString: $0.id) } }

    private func save(_ outfit: GeneratedOutfit) {
        do {
            try OutfitStore.save(itemIDs: ids(of: outfit), occasion: model.occasion, score: outfit.score, in: context)
            model.markSaved(outfit)
        } catch {
            logger.error("Outfit non salvato: \(error)")
        }
    }

    private func wear(_ outfit: GeneratedOutfit) {
        // Il giorno scelto, non quello della previsione: un luogo lontano può essere già a domani.
        let day = DayText.adding(model.dayIndex, to: today)
        do {
            try OutfitStore.log(itemIDs: ids(of: outfit), outfitID: nil, day: day, today: today, in: context)
            model.markWorn(outfit, day: day)
        } catch {
            logger.error("Outfit non registrato: \(error)")
        }
    }
}

/// Il tasto Chiudi dei fogli.
struct SheetCloseButton: ToolbarContent {
    let id: String
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("common.close", action: action).accessibilityIdentifier(id)
        }
    }
}

/// Gli outfit salvati: senza elenco non si potrebbero togliere.
struct SavedOutfitsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Outfit.createdAt, order: .reverse) private var outfits: [Outfit]
    @Query private var items: [Item]

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "outfit")

    var body: some View {
        List {
            ForEach(outfits) { outfit in
                SavedOutfitRow(outfit: outfit, items: items)
                    .listRowBackground(Palette.surface)
            }
            .onDelete { offsets in
                for index in offsets {
                    do {
                        try OutfitStore.delete(outfits[index], in: context)
                    } catch {
                        logger.error("Outfit non cancellato: \(error)")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(Text("native.outfit.saved.title"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if outfits.isEmpty {
                Text("native.outfit.saved.empty").font(.footnote).foregroundStyle(Palette.muted)
            }
        }
    }
}

/// Una riga di outfit salvato: i capi che esistono ancora, punteggio e occasione.
struct SavedOutfitRow: View {
    let outfit: Outfit
    let items: [Item]

    private var pieces: [Item] { outfit.itemIDs.compactMap { id in items.first { $0.id == id } } }

    private var caption: Text {
        let occasion = Catalog.occasions.first { $0.id == outfit.occasion }
        switch (outfit.score, occasion) {
        case (let score?, let occasion?):
            return Text("outfit.outfitScore") + Text(verbatim: " \(score) · ") + Text(LocalizedStringKey(occasion.labelKey))
        case (let score?, nil): return Text("outfit.outfitScore") + Text(verbatim: " \(score)")
        case (nil, let occasion?): return Text(LocalizedStringKey(occasion.labelKey))
        case (nil, nil): return Text("calendar.customOutfit")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            OutfitThumbs(items: Array(pieces.prefix(5)), size: 48)
            caption.font(.caption).foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("saved-outfit")
    }
}
