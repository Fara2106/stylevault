import StyleVaultCore
import SwiftUI

/// La scheda di un capo. Lavora su valori semplici: vale per il guardaroba e per la wishlist.
struct ItemCard: View {
    let name: String
    let brand: String?
    let colors: [String]
    let photo: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { ItemPhotoView(data: photo, name: name) }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(verbatim: name)
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if let brand {
                Text(verbatim: brand)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                ForEach(colors.compactMap(Catalog.color(id:))) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Palette.border))
                }
            }
        }
    }
}

struct FavoriteButton: View {
    let isFavorite: Bool
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Palette.danger : Palette.ink)
                .frame(width: 44, height: 44)
                // Con lo stile plain conta solo il disegno: il centro del cuore vuoto non si toccherebbe.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("common.favorites"))
        .accessibilityAddTraits(isFavorite ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
