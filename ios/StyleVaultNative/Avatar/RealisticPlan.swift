import CoreGraphics
import FashnKit
import Foundation
import StyleVaultCore

/// Cosa la versione realistica può mettere addosso, dato un insieme di capi.
/// Il modello veste un sopra, un sotto o un capo intero: capospalla e scarpe restano fuori, intimo e costumi non si generano.
struct RealisticPlan: Equatable {
    struct Piece: Equatable, Sendable {
        let slot: String
        let name: String
        let photo: Data
        /// La stessa chiave dell'avatar a collage: lo scontorno del capo è già in cache.
        let key: String
        let category: GarmentCategory
    }

    /// I capi da generare, nell'ordine in cui si mettono.
    let pieces: [Piece]
    /// I nomi dei capi che nell'immagine non compaiono.
    let leftOut: [String]
    /// Un costume porterebbe a un'immagine intima: non si genera.
    let hasSwimwear: Bool

    var canGenerate: Bool { !pieces.isEmpty && !hasSwimwear }

    static func category(slot: String) -> GarmentCategory? {
        switch slot {
        case "top": return .tops
        case "bottom": return .bottoms
        case "dress": return .onePieces
        default: return nil
        }
    }

    @MainActor static func make(_ selection: TryOnSelection) -> RealisticPlan {
        var bySlot: [String: Item] = [:]
        for (slot, item) in selection.pieces where bySlot[slot] == nil { bySlot[slot] = item }
        // Un vestito copre sopra e sotto: con un vestito gli altri due restano fuori
        let order = bySlot["dress"] != nil ? ["dress"] : ["top", "bottom"]
        var pieces: [Piece] = []
        var leftOut: [String] = []
        for (slot, item) in selection.pieces {
            guard order.contains(slot), bySlot[slot] === item, let category = category(slot: slot), let photo = item.photoFront else {
                leftOut.append(item.name)
                continue
            }
            pieces.append(Piece(slot: slot, name: item.name, photo: photo,
                                key: "item-\(item.id.uuidString)-front-\(photo.count)", category: category))
        }
        pieces.sort { (order.firstIndex(of: $0.slot) ?? 0) < (order.firstIndex(of: $1.slot) ?? 0) }
        return RealisticPlan(pieces: pieces, leftOut: leftOut, hasSwimwear: TryOnPrompt.hasSwimwear(selection.promptGarments))
    }
}
