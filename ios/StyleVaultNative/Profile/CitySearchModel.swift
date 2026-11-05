import Foundation
import Observation
import StyleVaultCore

extension Profile {
    func apply(city: City) {
        cityName = city.name
        cityLatitude = city.latitude
        cityLongitude = city.longitude
        cityCountry = city.country
        updatedAt = .now
    }

    func setTheme(_ value: String) {
        theme = value
        updatedAt = .now
    }
}

/// Stato della ricerca città. Applica la lunghezza minima, non `CitySearch.search`.
@MainActor @Observable final class CitySearchModel {
    enum Phase: Equatable { case idle, searching, results([City]), empty }

    private(set) var phase: Phase = .idle
    private let search: (String) async throws -> [City]

    init(search: @escaping (String) async throws -> [City]) {
        self.search = search
    }

    func run(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= CitySearch.minimumLength else {
            phase = .idle
            return
        }
        phase = .searching
        do {
            let cities = try await search(trimmed)
            guard !Task.isCancelled else { return }
            phase = cities.isEmpty ? .empty : .results(cities)
        } catch is CancellationError {
            // Una ricerca più recente ha preso il posto di questa: la fase la decide lei.
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            // Rete assente o errore del servizio: per chi cerca è "nessuna città".
            phase = .empty
        }
    }
}
