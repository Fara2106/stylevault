import StyleVaultCore
import SwiftUI

/// Le miniature di una fila di capi.
struct OutfitThumbs: View {
    let items: [Item]
    var size: CGFloat = 56

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                ItemPhotoView(data: item.shownPhoto, name: item.name)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(Text(verbatim: item.name))
            }
        }
    }
}

/// La proposta di un outfit.
struct OutfitCardView: View {
    let outfit: GeneratedOutfit
    let items: [String: Item]
    let lockedIDs: Set<String>
    let saved: Bool
    /// Già registrato: "calendar.worn" o "calendar.planned" secondo il giorno.
    let wornLabel: LocalizedStringKey?
    let onToggleLock: (String) -> Void
    let onSave: () -> Void
    let onTryOn: () -> Void
    let onWear: () -> Void

    private var sections: [(label: LocalizedStringKey, piece: OutfitPiece)] {
        let slots: [(LocalizedStringKey, OutfitPiece?)] = [
            (outfit.isDress ? "outfit.dress" : "outfit.top", outfit.top), ("outfit.bottom", outfit.bottom),
            ("outfit.shoes", outfit.shoes), ("outfit.outerwear", outfit.outerwear),
        ]
        return slots.compactMap { label, piece in piece.map { (label, $0) } }
    }

    private var missingText: String {
        outfit.missing.map { piece in
            switch piece {
            case .top: return String(localized: "outfit.missingPiece.top")
            case .bottom: return String(localized: "outfit.missingPiece.bottom")
            case .shoes: return String(localized: "outfit.missingPiece.shoes")
            }
        }.joined(separator: ", ")
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                header
                if !outfit.missing.isEmpty {
                    Text("outfit.incomplete \(missingText)")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("outfit-missing")
                }
                ForEach(sections, id: \.piece.id) { section in
                    row(section.label, section.piece)
                }
                if !outfit.accessories.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("outfit.accessoriesLabel").font(.caption).foregroundStyle(Palette.muted)
                        OutfitThumbs(items: outfit.accessories.compactMap { items[$0.id] }, size: 44)
                    }
                }
                actions
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("outfit-card")
    }

    /// Con il testo grande punteggio e percentuali non stanno su una riga: le percentuali scendono sotto.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                score
                Spacer()
                metric(outfit.weatherMatch, "outfit.weatherMatch")
                metric(outfit.colorHarmony, "outfit.colorMatch")
            }
            VStack(alignment: .leading, spacing: 8) {
                score
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    metric(outfit.weatherMatch, "outfit.weatherMatch", alignment: .leading).padding(.leading, -12)
                    metric(outfit.colorHarmony, "outfit.colorMatch", alignment: .leading)
                    Spacer()
                }
            }
        }
    }

    private var score: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "\(outfit.score)").displayFont(34).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("outfit-score")
            Text("outfit.outfitScore").font(.caption).foregroundStyle(Palette.muted).fixedSize()
        }
    }

    private func metric(_ value: Int, _ label: LocalizedStringKey, alignment: HorizontalAlignment = .trailing) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(verbatim: "\(value)%").font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
            Text(label).font(.caption).foregroundStyle(Palette.muted).fixedSize()
        }
        .padding(.leading, 12)
    }

    @ViewBuilder private func row(_ label: LocalizedStringKey, _ piece: OutfitPiece) -> some View {
        if let item = items[piece.id] {
            let locked = lockedIDs.contains(piece.id)
            HStack(spacing: 12) {
                ItemPhotoView(data: item.shownPhoto, name: item.name)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.caption).foregroundStyle(Palette.muted)
                    Text(verbatim: item.name).font(.subheadline).foregroundStyle(Palette.ink).lineLimit(2)
                }
                Spacer()
                Button { onToggleLock(piece.id) } label: {
                    Image(systemName: locked ? "lock.fill" : "lock.open")
                        .foregroundStyle(locked ? Palette.ink : Palette.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(locked ? "outfit.unlockItem" : "outfit.lockItem"))
                .accessibilityAddTraits(locked ? .isSelected : [])
                .accessibilityIdentifier("outfit-lock")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button(action: onTryOn) { Label("native.avatar.title", systemImage: "person.crop.rectangle") }
                .buttonStyle(OutlineButtonStyle())
                .accessibilityIdentifier("outfit-avatar")
            wearActions
        }
    }

    private var wearActions: some View {
        AdaptiveRow(spacing: 8) {
            Button(action: onSave) {
                Label(saved ? "outfit.saved" : "common.save", systemImage: saved ? "checkmark" : "heart")
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(saved)
            .accessibilityIdentifier("outfit-save")
            if let wornLabel {
                Button(action: {}) { Label(wornLabel, systemImage: "checkmark") }
                    .buttonStyle(OutlineButtonStyle())
                    .disabled(true)
                    .accessibilityIdentifier("outfit-worn")
            } else {
                Button(action: onWear) { Label("outfit.wearThis", systemImage: "checkmark") }
                    .buttonStyle(FilledButtonStyle())
                    .accessibilityIdentifier("outfit-wear")
            }
        }
    }
}
