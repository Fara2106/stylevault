import StyleVaultCore
import SwiftUI

/// Una categoria da mostrare: del catalogo, con la chiave da tradurre, o creata dalla persona.
struct CategoryChoice: Identifiable, Equatable {
    enum Title: Equatable {
        case catalog(String)
        case custom(String)
    }

    let id: String
    let title: Title

    var text: Text {
        switch title {
        case .catalog(let key): return Text(LocalizedStringKey(key))
        case .custom(let name): return Text(verbatim: name)
        }
    }

    var isCustom: Bool {
        if case .custom = title { return true }
        return false
    }

    static func all(custom: [CustomCategory]) -> [CategoryChoice] {
        let catalog = Catalog.categories.map { CategoryChoice(id: $0.id, title: .catalog($0.labelKey)) }
        let mine = custom
            .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
            .map { CategoryChoice(id: $0.id, title: .custom($0.name)) }
        return catalog + mine
    }

    /// `nil` per una categoria che non esiste più: la vista non mostra nulla, mai la chiave grezza.
    static func find(_ id: String, custom: [CustomCategory]) -> CategoryChoice? {
        all(custom: custom).first { $0.id == id }
    }
}
