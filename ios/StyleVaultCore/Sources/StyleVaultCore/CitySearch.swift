import Foundation

/// Una città trovata dalla ricerca.
public struct City: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let country: String?
    public let region: String?

    public init(id: Int, name: String, latitude: Double, longitude: Double,
                country: String? = nil, region: String? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.region = region
    }
}

/// Ricerca della città con il geocoding di Open-Meteo. Manda solo il testo cercato.
public enum CitySearch {
    public static let minimumLength = 2

    public struct HTTPError: Error, Equatable, Sendable {
        public let statusCode: Int
    }

    public static func url(query: String, language: String) -> URL? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "format", value: "json"),
        ]
        // queryItems lascia passare "&", "+" e "?" nei valori: li codifichiamo noi.
        if let items = components?.queryItems {
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&+=?#")
            components?.percentEncodedQuery = items.map { item in
                let value = item.value?.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
                return "\(item.name)=\(value)"
            }.joined(separator: "&")
        }
        return components?.url
    }

    public static func parse(_ data: Data) throws -> [City] {
        struct Response: Decodable {
            struct Result: Decodable {
                let id: Int
                let name: String
                let latitude: Double
                let longitude: Double
                let country: String?
                let admin1: String?
            }
            let results: [Result]?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return (response.results ?? []).map {
            City(id: $0.id, name: $0.name, latitude: $0.latitude, longitude: $0.longitude,
                 country: $0.country, region: $0.admin1)
        }
    }

    public static func search(_ query: String, language: String,
                              session: URLSession = .shared) async throws -> [City] {
        guard let url = url(query: query, language: language) else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HTTPError(statusCode: http.statusCode)
        }
        return try parse(data)
    }
}
