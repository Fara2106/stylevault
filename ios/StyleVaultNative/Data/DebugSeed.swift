#if DEBUG
import Foundation
import SwiftData

/// Per i test UI: un guardaroba già pronto, solo con `-SVSeedWardrobe`. Non arriva nella Release.
@MainActor enum DebugSeed {
    static func fill(_ context: ModelContext) {
        let wardrobe: [(String, String, String, [String], Double?)] = [
            ("Maglione blu", "tops", "sweater", ["navy"], 60),
            ("Camicia bianca", "tops", "shirt", ["white"], nil),
            ("Jeans", "bottoms", "jeans", ["denim"], 90),
            ("Sneakers", "shoes", "sneakers", ["white"], 120),
            ("Cappotto", "outerwear", "coat", ["black"], 200),
        ]
        for (name, category, subcategory, colors, price) in wardrobe {
            var values = ItemValues()
            values.name = name
            values.category = category
            values.subcategory = subcategory
            values.colors = colors
            values.warmthLevel = 3
            values.price = price
            _ = try? WardrobeStore.addItem(values, in: context)
        }
    }
}
#endif
