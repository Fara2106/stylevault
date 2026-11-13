import Foundation

enum AppTab: Hashable, CaseIterable { case wardrobe, outfit, add, calendar, profile }

enum AddDestination: Hashable { case wardrobe, wishlist }

/// Il tasto + non è una vera tab: apre il foglio di aggiunta e lascia selezionata la tab di prima.
struct TabRouter: Equatable {
    var selected: AppTab = .wardrobe
    var isAddSheetPresented = false
    var addDestination: AddDestination = .wardrobe

    mutating func select(_ tab: AppTab) {
        if tab == .add {
            openAdd(to: .wardrobe)
        } else {
            selected = tab
        }
    }

    mutating func openAdd(to destination: AddDestination) {
        addDestination = destination
        isAddSheetPresented = true
    }
}
