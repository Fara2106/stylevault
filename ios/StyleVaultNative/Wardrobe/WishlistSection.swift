import OSLog
import StyleVaultCore
import SwiftData
import SwiftUI

/// La sezione Wishlist. Un desiderio si apre nel negozio, si compra o si cancella.
struct WishlistSection: View {
    let onAdd: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(CutoutWorker.self) private var cutoutWorker
    @Query(sort: \WishlistItem.createdAt) private var wishes: [WishlistItem]

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "wardrobe")

    var body: some View {
        if wishes.isEmpty {
            VStack(spacing: 12) {
                Text("wishlist.emptyState").font(.headline).foregroundStyle(Palette.ink)
                Button("wishlist.emptyAction", action: onAdd)
                    .buttonStyle(InkButtonStyle())
                    .accessibilityIdentifier("wishlist-empty-add")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        } else {
            LazyVGrid(columns: GridItem.cardColumns, spacing: 16) {
                ForEach(wishes) { wish in
                    card(for: wish)
                }
            }
        }
    }

    private func card(for wish: WishlistItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ItemCard(name: wish.name, brand: wish.brand, colors: wish.colors, photo: wish.photoFront)
            HStack(spacing: 4) {
                if let url = wish.sourceURL.flatMap(LinkText.httpURL(from:)) {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square").frame(width: 44, height: 44)
                    }
                    .tint(Palette.link)
                    .accessibilityLabel(Text("wishlist.openLink"))
                }
                Button("wishlist.bought") { buy(wish) }
                    .buttonStyle(.bordered)
                    .tint(Palette.ink)
                    .font(.footnote)
                    .accessibilityHint(Text("wishlist.moveToWardrobe"))
                    .accessibilityIdentifier("wish-bought")
                Spacer(minLength: 0)
                Button { remove(wish) } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Palette.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.delete"))
                .accessibilityIdentifier("wish-delete")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wish-card")
    }

    private func buy(_ wish: WishlistItem) {
        do {
            let item = try WardrobeStore.moveToWardrobe(wish, in: context)
            if item.photoFront != nil { cutoutWorker.enqueue(item.id) }
        } catch {
            logger.error("Spostamento nel guardaroba non riuscito: \(error)")
        }
    }

    private func remove(_ wish: WishlistItem) {
        do {
            try WardrobeStore.delete(wish, in: context)
        } catch {
            logger.error("Cancellazione del desiderio non riuscita: \(error)")
        }
    }
}
