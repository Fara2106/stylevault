import Foundation
import SwiftData

// Tutte le proprietà hanno un default o sono facoltative, senza `unique`:
// è il requisito di CloudKit per lo schema.

@Model final class Item {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = ""
    var subcategory: String?
    var brand: String?
    var size: String?
    var colors: [String] = []
    var season: String = "all"
    var occasion: String = "casual"
    var warmthLevel: Int = 2
    var sourceURL: String?
    var price: Double?
    var favorite: Bool = false
    var createdAt: Date = Date.now
    @Attribute(.externalStorage) var photoFront: Data?
    @Attribute(.externalStorage) var photoBack: Data?
    @Attribute(.externalStorage) var cutout: Data?

    init() {}
}

@Model final class WishlistItem {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = ""
    var subcategory: String?
    var brand: String?
    var size: String?
    var colors: [String] = []
    var season: String = "all"
    var occasion: String = "casual"
    var warmthLevel: Int = 2
    var sourceURL: String?
    var price: Double?
    var createdAt: Date = Date.now
    @Attribute(.externalStorage) var photoFront: Data?
    @Attribute(.externalStorage) var photoBack: Data?

    init() {}
}

@Model final class Outfit {
    var id: UUID = UUID()
    var occasion: String?
    var score: Int?
    var itemIDs: [UUID] = []
    var createdAt: Date = Date.now

    init() {}
}

@Model final class CalendarEntry {
    var id: UUID = UUID()
    /// Formato `yyyy-MM-dd`, stringa per non spostare la voce cambiando fuso.
    var day: String = ""
    var worn: Bool = true
    var outfitID: UUID?
    var itemIDs: [UUID] = []
    var createdAt: Date = Date.now

    init() {}
}

@Model final class Profile {
    var id: UUID = UUID()
    var theme: String = "system"
    var cityName: String = "Milano"
    var cityLatitude: Double = 45.4642
    var cityLongitude: Double = 9.19
    var cityCountry: String? = "Italia"
    var armocromia: Data?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}
}

@Model final class BodyPhoto {
    var id: UUID = UUID()
    /// `front`, `side` oppure `back`.
    var kind: String = "front"
    @Attribute(.externalStorage) var photo: Data?
    var updatedAt: Date = Date.now

    init() {}
}
