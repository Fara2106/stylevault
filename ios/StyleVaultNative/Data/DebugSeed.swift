#if DEBUG
import Foundation
import StyleVaultCore
import SwiftData
import UIKit

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

    /// Il cappotto con una foto su fondo grigio e il suo scontorno, solo con `-SVSeedCutout`:
    /// nel simulatore Vision non gira, e senza questo lo scontorno non si vede mai.
    static func fillCutout(_ context: ModelContext) {
        guard let coat = try? context.fetch(FetchDescriptor<Item>()).first(where: { $0.name == "Cappotto" }) else { return }
        let size = CGSize(width: 600, height: 800)
        let shape = UIBezierPath(roundedRect: CGRect(x: 150, y: 120, width: 300, height: 560), cornerRadius: 60)
        func draw(background: UIColor?) -> UIImage {
            let format = UIGraphicsImageRendererFormat()
            format.opaque = background != nil
            return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
                if let background {
                    background.setFill()
                    renderer.fill(CGRect(origin: .zero, size: size))
                }
                UIColor.black.setFill()
                shape.fill()
            }
        }
        coat.photoFront = draw(background: .systemGray).jpegData(compressionQuality: 0.8)
        coat.cutout = draw(background: nil).pngData()
        try? context.save()
    }

    /// Una foto finta, solo con `-SVSeedBodyPhoto`.
    static func fillBodyPhoto(_ context: ModelContext) {
        let size = CGSize(width: 300, height: 600)
        let image = UIGraphicsImageRenderer(size: size).image { renderer in
            UIColor.systemTeal.setFill()
            renderer.fill(CGRect(origin: .zero, size: size))
        }
        if let jpeg = image.jpegData(compressionQuality: 0.8) { try? BodyPhotoStore.save(jpeg, view: .front, in: context) }
    }
}
#endif
