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

public enum CitySearch {
    public static let minimumLength = 2
}
