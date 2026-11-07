import Foundation
import Observation
import StyleVaultCore

struct SavedCity: Codable, Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
}

/// Da dove viene il meteo. Si parte dalla città del Profilo: la posizione si usa solo dopo averla chiesta.
enum PlaceChoice: Equatable {
    case defaultCity, position
    case city(SavedCity)
}

enum PlaceKind { case fallback, position, manual }

/// Lo stato della schermata Outfit.
@MainActor @Observable final class OutfitPageModel {
    private static let placeKey = "outfit.place"
    /// Entro ~5 km il meteo è lo stesso: gli outfit già mostrati non cambiano.
    private static let sameWeatherDegrees = 0.05
    private static let forecastLifetime: TimeInterval = 3600

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var choice: PlaceChoice
    private(set) var position: ForecastPlace?
    var positionUnavailable = false
    private(set) var forecast: ForecastResult?
    private(set) var weatherError = false
    var manualTemperature = 20.0
    var manualRain = false
    private(set) var dayIndex = 0
    private(set) var occasion = "all"
    private(set) var outfits: [GeneratedOutfit] = []
    private(set) var lockedIDs: Set<String> = []
    private var savedOutfits: Set<UUID> = []
    private var wornOutfits: Set<UUID> = []
    private var loadedPlace: ForecastPlace?
    /// Il giorno su cui si è appena registrato un outfit.
    var wornDay: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        choice = Self.readChoice(from: defaults)
    }

    private static func readChoice(from defaults: UserDefaults) -> PlaceChoice {
        guard let data = defaults.data(forKey: placeKey) else {
            return defaults.bool(forKey: placeKey + ".position") ? .position : .defaultCity
        }
        return (try? JSONDecoder().decode(SavedCity.self, from: data)).map(PlaceChoice.city) ?? .defaultCity
    }

    func choose(_ city: SavedCity) {
        choice = .city(city)
        defaults.set(try? JSONEncoder().encode(city), forKey: Self.placeKey)
        defaults.set(false, forKey: Self.placeKey + ".position")
    }

    /// Le coordinate non si ricordano: solo la scelta.
    func chooseMyPosition() {
        choice = .position
        positionUnavailable = false
        defaults.removeObject(forKey: Self.placeKey)
        defaults.set(true, forKey: Self.placeKey + ".position")
    }

    func useDefaultCity() {
        choice = .defaultCity
        position = nil
        positionUnavailable = false
        defaults.removeObject(forKey: Self.placeKey)
        defaults.set(false, forKey: Self.placeKey + ".position")
    }

    func receive(position new: ForecastPlace) {
        guard choice == .position else { return }
        positionUnavailable = false
        if let old = position, abs(old.latitude - new.latitude) <= Self.sameWeatherDegrees,
           abs(old.longitude - new.longitude) <= Self.sameWeatherDegrees { return }
        position = new
    }

    var placeKind: PlaceKind {
        switch choice {
        case .city: return .manual
        case .position: return position == nil ? .fallback : .position
        case .defaultCity: return .fallback
        }
    }

    func place(defaultCity: ForecastPlace) -> ForecastPlace {
        switch choice {
        case .city(let city):
            return ForecastPlace(name: city.name, latitude: city.latitude, longitude: city.longitude, isPosition: false)
        case .position: return position ?? defaultCity
        case .defaultCity: return defaultCity
        }
    }

    /// Cambiando luogo gli outfit vecchi erano per un altro meteo. Tornando sulla scheda, invece, resta
    /// tutto com'era: `.task` riparte a ogni ritorno e rifare gli outfit perderebbe blocchi e "Salvato".
    func loadForecast(for place: ForecastPlace, using loader: any ForecastLoading, now: Date = .now) async {
        if place == loadedPlace, let current = forecast, !current.stale,
           now.timeIntervalSince(current.fetchedAt) < Self.forecastLifetime { return }
        loadedPlace = place
        weatherError = false
        forecast = nil
        outfits = []
        do {
            let result = try await loader.load(place: place)
            guard !Task.isCancelled else { return }
            forecast = result
        } catch {
            guard !Task.isCancelled else { return }
            weatherError = true
        }
    }

    /// Il giorno scelto si cerca per data: una previsione rimasta in memoria può iniziare giorni fa.
    private func forecastDay(today: String) -> DayForecast? {
        guard let days = forecast?.days else { return nil }
        if let match = days.first(where: { $0.date == DayText.adding(dayIndex, to: today) }) { return match }
        // Un luogo già al giorno dopo (Tokyo, la sera da Milano) non ha il "nostro" oggi: conta la posizione.
        if let first = days.first?.date, first > today, days.indices.contains(dayIndex) { return days[dayIndex] }
        return nil
    }

    func dayWeather(city: String, today: String) -> DayForecast? {
        if let day = forecastDay(today: today) { return day }
        guard usesManualWeather(today: today) else { return nil }
        return DayForecast(city: city, date: DayText.adding(dayIndex, to: today), tMin: nil, tMax: nil,
                           temperature: manualTemperature, windSpeed: 0, uvIndex: 0, precipProb: nil,
                           icon: manualRain ? .rain : .sun, descriptionKey: manualRain ? "weather.rainy" : "weather.clear",
                           rain: manualRain, snow: false)
    }

    /// Senza previsione per quel giorno si imposta a mano: l'outfit non resta mai bloccato.
    func usesManualWeather(today: String) -> Bool {
        weatherError || (forecast != nil && forecastDay(today: today) == nil)
    }

    func select(day: Int) {
        dayIndex = day
        outfits = []
    }

    func select(occasion: String) {
        self.occasion = occasion
        outfits = []
    }

    func toggleLock(_ id: String) {
        if lockedIDs.remove(id) == nil { lockedIDs.insert(id) }
    }

    func generate(items: [OutfitPiece], recentWear: [RecentWear], city: String = "", today: String = CalendarMath.iso(.now)) {
        guard let weather = dayWeather(city: city, today: today) else { return }
        var generator = SystemRandomNumberGenerator()
        outfits = OutfitEngine.generate(items: items, weather: weather, occasion: occasion, count: 3,
                                        locked: items.filter { lockedIDs.contains($0.id) }, recentWear: recentWear,
                                        referenceDate: weather.date, using: &generator)
        savedOutfits = []
        wornOutfits = []
        wornDay = nil
    }

    func generateIfNeeded(items: [OutfitPiece], recentWear: [RecentWear], city: String = "", today: String = CalendarMath.iso(.now)) {
        guard outfits.isEmpty, !items.isEmpty else { return }
        generate(items: items, recentWear: recentWear, city: city, today: today)
    }

    func markSaved(_ outfit: GeneratedOutfit) { savedOutfits.insert(outfit.id) }

    func isSaved(_ outfit: GeneratedOutfit) -> Bool { savedOutfits.contains(outfit.id) }

    /// La conferma sta nel tasto: quello in cima alla pagina, scorrendo, non si vede.
    func markWorn(_ outfit: GeneratedOutfit, day: String) {
        wornOutfits.insert(outfit.id)
        wornDay = day
    }

    func isWorn(_ outfit: GeneratedOutfit) -> Bool { wornOutfits.contains(outfit.id) }
}
