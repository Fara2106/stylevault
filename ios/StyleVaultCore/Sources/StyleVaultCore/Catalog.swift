import Foundation

public struct Subcategory: Equatable, Sendable {
    public let id: String
    public let labelKey: String

    public init(id: String, labelKey: String) {
        self.id = id
        self.labelKey = labelKey
    }
}

public struct WardrobeCategory: Identifiable, Equatable, Sendable {
    public let id: String
    public let icon: String
    public let labelKey: String
    public let subcategories: [Subcategory]

    public init(id: String, icon: String, labelKey: String, subcategories: [Subcategory]) {
        self.id = id
        self.icon = icon
        self.labelKey = labelKey
        self.subcategories = subcategories
    }
}

public struct ChoiceOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let labelKey: String
    public let icon: String

    public init(id: String, labelKey: String, icon: String) {
        self.id = id
        self.labelKey = labelKey
        self.icon = icon
    }
}

public struct ClothingColor: Identifiable, Equatable, Sendable {
    public let id: String
    public let hex: String
    public let labelKey: String

    public init(id: String, hex: String, labelKey: String) {
        self.id = id
        self.hex = hex
        self.labelKey = labelKey
    }
}

/// Catalogo del guardaroba.
public enum Catalog {
    public static let categories: [WardrobeCategory] = [
        WardrobeCategory(id: "tops", icon: "👕", labelKey: "categories.tops", subcategories: [
            Subcategory(id: "tshirt", labelKey: "subcategories.tshirt"),
            Subcategory(id: "shirt", labelKey: "subcategories.shirt"),
            Subcategory(id: "hoodie", labelKey: "subcategories.hoodie"),
            Subcategory(id: "sweater", labelKey: "subcategories.sweater"),
            Subcategory(id: "tank", labelKey: "subcategories.tank"),
            Subcategory(id: "polo", labelKey: "subcategories.polo"),
            Subcategory(id: "croptop", labelKey: "subcategories.croptop"),
            Subcategory(id: "blouse", labelKey: "subcategories.blouse"),
        ]),
        WardrobeCategory(id: "bottoms", icon: "👖", labelKey: "categories.bottoms", subcategories: [
            Subcategory(id: "jeans", labelKey: "subcategories.jeans"),
            Subcategory(id: "trousers", labelKey: "subcategories.trousers"),
            Subcategory(id: "shorts", labelKey: "subcategories.shorts"),
            Subcategory(id: "skirt", labelKey: "subcategories.skirt"),
            Subcategory(id: "joggers", labelKey: "subcategories.joggers"),
            Subcategory(id: "leggings", labelKey: "subcategories.leggings"),
            Subcategory(id: "dresspants", labelKey: "subcategories.dressparts"),
        ]),
        WardrobeCategory(id: "outerwear", icon: "🧥", labelKey: "categories.outerwear", subcategories: [
            Subcategory(id: "jacket", labelKey: "subcategories.jacket"),
            Subcategory(id: "coat", labelKey: "subcategories.coat"),
            Subcategory(id: "puffer", labelKey: "subcategories.puffer"),
            Subcategory(id: "blazer", labelKey: "subcategories.blazer"),
            Subcategory(id: "trench", labelKey: "subcategories.trench"),
            Subcategory(id: "vest", labelKey: "subcategories.vest"),
            Subcategory(id: "raincoat", labelKey: "subcategories.raincoat"),
            Subcategory(id: "cardigan", labelKey: "subcategories.cardigan"),
        ]),
        WardrobeCategory(id: "dresses", icon: "👗", labelKey: "categories.dresses", subcategories: [
            Subcategory(id: "shortdress", labelKey: "subcategories.shortdress"),
            Subcategory(id: "longdress", labelKey: "subcategories.longdress"),
            Subcategory(id: "jumpsuit", labelKey: "subcategories.jumpsuit"),
            Subcategory(id: "eveningdress", labelKey: "subcategories.eveningdress"),
        ]),
        WardrobeCategory(id: "shoes", icon: "👟", labelKey: "categories.shoes", subcategories: [
            Subcategory(id: "sneakers", labelKey: "subcategories.sneakers"),
            Subcategory(id: "boots", labelKey: "subcategories.boots"),
            Subcategory(id: "loafers", labelKey: "subcategories.loafers"),
            Subcategory(id: "sandals", labelKey: "subcategories.sandals"),
            Subcategory(id: "heels", labelKey: "subcategories.heels"),
            Subcategory(id: "ankleboots", labelKey: "subcategories.ankleboots"),
            Subcategory(id: "pumps", labelKey: "subcategories.pumps"),
        ]),
        WardrobeCategory(id: "accessories", icon: "🧢", labelKey: "categories.accessories", subcategories: [
            Subcategory(id: "hat", labelKey: "subcategories.hat"),
            Subcategory(id: "scarf", labelKey: "subcategories.scarf"),
            Subcategory(id: "belt", labelKey: "subcategories.belt"),
            Subcategory(id: "bag", labelKey: "subcategories.bag"),
            Subcategory(id: "sunglasses", labelKey: "subcategories.sunglasses"),
            Subcategory(id: "jewelry", labelKey: "subcategories.jewelry"),
            Subcategory(id: "watch", labelKey: "subcategories.watch"),
            Subcategory(id: "umbrella", labelKey: "subcategories.umbrella"),
        ]),
        WardrobeCategory(id: "underwear", icon: "🩲", labelKey: "categories.underwear", subcategories: [
            Subcategory(id: "underwear_item", labelKey: "subcategories.underwear_item"),
            Subcategory(id: "socks", labelKey: "subcategories.socks"),
            Subcategory(id: "pajamas", labelKey: "subcategories.pajamas"),
        ]),
    ]

    public static let seasons: [ChoiceOption] = [
        ChoiceOption(id: "spring", labelKey: "seasons.spring", icon: "🌸"),
        ChoiceOption(id: "summer", labelKey: "seasons.summer", icon: "☀️"),
        ChoiceOption(id: "autumn", labelKey: "seasons.autumn", icon: "🍂"),
        ChoiceOption(id: "winter", labelKey: "seasons.winter", icon: "❄️"),
        ChoiceOption(id: "all", labelKey: "seasons.all", icon: "🔄"),
    ]

    public static let occasions: [ChoiceOption] = [
        ChoiceOption(id: "casual", labelKey: "occasions.casual", icon: "😎"),
        ChoiceOption(id: "formal", labelKey: "occasions.formal", icon: "👔"),
        ChoiceOption(id: "sport", labelKey: "occasions.sport", icon: "🏃"),
        ChoiceOption(id: "evening", labelKey: "occasions.evening", icon: "🌙"),
        ChoiceOption(id: "business", labelKey: "occasions.business", icon: "💼"),
    ]

    public static let colors: [ClothingColor] = [
        ClothingColor(id: "black", hex: "#1A1A1A", labelKey: "colors.black"),
        ClothingColor(id: "white", hex: "#FFFFFF", labelKey: "colors.white"),
        ClothingColor(id: "gray", hex: "#9E9E9E", labelKey: "colors.gray"),
        ClothingColor(id: "navy", hex: "#1B2A4A", labelKey: "colors.navy"),
        ClothingColor(id: "blue", hex: "#4A90D9", labelKey: "colors.blue"),
        ClothingColor(id: "lightblue", hex: "#87CEEB", labelKey: "colors.lightblue"),
        ClothingColor(id: "red", hex: "#C0392B", labelKey: "colors.red"),
        ClothingColor(id: "burgundy", hex: "#722F37", labelKey: "colors.burgundy"),
        ClothingColor(id: "pink", hex: "#E8A0B4", labelKey: "colors.pink"),
        ClothingColor(id: "green", hex: "#4A7C59", labelKey: "colors.green"),
        ClothingColor(id: "olive", hex: "#808000", labelKey: "colors.olive"),
        ClothingColor(id: "brown", hex: "#8B4513", labelKey: "colors.brown"),
        ClothingColor(id: "tan", hex: "#D2B48C", labelKey: "colors.tan"),
        ClothingColor(id: "beige", hex: "#F5F0E1", labelKey: "colors.beige"),
        ClothingColor(id: "cream", hex: "#FFFDD0", labelKey: "colors.cream"),
        ClothingColor(id: "yellow", hex: "#F4D03F", labelKey: "colors.yellow"),
        ClothingColor(id: "orange", hex: "#E67E22", labelKey: "colors.orange"),
        ClothingColor(id: "purple", hex: "#7D3C98", labelKey: "colors.purple"),
        ClothingColor(id: "lavender", hex: "#B8A9C9", labelKey: "colors.lavender"),
        ClothingColor(id: "coral", hex: "#FF7F7F", labelKey: "colors.coral"),
        ClothingColor(id: "gold", hex: "#C4A882", labelKey: "colors.gold"),
        ClothingColor(id: "silver", hex: "#C0C0C0", labelKey: "colors.silver"),
        ClothingColor(id: "denim", hex: "#5B7FA5", labelKey: "colors.denim"),
        ClothingColor(id: "khaki", hex: "#BDB76B", labelKey: "colors.khaki"),
    ]

    public static func category(id: String) -> WardrobeCategory? {
        categories.first { $0.id == id }
    }

    public static func color(id: String) -> ClothingColor? {
        colors.first { $0.id == id }
    }
}
