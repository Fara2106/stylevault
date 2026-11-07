import MapKit
import StyleVaultCore

/// Ricerca della città con le Mappe di Apple. Manda solo il testo cercato.
/// I suggerimenti portano le città con lo stesso nome; `MKLocalSearch` da solo ne darebbe una.
enum AppleCitySearch {
    private static let limit = 6

    @MainActor static func search(_ query: String) async throws -> [City] {
        let completions = try await Suggestions().fetch(query).prefix(limit)
        let cities = await withTaskGroup(of: (Int, City?).self) { group in
            for (index, completion) in completions.enumerated() {
                group.addTask { @MainActor in (index, await city(for: completion)) }
            }
            var found: [(Int, City?)] = []
            for await result in group { found.append(result) }
            return found.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
        return unique(cities)
    }

    @MainActor private static func city(for completion: MKLocalSearchCompletion) async -> City? {
        guard let item = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start().mapItems.first
        else { return nil }
        let place = item.placemark
        return City(id: 0, name: place.locality ?? item.name ?? completion.title,
                    latitude: place.coordinate.latitude, longitude: place.coordinate.longitude,
                    country: place.country, region: place.administrativeArea)
    }

    /// MapKit può dare più volte lo stesso posto e non ha un identificativo numerico.
    static func unique(_ cities: [City]) -> [City] {
        var seen = Set<String>()
        let distinct = cities.filter { seen.insert("\($0.name)|\($0.region ?? "")|\($0.country ?? "")").inserted }
        return distinct.prefix(limit).enumerated().map { index, city in
            City(id: index, name: city.name, latitude: city.latitude, longitude: city.longitude,
                 country: city.country, region: city.region)
        }
    }
}

/// `MKLocalSearchCompleter` risponde con un delegato: qui diventa una chiamata sola.
@MainActor private final class Suggestions: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var waiting: CheckedContinuation<[MKLocalSearchCompletion], Error>?

    func fetch(_ query: String) async throws -> [MKLocalSearchCompletion] {
        completer.delegate = self
        completer.resultTypes = .address
        if #available(iOS 18.0, *) { completer.addressFilter = MKAddressFilter(including: .locality) }
        return try await withCheckedThrowingContinuation { continuation in
            waiting = continuation
            completer.queryFragment = query
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            waiting?.resume(returning: completer.results)
            waiting = nil
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            waiting?.resume(throwing: error)
            waiting = nil
        }
    }
}
