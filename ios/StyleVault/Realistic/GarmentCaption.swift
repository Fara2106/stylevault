import Foundation

/// Didascalie che Mobile-VTON si aspetta (copiate da tools/avatar-realistico/common.py).
enum GarmentCaption {
    /// Negativo fisso, uguale a `common.NEGATIVE`.
    static let negative = "deformed, distorted, disfigured, poorly drawn, bad anatomy, wrong anatomy, extra limb, missing limb, floating limbs, mutated hands and fingers, disconnected limbs, mutation, mutated, ugly, disgusting, blurry, amputation, NSFW"

    /// "The item is a <descrittore>."
    static func cloth(_ item: AvatarItem) -> String {
        "The item is a \(descriptor(item))."
    }

    /// "Replace the upper body with item is a <descrittore>." (la didascalia
    /// del capo senza la prima parola, come in common.py).
    static func person(_ item: AvatarItem) -> String {
        "Replace the upper body with " + cloth(item).split(separator: " ", maxSplits: 1)[1]
    }

    private static func descriptor(_ item: AvatarItem) -> String {
        for candidate in [item.descriptor, item.name] {
            if let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return text
            }
        }
        return "garment"
    }
}
