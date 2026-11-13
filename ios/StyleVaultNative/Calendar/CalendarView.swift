import OSLog
import StyleVaultCore
import SwiftData
import SwiftUI

/// La schermata Calendario. Niente "Prova": arriva con la fase 6.
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.forecastLoader) private var forecastLoader
    @Query(sort: \CalendarEntry.createdAt, order: .reverse) private var entries: [CalendarEntry]
    @Query(sort: \Item.createdAt) private var items: [Item]
    @Query private var profiles: [Profile]

    /// Lato del cerchio del giorno: cresce con il testo, ma sette colonne devono stare nello schermo.
    @ScaledMetric(relativeTo: .subheadline) private var scaledDaySide: CGFloat = 32
    private var daySide: CGFloat { min(scaledDaySide, 44) }

    @State private var year = CalendarMath.local.component(.year, from: .now)
    @State private var month = CalendarMath.local.component(.month, from: .now)
    @State private var selected = CalendarMath.iso(.now)
    @State private var isPickerOpen = false
    @State private var forecast: [DayForecast] = []
    @State private var tryOn: TryOnSelection?
    @State private var removing: CalendarEntry?
    @AppStorage(TemperatureText.storageKey) private var temperatureUnit = "auto"

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "calendar")

    private var today: String { CalendarMath.iso(.now) }
    private var dayEntries: [CalendarEntry] { entries.filter { $0.day == selected } }

    private var profileCity: ForecastPlace? {
        ProfileStore.survivor(of: profiles).map {
            ForecastPlace(name: $0.cityName, latitude: $0.cityLatitude, longitude: $0.cityLongitude, isPosition: false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("calendar.title").displayFont(30).foregroundStyle(Palette.ink)
                        Text("calendar.subtitle").font(.footnote).foregroundStyle(Palette.muted)
                    }
                    monthCard
                    detail
                }
                .padding(16)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.bg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $tryOn) { selection in AvatarView(garments: selection) }
            .alert("native.calendar.removeTitle", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
                Button("common.cancel", role: .cancel) { removing = nil }
                Button("calendar.removeEntry", role: .destructive) {
                    if let entry = removing { perform { try OutfitStore.remove(entry, in: context) } }
                    removing = nil
                }
            }
            .sheet(isPresented: $isPickerOpen) {
                OutfitPickerView { outfit in assign(outfit) }
            }
            .task(id: profileCity?.name) {
                guard let city = profileCity else { return }
                let result = try? await forecastLoader.load(place: city)
                forecast = result?.days ?? []
            }
        }
    }

    // MARK: Mese

    private var monthTitle: String {
        let date = CalendarMath.local.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
        return date.formatted(.dateTime.month(.wide).year())
    }

    /// Le iniziali dei giorni, dal lunedì.
    private var weekdays: [String] {
        let symbols = CalendarMath.local.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    private func change(month delta: Int) {
        let start = CalendarMath.local.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
        let moved = CalendarMath.local.date(byAdding: .month, value: delta, to: start) ?? start
        year = CalendarMath.local.component(.year, from: moved)
        month = CalendarMath.local.component(.month, from: moved)
    }

    private var monthCard: some View {
        Card {
            VStack(spacing: 10) {
                HStack {
                    monthButton("chevron.left", label: "native.calendar.previous", id: "calendar-previous") { change(month: -1) }
                    Spacer()
                    Text(verbatim: monthTitle).font(.headline).foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("calendar-month")
                    Spacer()
                    monthButton("chevron.right", label: "native.calendar.next", id: "calendar-next") { change(month: 1) }
                }
                Grid(horizontalSpacing: 0, verticalSpacing: 4) {
                    GridRow {
                        ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                            Text(verbatim: day).font(.caption).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(Array(CalendarMath.monthMatrix(year: year, month: month).enumerated()), id: \.offset) { _, week in
                        GridRow {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                                if let day {
                                    dayCell(day)
                                } else {
                                    Color.clear.frame(maxWidth: .infinity, minHeight: 44)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func monthButton(_ symbol: String, label: LocalizedStringKey, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).foregroundStyle(Palette.ink).frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }

    private func dayCell(_ day: Int) -> some View {
        let iso = CalendarMath.iso(year: year, month: month, day: day)
        let logged = entries.filter { $0.day == iso }
        let isSelected = iso == selected
        return Button { selected = iso } label: {
            VStack(spacing: 2) {
                Text(verbatim: "\(day)")
                    .font(.subheadline)
                    // Con il testo grande «30» non entra nel cerchio: si rimpicciolisce quanto basta invece di diventare «…»
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(isSelected ? Palette.bg : Palette.ink)
                    .frame(width: daySide, height: daySide)
                    .background(isSelected ? Palette.ink : Color.clear, in: Circle())
                    .overlay {
                        if iso == today, !isSelected { Circle().stroke(Palette.ink) }
                    }
                Circle()
                    .fill(logged.contains(where: \.worn) ? Palette.ink : Palette.muted)
                    .frame(width: 5, height: 5)
                    .opacity(logged.isEmpty ? 0 : 1)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: DayText.long(iso)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("calendar-day-\(iso)")
    }

    // MARK: Giorno

    private var detail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(verbatim: DayText.long(selected)).font(.headline).foregroundStyle(Palette.ink)
                Spacer()
                if let day = forecast.first(where: { $0.date == selected }), let low = day.tMin, let high = day.tMax {
                    Label { Text(verbatim: "\(TemperatureText.string(low)) / \(TemperatureText.string(high))") } icon: { Image(systemName: day.icon.symbol) }
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("calendar-forecast")
                }
            }
            if forecast.contains(where: { $0.date == selected }) {
                WeatherCredit()
            }
            if dayEntries.isEmpty {
                Text("calendar.noOutfit").font(.footnote).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("calendar-empty")
            } else {
                ForEach(dayEntries) { entry in card(for: entry) }
            }
            Button { isPickerOpen = true } label: { Label("calendar.assignOutfit", systemImage: "plus") }
                .buttonStyle(OutlineButtonStyle())
                .accessibilityIdentifier("calendar-assign")
        }
    }

    private func deletedNote(_ names: [String]) -> some View {
        Group {
            if names.isEmpty {
                Text("calendar.deletedItems")
            } else {
                Text("calendar.deletedNamed \(names.joined(separator: ", "))")
            }
        }
        .font(.footnote)
        .foregroundStyle(Palette.muted)
        .accessibilityIdentifier("calendar-deleted")
    }

    private func repeatDate(for entry: CalendarEntry) -> String? {
        // Conta solo la settimana prima: il resto dello storico non si prepara nemmeno
        let week = CalendarMath.window(before: entry.day, days: 7)
        let near = entries.filter { $0.day != entry.day && !CalendarMath.isSurelyOutside($0.day, week) }
        return CalendarMath.repeatDate(for: entry.repeatLog, in: near.map(\.repeatLog))
    }

    private func card(for entry: CalendarEntry) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(entry.worn ? "calendar.worn" : "calendar.planned")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(entry.worn ? Palette.bg : Palette.ink)
                        .background(entry.worn ? Palette.ink : Palette.bg, in: Capsule())
                        .overlay(Capsule().stroke(Palette.border))
                        .accessibilityIdentifier("calendar-status")
                    if let date = repeatDate(for: entry) {
                        Text("calendar.repeatWarning \(DayText.medium(date))")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                            .accessibilityIdentifier("calendar-repeat")
                    }
                }
                let present = entry.present(in: items)
                ScrollView(.horizontal, showsIndicators: false) {
                    OutfitThumbs(items: present)
                }
                if entry.hasDeletedItems(in: items) {
                    deletedNote(entry.deletedNames(in: items))
                }
                HStack(spacing: 16) {
                    if !present.isEmpty {
                        Button("tryon.seeOnMe") { tryOn = .from(present) }
                            .tint(Palette.link)
                            .accessibilityIdentifier("calendar-avatar")
                    }
                    if OutfitStore.canMarkWorn(entry, today: today) {
                        Button("calendar.markWorn") { perform { try OutfitStore.markWorn(entry, in: context) } }
                            .tint(Palette.link)
                            .accessibilityIdentifier("calendar-mark-worn")
                    }
                    // Senza `role`: col ruolo iOS usa il suo rosso, fuori dalla palette.
                    Button { removing = entry } label: {
                        Text("calendar.removeEntry").foregroundStyle(Palette.danger)
                    }
                    .accessibilityIdentifier("calendar-remove")
                }
                .font(.footnote)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar-entry")
    }

    private func assign(_ outfit: Outfit) {
        perform { try OutfitStore.log(itemIDs: outfit.itemIDs, outfitID: outfit.id, day: selected, today: today, in: context) }
        isPickerOpen = false
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            logger.error("Calendario non aggiornato: \(error)")
        }
    }
}

/// La scelta di un outfit salvato da mettere su un giorno.
struct OutfitPickerView: View {
    let onPick: (Outfit) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Outfit.createdAt, order: .reverse) private var outfits: [Outfit]
    @Query private var items: [Item]

    var body: some View {
        NavigationStack {
            List {
                ForEach(outfits) { outfit in
                    Button { onPick(outfit) } label: { SavedOutfitRow(outfit: outfit, items: items) }
                        .listRowBackground(Palette.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .overlay {
                if outfits.isEmpty {
                    Text("calendar.noSavedOutfits")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .padding(32)
                        .accessibilityIdentifier("calendar-no-saved")
                }
            }
            .navigationTitle(Text("calendar.pickOutfit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }.accessibilityIdentifier("calendar-picker-close")
                }
            }
        }
        .tint(Palette.ink)
        .accessibilityIdentifier("calendar-picker")
    }
}
