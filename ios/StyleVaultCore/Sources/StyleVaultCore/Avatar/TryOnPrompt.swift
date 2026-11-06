import Foundation

public struct PromptGarment: Equatable, Sendable {
    public let name: String
    public let category: String
    public let subcategory: String?
    public let colors: [String]

    public init(name: String, category: String, subcategory: String?, colors: [String]) {
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.colors = colors
    }
}

/// Il prompt da incollare in ChatGPT o Gemini. È in inglese perché rende meglio con i modelli di immagini.
public enum TryOnPrompt {
    private static let colorWords = [
        "black": "black", "white": "white", "gray": "gray", "navy": "navy-blue", "blue": "blue",
        "lightblue": "light-blue", "red": "red", "burgundy": "burgundy", "pink": "pink",
        "green": "green", "olive": "olive-green", "brown": "brown", "tan": "tan", "beige": "beige",
        "cream": "cream", "yellow": "yellow", "orange": "orange", "purple": "purple",
        "lavender": "lavender", "coral": "coral", "gold": "gold", "silver": "silver",
        "denim": "denim-blue", "khaki": "khaki",
    ]

    private static let garmentWords = [
        "tshirt": "t-shirt", "shirt": "button-up shirt", "hoodie": "hoodie", "sweater": "sweater",
        "tank": "tank top", "polo": "polo shirt", "croptop": "crop top", "blouse": "blouse",
        "jeans": "jeans", "trousers": "trousers", "shorts": "shorts", "skirt": "skirt",
        "joggers": "joggers", "leggings": "leggings", "dresspants": "dress trousers",
        "jacket": "jacket", "coat": "coat", "puffer": "puffer jacket", "blazer": "blazer",
        "trench": "trench coat", "vest": "vest", "raincoat": "raincoat", "cardigan": "cardigan",
        "shortdress": "short dress", "longdress": "long dress", "jumpsuit": "jumpsuit",
        "eveningdress": "evening dress",
        "sneakers": "sneakers", "boots": "boots", "loafers": "loafers", "sandals": "sandals",
        "heels": "heels", "ankleboots": "ankle boots", "pumps": "pumps",
        "hat": "hat", "scarf": "scarf", "belt": "belt", "bag": "bag", "sunglasses": "sunglasses",
        "jewelry": "jewelry", "watch": "watch", "umbrella": "umbrella",
        "underwear_item": "underwear", "socks": "socks", "pajamas": "pajamas",
    ]

    private static let swimwearName =
        #"(?i)\b(costum[ei]|bikini|trikini|tankini|monokini|swimsuit|swimwear|swim trunks|da bagno)\b"#

    /// Un costume va provato su una foto in costume: sopra i vestiti non rende.
    public static func hasSwimwear(_ garments: [PromptGarment]) -> Bool {
        garments.contains { garment in
            !["shoes", "accessories"].contains(garment.category)
                && garment.name.range(of: swimwearName, options: .regularExpression) != nil
        }
    }

    static func descriptor(_ garment: PromptGarment) -> String {
        let fallback = garment.name.isEmpty ? "garment" : garment.name
        let noun = garment.subcategory.flatMap { garmentWords[$0] } ?? fallback
        guard let color = garment.colors.first.flatMap({ colorWords[$0] }) else { return noun }
        return "\(color) \(noun)"
    }

    public static func build(_ garments: [PromptGarment]) -> String {
        let lines = garments.enumerated().map { index, garment in
            "\(index + 1). \(descriptor(garment)) (Image \(index + 2))."
        }
        let dressing = lines.isEmpty
            ? "Dress this same person in the garments shown in the following images."
            : "Dress this same person in the garments shown in the next images:\n\(lines.joined(separator: "\n"))"
        return [
            "Photorealistic virtual try-on.",
            "",
            "Image 1 is a real person — preserve their exact face, hairstyle, skin tone, body shape, height, pose "
                + "and background with total fidelity. Do not change their identity in any way.",
            "",
            dressing,
            "",
            "The photos may be attached as separate images or combined into a single numbered contact sheet — "
                + "the numbers always identify the same person and garments.",
            "",
            "Replace ONLY the person's current clothing with these garments. Fit each item naturally with realistic "
                + "folds, seams and shadows, matching the lighting and perspective of Image 1. Full-body framing, head "
                + "to feet, sharp focus, natural light. Return only the final edited photograph, no text.",
        ].joined(separator: "\n")
    }
}
