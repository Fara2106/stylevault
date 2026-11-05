import Foundation
import SwiftData

/// Tutte le scritture su capi e wishlist passano da qui, e ognuna salva prima di tornare.
@MainActor enum WardrobeStore {
    @discardableResult
    static func addItem(_ values: ItemValues, in context: ModelContext) throws -> Item {
        let item = Item()
        item.apply(values)
        context.insert(item)
        try context.save()
        return item
    }

    @discardableResult
    static func addWish(_ values: ItemValues, in context: ModelContext) throws -> WishlistItem {
        let wish = WishlistItem()
        wish.apply(values)
        context.insert(wish)
        try context.save()
        return wish
    }

    /// `true` se la foto davanti è cambiata: lo scontorno è stato azzerato e va rifatto.
    @discardableResult
    static func update(_ item: Item, with values: ItemValues, in context: ModelContext) throws -> Bool {
        let photoChanged = item.photoFront != values.photoFront
        item.apply(values)
        if photoChanged { item.cutout = nil }
        try context.save()
        return photoChanged
    }

    static func delete(_ item: Item, in context: ModelContext) throws {
        context.delete(item)
        try context.save()
    }

    static func delete(_ wish: WishlistItem, in context: ModelContext) throws {
        context.delete(wish)
        try context.save()
    }

    static func toggleFavorite(_ item: Item, in context: ModelContext) throws {
        item.favorite.toggle()
        try context.save()
    }

    /// Crea il capo e toglie il desiderio nello stesso salvataggio: un errore non perde nulla.
    @discardableResult
    static func moveToWardrobe(_ wish: WishlistItem, in context: ModelContext) throws -> Item {
        let item = Item()
        item.apply(wish.values)
        context.insert(item)
        context.delete(wish)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return item
    }
}
