import Foundation

public enum ExportError: Error, Equatable {
    case notAnExport, newerVersion
}

/// Capo o desiderio. Le foto sono percorsi dentro lo zip.
public struct ExportGarment: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: String
    public var subcategory: String?
    public var brand: String?
    public var size: String?
    public var colors: [String]
    public var season: String
    public var occasion: String
    public var warmthLevel: Int
    public var sourceURL: String?
    public var price: Double?
    public var favorite: Bool?
    public var createdAt: Date
    public var photoFront: String?
    public var photoBack: String?
    public var cutout: String?

    public init(id: String, name: String, category: String, subcategory: String?, brand: String?, size: String?,
                colors: [String], season: String, occasion: String, warmthLevel: Int, sourceURL: String?, price: Double?,
                favorite: Bool?, createdAt: Date, photoFront: String?, photoBack: String?, cutout: String?) {
        self.id = id
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.brand = brand
        self.size = size
        self.colors = colors
        self.season = season
        self.occasion = occasion
        self.warmthLevel = warmthLevel
        self.sourceURL = sourceURL
        self.price = price
        self.favorite = favorite
        self.createdAt = createdAt
        self.photoFront = photoFront
        self.photoBack = photoBack
        self.cutout = cutout
    }
}

public struct ExportCategory: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var createdAt: Date

    public init(id: String, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct ExportOutfit: Codable, Equatable, Sendable {
    public var id: String
    public var occasion: String?
    public var score: Int?
    public var itemIDs: [String]
    public var createdAt: Date

    public init(id: String, occasion: String?, score: Int?, itemIDs: [String], createdAt: Date) {
        self.id = id
        self.occasion = occasion
        self.score = score
        self.itemIDs = itemIDs
        self.createdAt = createdAt
    }
}

/// Il ricordo di un capo indossato: resta nello storico anche quando il capo viene cancellato.
public struct WornItem: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: String

    public init(id: String, name: String, category: String) {
        self.id = id
        self.name = name
        self.category = category
    }
}

public struct ExportCalendarEntry: Codable, Equatable, Sendable {
    public var id: String
    public var day: String
    public var worn: Bool
    public var outfitID: String?
    public var itemIDs: [String]
    public var createdAt: Date
    /// Assente nei file vecchi.
    public var snapshot: [WornItem]?

    public init(id: String, day: String, worn: Bool, outfitID: String?, itemIDs: [String], createdAt: Date,
                snapshot: [WornItem]? = nil) {
        self.snapshot = snapshot
        self.id = id
        self.day = day
        self.worn = worn
        self.outfitID = outfitID
        self.itemIDs = itemIDs
        self.createdAt = createdAt
    }
}

public struct ExportProfile: Codable, Equatable, Sendable {
    public var theme: String
    public var cityName: String
    public var cityLatitude: Double
    public var cityLongitude: Double
    public var cityCountry: String?
    /// Il verdetto dell'Armocromia in JSON, come sta nel Profilo.
    public var armocromia: String?

    public init(theme: String, cityName: String, cityLatitude: Double, cityLongitude: Double,
                cityCountry: String?, armocromia: String?) {
        self.theme = theme
        self.cityName = cityName
        self.cityLatitude = cityLatitude
        self.cityLongitude = cityLongitude
        self.cityCountry = cityCountry
        self.armocromia = armocromia
    }
}

public struct ExportBodyPhoto: Codable, Equatable, Sendable {
    public var kind: String
    public var file: String

    public init(kind: String, file: String) {
        self.kind = kind
        self.file = file
    }
}

/// Il contenuto di `stylevault-export.json`, il documento dentro lo zip.
public struct ExportBundle: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var profile: ExportProfile?
    public var items: [ExportGarment]
    public var wishlist: [ExportGarment]
    public var customCategories: [ExportCategory]
    public var outfits: [ExportOutfit]
    public var calendar: [ExportCalendarEntry]
    public var bodyPhotos: [ExportBodyPhoto]

    public init(exportedAt: Date = .now) {
        version = Self.currentVersion
        self.exportedAt = exportedAt
        profile = nil
        items = []
        wishlist = []
        customCategories = []
        outfits = []
        calendar = []
        bodyPhotos = []
    }

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, profile, items, wishlist, customCategories, outfits, calendar, bodyPhotos
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        guard version <= Self.currentVersion else { throw ExportError.newerVersion }
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        profile = try c.decodeIfPresent(ExportProfile.self, forKey: .profile)
        items = try c.decodeIfPresent([ExportGarment].self, forKey: .items) ?? []
        wishlist = try c.decodeIfPresent([ExportGarment].self, forKey: .wishlist) ?? []
        customCategories = try c.decodeIfPresent([ExportCategory].self, forKey: .customCategories) ?? []
        outfits = try c.decodeIfPresent([ExportOutfit].self, forKey: .outfits) ?? []
        calendar = try c.decodeIfPresent([ExportCalendarEntry].self, forKey: .calendar) ?? []
        bodyPhotos = try c.decodeIfPresent([ExportBodyPhoto].self, forKey: .bodyPhotos) ?? []
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> ExportBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = parse(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: text))
            }
            return date
        }
        return try decoder.decode(ExportBundle.self, from: data)
    }

    /// Con o senza millesimi: lo script da Supabase li scrive, l'app no.
    private static func parse(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

/// Il file che si esporta: `stylevault-export.json` più la cartella `photos/`.
public enum ExportArchive {
    public static let documentName = "stylevault-export.json"

    public struct Contents {
        public let bundle: ExportBundle
        private let reader: ZipReader

        init(bundle: ExportBundle, reader: ZipReader) {
            self.bundle = bundle
            self.reader = reader
        }

        public func photo(_ name: String?) throws -> Data? {
            guard let name else { return nil }
            return try reader.data(name: name, limit: GarmentImage.importedMaxBytes)
        }
    }

    public static func write(_ bundle: ExportBundle, photos: [String: Data], to url: URL) throws {
        let writer = try ZipWriter(url: url)
        try writer.add(name: documentName, data: bundle.encoded())
        for (name, data) in photos.sorted(by: { $0.key < $1.key }) {
            try writer.add(name: name, data: data)
        }
        try writer.close()
    }

    public static func read(_ url: URL) throws -> Contents {
        let reader: ZipReader
        do { reader = try ZipReader(url: url) } catch { throw ExportError.notAnExport }
        guard let document = try reader.data(name: documentName) else { throw ExportError.notAnExport }
        return Contents(bundle: try ExportBundle.decode(document), reader: reader)
    }

    public static func fileName(date: Date = .now, calendar: Calendar = CalendarMath.local) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "StyleVault-%04d-%02d-%02d.zip", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
