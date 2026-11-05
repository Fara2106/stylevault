import OSLog
import StyleVaultCore
import SwiftData
import SwiftUI

enum WardrobeSection: Hashable { case wardrobe, wishlist }

/// La schermata Guardaroba, come src/pages/WardrobePage/WardrobePage.jsx.
struct WardrobeView: View {
    let onAdd: (AddDestination) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Item.createdAt) private var items: [Item]
    @Query(sort: \WishlistItem.createdAt) private var wishes: [WishlistItem]
    @Query private var customCategories: [CustomCategory]

    @State private var section = WardrobeSection.wardrobe
    @State private var filter = WardrobeFilter()
    @State private var isCategoryInUse = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "wardrobe")
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var filtered: [Item] {
        items.filter { filter.matches(name: $0.name, brand: $0.brand, category: $0.category, favorite: $0.favorite) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if section == .wardrobe {
                        wardrobeContent
                    } else {
                        WishlistSection { onAdd(.wishlist) }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            // Su iPad le tab stanno nella fascia della barra: nasconderla fa salire la pagina sotto di loro
            // quando si torna dal dettaglio.
            .toolbar(sizeClass == .regular ? .automatic : .hidden, for: .navigationBar)
            .alert("native.category.inUse", isPresented: $isCategoryInUse) {
                Button("common.close", role: .cancel) {}
            }
        }
    }

    private func deleteCategory(_ choice: CategoryChoice) {
        guard let category = customCategories.first(where: { $0.id == choice.id }) else { return }
        do {
            if try CustomCategoryStore.delete(category, in: context) {
                if filter.category == choice.id { filter.category = nil }
            } else {
                isCategoryInUse = true
            }
        } catch {
            logger.error("Cancellazione della categoria non riuscita: \(error)")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(section == .wardrobe ? "wardrobe.title" : "wishlist.title"))
                .font(.display(30))
                .foregroundStyle(Palette.ink)
            Group {
                if section == .wardrobe {
                    Text("native.wardrobe.count \(items.count)")
                } else {
                    Text("wishlist.subtitle")
                }
            }
            .font(.footnote)
            .foregroundStyle(Palette.muted)
            HStack(spacing: 8) {
                Chip(text: Text("wardrobe.tabWardrobe"), isSelected: section == .wardrobe) { section = .wardrobe }
                    .accessibilityIdentifier("wardrobe-section-wardrobe")
                Chip(text: wishlistTitle, isSelected: section == .wishlist) { section = .wishlist }
                    .accessibilityIdentifier("wardrobe-section-wishlist")
            }
        }
    }

    private var wishlistTitle: Text {
        wishes.isEmpty ? Text("wardrobe.tabWishlist") : Text("wardrobe.tabWishlist") + Text(verbatim: " \(wishes.count)")
    }

    @ViewBuilder private var wardrobeContent: some View {
        toolbarRow
        CategoryChips(selection: $filter.category, choices: CategoryChoice.all(custom: customCategories),
                      onDelete: deleteCategory)
        if filtered.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filtered) { item in
                    card(for: item)
                }
            }
        }
    }

    private var toolbarRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField("wardrobe.searchPlaceholder", text: $filter.search)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("wardrobe-search")
            }
            .padding(10)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border))
            FavoriteButton(isFavorite: filter.onlyFavorites, id: "wardrobe-favorites") {
                filter.onlyFavorites.toggle()
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 12) {
            if items.isEmpty {
                Text("wardrobe.emptyState").font(.headline).foregroundStyle(Palette.ink)
                Button("wardrobe.emptyAction") { onAdd(.wardrobe) }
                    .buttonStyle(InkButtonStyle())
                    .accessibilityIdentifier("wardrobe-empty-add")
            } else {
                Text("common.noResults").font(.headline).foregroundStyle(Palette.ink)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func card(for item: Item) -> some View {
        // Il cuore sta sopra il link e non dentro: non deve aprire il dettaglio.
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                ItemDetailView(itemID: item.id)
            } label: {
                ItemCard(name: item.name, brand: item.brand, colors: item.colors, photo: item.photoFront)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("item-card")
            FavoriteButton(isFavorite: item.favorite, id: "item-card-favorite", onPhoto: true) {
                do {
                    try WardrobeStore.toggleFavorite(item, in: context)
                } catch {
                    logger.error("Preferito non salvato: \(error)")
                }
            }
        }
    }
}
