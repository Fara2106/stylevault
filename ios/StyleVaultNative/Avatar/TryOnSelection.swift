import Foundation
import StyleVaultCore

/// I capi da vedere addosso, da qualsiasi punto arrivino: outfit, Calendario o dettaglio.
struct TryOnSelection: Identifiable {
    let id = UUID()
    let pieces: [(slot: String, item: Item)]
    /// Per il Prompt AI contano tutti i capi, anche quelli che addosso non si vedono.
    let all: [Item]

    @MainActor static func from(_ outfit: GeneratedOutfit, items: [String: Item]) -> TryOnSelection {
        let pieces = outfit.avatarPieces.compactMap { slot, piece in items[piece.id].map { (slot: slot, item: $0) } }
        let accessories = outfit.accessories.compactMap { items[$0.id] }
        return TryOnSelection(pieces: pieces, all: pieces.map(\.item) + accessories)
    }

    /// Un posto, un capo: fra due capi per lo stesso posto resta il primo.
    @MainActor static func from(_ items: [Item]) -> TryOnSelection {
        var used = Set<String>()
        let pieces = items.compactMap { item -> (slot: String, item: Item)? in
            guard let slot = AvatarSlots.slot(category: item.category), used.insert(slot).inserted else { return nil }
            return (slot, item)
        }
        return TryOnSelection(pieces: pieces, all: items)
    }

    var promptGarments: [PromptGarment] {
        all.map { PromptGarment(name: $0.name, category: $0.category, subcategory: $0.subcategory, colors: $0.colors) }
    }
}
