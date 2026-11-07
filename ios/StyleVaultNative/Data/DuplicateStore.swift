import Foundation
import OSLog
import SwiftData

/// CloudKit non ha vincoli `unique`: lo stesso file importato su due dispositivi dà due record con lo stesso id.
///
/// Si tiene la copia con lo `stamp` più alto, così ogni dispositivo sceglie la stessa e nessuno cancella quella
/// che l'altro ha tenuto. Copie senza `stamp`, o con lo stesso, restano entrambe: un doppione si vede e si
/// cancella a mano, un capo perso non torna.
@MainActor enum DuplicateStore {
    private static let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "duplicates")

    @discardableResult
    static func clean(in context: ModelContext) throws -> Int {
        var removed = try merge(Item.self, key: \.id, stamp: \.stamp, in: context) { keeper, copy in
            keeper.photoFront = keeper.photoFront ?? copy.photoFront
            keeper.photoBack = keeper.photoBack ?? copy.photoBack
            keeper.cutout = keeper.cutout ?? copy.cutout
            keeper.favorite = keeper.favorite || copy.favorite
        }
        removed += try merge(WishlistItem.self, key: \.id, stamp: \.stamp, in: context) { keeper, copy in
            keeper.photoFront = keeper.photoFront ?? copy.photoFront
            keeper.photoBack = keeper.photoBack ?? copy.photoBack
        }
        removed += try merge(CustomCategory.self, key: \.id, stamp: \.stamp, in: context) { _, _ in }
        removed += try merge(Outfit.self, key: \.id, stamp: \.stamp, in: context) { _, _ in }
        removed += try merge(CalendarEntry.self, key: \.id, stamp: \.stamp, in: context) { keeper, copy in
            keeper.worn = keeper.worn || copy.worn
            keeper.snapshot = keeper.snapshot ?? copy.snapshot
        }
        if removed > 0 {
            try context.save()
            logger.info("Tolti \(removed) doppioni")
        }
        return removed
    }

    private static func merge<Model: PersistentModel, Key: Hashable>(
        _ type: Model.Type, key: (Model) -> Key, stamp: (Model) -> UUID?, in context: ModelContext,
        absorb: (Model, Model) -> Void
    ) throws -> Int {
        var removed = 0
        for copies in Dictionary(grouping: try context.fetch(FetchDescriptor<Model>()), by: key).values where copies.count > 1 {
            let stamped = copies.compactMap { copy in stamp(copy).map { (copy, $0.uuidString) } }
            guard let highest = stamped.map(\.1).max(),
                  stamped.filter({ $0.1 == highest }).count == 1,
                  let keeper = stamped.first(where: { $0.1 == highest })?.0 else { continue }
            for copy in copies where copy.persistentModelID != keeper.persistentModelID {
                absorb(keeper, copy)
                context.delete(copy)
                removed += 1
            }
        }
        return removed
    }
}
