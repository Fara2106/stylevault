import Foundation

/// I filtri della schermata Guardaroba, come src/pages/WardrobePage/WardrobePage.jsx.
public struct WardrobeFilter: Equatable, Sendable {
    /// `nil` vuol dire tutte le categorie.
    public var category: String?
    public var onlyFavorites: Bool
    public var search: String

    public init(category: String? = nil, onlyFavorites: Bool = false, search: String = "") {
        self.category = category
        self.onlyFavorites = onlyFavorites
        self.search = search
    }

    public func matches(name: String, brand: String?, category: String, favorite: Bool) -> Bool {
        if let wanted = self.category, wanted != category { return false }
        if onlyFavorites && !favorite { return false }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        return name.lowercased().contains(query) || (brand ?? "").lowercased().contains(query)
    }
}
