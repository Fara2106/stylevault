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

extension CalendarEntry {
    var wornItems: [WornItem] {
        guard let snapshot, let items = try? JSONDecoder().decode([WornItem].self, from: snapshot) else { return [] }
        return items
    }

    func remember(_ item: Item) {
        let id = item.id.uuidString
        guard !wornItems.contains(where: { $0.id == id }) else { return }
        snapshot = try? JSONEncoder().encode(wornItems + [WornItem(id: id, name: item.name, category: item.category)])
    }

    /// I capi di questo giorno che ci sono ancora, nell'ordine in cui sono stati registrati.
    func present(in items: [Item]) -> [Item] {
        let known = Item.byID(items)
        // Lo stesso capo scritto due volte nello stesso giorno si mostra una volta
        var seen = Set<UUID>()
        return itemIDs.filter { seen.insert($0).inserted }.compactMap { known[$0.uuidString] }
    }

    /// I nomi dei capi cancellati, per quelli che si conoscono.
    func deletedNames(in items: [Item]) -> [String] {
        let known = Item.byID(items)
        return wornItems.filter { known[$0.id] == nil }.map(\.name)
    }

    func hasDeletedItems(in items: [Item]) -> Bool { present(in: items).count < itemIDs.count }
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
        let existing = try context.fetch(FetchDescriptor<CalendarEntry>(predicate: #Predicate { $0.day == day }))
        // Toccare due volte lo stesso outfit non deve raddoppiare il giorno.
        if let same = existing.first(where: { Set($0.itemIDs) == Set(itemIDs) }) { return same }
        let entry = CalendarEntry()
        entry.day = day
        entry.worn = day <= today
        entry.outfitID = outfitID
        entry.itemIDs = itemIDs
        context.insert(entry)
        try context.save()
        return entry
    }

    /// Un giorno che deve ancora arrivare non può essere già indossato.
    static func canMarkWorn(_ entry: CalendarEntry, today: String) -> Bool { !entry.worn && entry.day <= today }

    static func markWorn(_ entry: CalendarEntry, in context: ModelContext) throws {
        entry.worn = true
        try context.save()
    }

    static func remove(_ entry: CalendarEntry, in context: ModelContext) throws {
        context.delete(entry)
        try context.save()
    }

    /// Per la penalità di ripetizione e il consiglio "già indossato".
    /// `since`: i giorni prima non servono a chi chiede (i giorni si confrontano come testo) e non si preparano.
    static func recentWear(from entries: [CalendarEntry], since: String? = nil) -> [RecentWear] {
        entries.filter { entry in entry.worn && (since.map { entry.day >= $0 } ?? true) }.flatMap { entry in
            Set(entry.itemIDs).map { RecentWear(itemID: $0.uuidString, date: entry.day) }
        }
    }
}
