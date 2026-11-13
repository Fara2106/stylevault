import Foundation
import SwiftData

/// Le categorie create dalla persona. CloudKit non ha `unique`: due dispositivi possono crearne
/// una con lo stesso nome, e si vedono entrambe finché una non viene cancellata.
@MainActor enum CustomCategoryStore {
    /// Nome vuoto: `nil`. Nome già presente, anche con altre maiuscole: quella che c'è.
    @discardableResult
    static func add(name: String, in context: ModelContext) throws -> CustomCategory? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = try context.fetch(FetchDescriptor<CustomCategory>())
        if let same = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return same
        }
        let category = CustomCategory()
        category.id = "custom_\(UUID().uuidString)"
        category.name = trimmed
        context.insert(category)
        try context.save()
        return category
    }

    static func isUsed(_ category: CustomCategory, in context: ModelContext) throws -> Bool {
        let id = category.id
        let items = FetchDescriptor<Item>(predicate: #Predicate { $0.category == id })
        let wishes = FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.category == id })
        return try context.fetchCount(items) > 0 || context.fetchCount(wishes) > 0
    }

    /// Non cancella se un capo o un desiderio la usa: ritorna `false`.
    @discardableResult
    static func delete(_ category: CustomCategory, in context: ModelContext) throws -> Bool {
        guard try !isUsed(category, in: context) else { return false }
        context.delete(category)
        try context.save()
        return true
    }
}
