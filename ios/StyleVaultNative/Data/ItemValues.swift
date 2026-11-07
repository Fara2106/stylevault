import Foundation

/// I valori puliti di un capo, già validati dal modulo.
struct ItemValues: Equatable {
    var name = ""
    var category = ""
    var subcategory: String?
    var brand: String?
    var size: String?
    var colors: [String] = []
    var season = "all"
    var occasion = "casual"
    var warmthLevel = 2
    var sourceURL: String?
    var price: Double?
    var photoFront: Data?
    var photoBack: Data?
}

extension Item {
    /// CloudKit non ha vincoli `unique`: due record possono avere lo stesso id e qui non deve costare un crash.
    static func byID(_ items: [Item]) -> [String: Item] {
        Dictionary(items.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func apply(_ values: ItemValues) {
        name = values.name
        category = values.category
        subcategory = values.subcategory
        brand = values.brand
        size = values.size
        colors = values.colors
        season = values.season
        occasion = values.occasion
        warmthLevel = values.warmthLevel
        sourceURL = values.sourceURL
        price = values.price
        photoFront = values.photoFront
        photoBack = values.photoBack
    }

    var values: ItemValues {
        ItemValues(name: name, category: category, subcategory: subcategory, brand: brand, size: size,
                   colors: colors, season: season, occasion: occasion, warmthLevel: warmthLevel,
                   sourceURL: sourceURL, price: price, photoFront: photoFront, photoBack: photoBack)
    }
}

extension WishlistItem {
    func apply(_ values: ItemValues) {
        name = values.name
        category = values.category
        subcategory = values.subcategory
        brand = values.brand
        size = values.size
        colors = values.colors
        season = values.season
        occasion = values.occasion
        warmthLevel = values.warmthLevel
        sourceURL = values.sourceURL
        price = values.price
        photoFront = values.photoFront
        photoBack = values.photoBack
    }

    var values: ItemValues {
        ItemValues(name: name, category: category, subcategory: subcategory, brand: brand, size: size,
                   colors: colors, season: season, occasion: occasion, warmthLevel: warmthLevel,
                   sourceURL: sourceURL, price: price, photoFront: photoFront, photoBack: photoBack)
    }
}
