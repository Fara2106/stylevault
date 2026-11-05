import Foundation

enum AppTab: Hashable, CaseIterable { case wardrobe, outfit, add, calendar, profile }

/// Il tasto + non è una vera tab: apre il foglio di aggiunta e lascia selezionata la tab di prima.
struct TabRouter: Equatable {
    var selected: AppTab = .wardrobe
    var isAddSheetPresented = false

    mutating func select(_ tab: AppTab) {
        if tab == .add {
            isAddSheetPresented = true
        } else {
            selected = tab
        }
    }
}
