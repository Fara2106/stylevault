import Foundation
import StyleVaultCore
import SwiftData

extension Item {
    /// Il capo come lo vede l'algoritmo.
    var piece: OutfitPiece {
        OutfitPiece(id: id.uuidString, category: category, subcategory: subcategory, colors: colors, season: season,
                    occasion: occasion, warmthLevel: warmthLevel, price: price)
    }
}

extension CalendarEntry {
    var wearLog: WearLog { WearLog(date: day, worn: worn, itemIDs: itemIDs.map(\.uuidString)) }
    var repeatLog: RepeatLog { RepeatLog(id: id.uuidString, date: day, itemIDs: itemIDs.map(\.uuidString)) }
}

/// Tutte le scritture su outfit salvati e calendario passano da qui, e ognuna salva prima di tornare.
@MainActor enum OutfitStore {
    @discardableResult
    static func save(itemIDs: [UUID], occasion: String?, score: Int?, in context: ModelContext) throws -> Outfit {
        let outfit = Outfit()
        outfit.itemIDs = itemIDs
        outfit.occasion = occasion == "all" ? nil : occasion
        outfit.score = score
        context.insert(outfit)
        try context.save()
        return outfit
    }

    /// Il calendario tiene i suoi capi: cancellare l'outfit salvato non cambia lo storico.
    static func delete(_ outfit: Outfit, in context: ModelContext) throws {
        context.delete(outfit)
        try context.save()
    }

    /// Un giorno passato o di oggi è indossato, uno futuro è pianificato.
    @discardableResult
    static func log(itemIDs: [UUID], outfitID: UUID?, day: String, today: String, in context: ModelContext) throws -> CalendarEntry {
        let entry = CalendarEntry()
        entry.day = day
        entry.worn = day <= today
        entry.outfitID = outfitID
        entry.itemIDs = itemIDs
        context.insert(entry)
        try context.save()
        return entry
    }

    static func markWorn(_ entry: CalendarEntry, in context: ModelContext) throws {
        entry.worn = true
        try context.save()
    }

    static func remove(_ entry: CalendarEntry, in context: ModelContext) throws {
        context.delete(entry)
        try context.save()
    }

    /// Per la penalità di ripetizione e il consiglio "già indossato".
    static func recentWear(from entries: [CalendarEntry]) -> [RecentWear] {
        entries.filter(\.worn).flatMap { entry in
            entry.itemIDs.map { RecentWear(itemID: $0.uuidString, date: entry.day) }
        }
    }
}
