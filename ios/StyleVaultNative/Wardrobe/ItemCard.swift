import StyleVaultCore
import SwiftUI

extension GridItem {
    /// Le colonne di capi e desideri. In alto: le schede con più righe non devono spostare le vicine.
    static let cardColumns = [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)]
}

/// Il pallino di un colore. Il bordo si vede sempre: il bianco su fondo chiaro, il nero su fondo scuro.
struct ColorDot: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Palette.muted, lineWidth: 1))
    }
}

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
                    ColorDot(color: color.color, size: 10)
                }
            }
        }
    }
}

struct FavoriteButton: View {
    let isFavorite: Bool
    let id: String
    /// Sopra una foto serve il suo fondo, come sul sito: le foto dei negozi sono spesso chiarissime.
    var onPhoto = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Palette.danger : Palette.ink)
                .background {
                    if onPhoto { Circle().fill(Palette.bg.opacity(0.85)).frame(width: 32, height: 32) }
                }
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
