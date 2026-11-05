import OSLog
import StyleVaultCore
import SwiftData
import SwiftUI

/// Il dettaglio di un capo, come src/pages/ItemDetailPage/ItemDetailPage.jsx.
/// Passa dall'id: se un altro dispositivo cancella il capo, la query si svuota e la vista esce.
struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var items: [Item]
    @Query private var customCategories: [CustomCategory]

    @State private var isEditing = false
    @State private var isDeleteAsked = false

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "wardrobe")

    init(itemID: UUID) {
        _items = Query(filter: #Predicate<Item> { $0.id == itemID })
    }

    var body: some View {
        Group {
            if let item = items.first {
                content(for: item)
            } else {
                Palette.bg.ignoresSafeArea()
            }
        }
        .background(Palette.bg)
        .navigationTitle(Text("itemDetail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onChange(of: items.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    @ViewBuilder private func content(for item: Item) -> some View {
        ScrollView {
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 24) {
                    photos(of: item).frame(maxWidth: .infinity)
                    info(of: item).frame(maxWidth: 420)
                }
                .padding(24)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    photos(of: item)
                    info(of: item)
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $isEditing) {
            ItemFormView(mode: .edit(item))
        }
        .alert("itemDetail.deleteItem", isPresented: $isDeleteAsked) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive) { delete(item) }
        } message: {
            Text("wardrobe.deleteConfirm")
        }
    }

    // MARK: Foto

    private struct PhotoPage: Identifiable {
        let id: Int
        let data: Data?
        let caption: LocalizedStringKey?
    }

    private func pages(of item: Item) -> [PhotoPage] {
        var pages = [PhotoPage(id: 0, data: item.photoFront, caption: nil)]
        if let back = item.photoBack { pages.append(PhotoPage(id: 1, data: back, caption: "native.detail.photoBack")) }
        if let cutout = item.cutout { pages.append(PhotoPage(id: 2, data: cutout, caption: "native.detail.cutout")) }
        return pages
    }

    private func photos(of item: Item) -> some View {
        let pages = pages(of: item)
        return TabView {
            ForEach(pages) { page in
                ItemPhotoView(data: page.data, name: item.name, maxSide: GarmentImage.photoMaxSide, contentMode: .fit)
                    .overlay(alignment: .topLeading) {
                        if let caption = page.caption {
                            Text(caption)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Palette.bg, in: Capsule())
                                .padding(12)
                        }
                    }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .always : .never))
        // I pallini sono bianchi: senza fondo spariscono sulle foto chiare e il retro non si trova.
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: sizeClass == .regular ? 560 : 420)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            FavoriteButton(isFavorite: item.favorite, id: "detail-favorite", onPhoto: true) {
                perform { try WardrobeStore.toggleFavorite(item, in: context) }
            }
        }
    }

    // MARK: Dati

    private func info(of item: Item) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: item.name).font(.display(26)).foregroundStyle(Palette.ink)
                if let brand = item.brand {
                    Text(verbatim: brand).font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            colors(of: item)
            facts(of: item)
            if let url = item.sourceURL.flatMap(LinkText.httpURL(from:)) {
                Link(destination: url) {
                    Label("itemDetail.openShop", systemImage: "arrow.up.right.square")
                }
                .tint(Palette.accent)
            }
            HStack(spacing: 12) {
                Button("common.edit") { isEditing = true }
                    .buttonStyle(.bordered)
                    .tint(Palette.ink)
                    .accessibilityIdentifier("detail-edit")
                Button("itemDetail.deleteItem", role: .destructive) { isDeleteAsked = true }
                    .buttonStyle(.bordered)
                    .tint(Palette.danger)
                    .accessibilityIdentifier("detail-delete")
            }
        }
    }

    private func colors(of item: Item) -> some View {
        FlowLayout(spacing: 12) {
            ForEach(item.colors.compactMap(Catalog.color(id:))) { color in
                HStack(spacing: 6) {
                    Circle()
                        .fill(color.color)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Palette.border))
                    Text(LocalizedStringKey(color.labelKey)).font(.footnote).foregroundStyle(Palette.ink)
                }
            }
        }
    }

    private func facts(of item: Item) -> some View {
        VStack(spacing: 0) {
            if let choice = CategoryChoice.find(item.category, custom: customCategories) {
                fact("addItem.category", choice.text)
            }
            if let key = Catalog.category(id: item.category)?.subcategories.first(where: { $0.id == item.subcategory })?.labelKey {
                fact("addItem.subcategory", Text(LocalizedStringKey(key)))
            }
            if let brand = item.brand { fact("addItem.brand", Text(verbatim: brand)) }
            if let size = item.size { fact("addItem.size", Text(verbatim: size)) }
            if let key = Catalog.seasons.first(where: { $0.id == item.season })?.labelKey {
                fact("addItem.season", Text(LocalizedStringKey(key)))
            }
            if let key = Catalog.occasions.first(where: { $0.id == item.occasion })?.labelKey {
                fact("addItem.occasion", Text(LocalizedStringKey(key)))
            }
            if (1...5).contains(item.warmthLevel) {
                fact("addItem.warmth", Text.warmth(item.warmthLevel))
            }
            if let price = item.price {
                fact("addItem.price", Text(price, format: .currency(code: "EUR")))
            }
        }
    }

    private func fact(_ label: LocalizedStringKey, _ value: Text) -> some View {
        HStack {
            Text(label).font(.footnote).foregroundStyle(Palette.muted)
            Spacer()
            value.font(.subheadline).foregroundStyle(Palette.ink)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1) }
    }

    // MARK: Azioni

    private func delete(_ item: Item) {
        perform { try WardrobeStore.delete(item, in: context) }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            logger.error("Modifica del capo non salvata: \(error)")
        }
    }
}
