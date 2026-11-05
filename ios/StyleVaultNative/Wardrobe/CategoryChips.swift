import SwiftUI

/// Una riga di elementi che va a capo quando non c'è più spazio.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let frames = arrange(subviews, width: width)
        let height = frames.map(\.maxY).max() ?? 0
        let used = frames.map(\.maxX).max() ?? 0
        return CGSize(width: proposal.width ?? used, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(subviews, width: bounds.width)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return frames
    }
}

/// Il tasto pieno. `.borderedProminent` scrive sempre in bianco: col tema scuro, dove l'inchiostro
/// è chiaro, il testo sparirebbe.
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundStyle(Palette.bg)
            .background(Palette.ink, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct Chip: View {
    let text: Text
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            text
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Palette.bg : Palette.ink)
                .background(isSelected ? Palette.ink : Palette.surface, in: Capsule())
                .overlay(Capsule().stroke(Palette.border))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// I filtri di categoria. Una categoria che non esiste più non ha il suo chip: il capo resta in Tutti.
struct CategoryChips: View {
    @Binding var selection: String?
    let choices: [CategoryChoice]
    var onDelete: ((CategoryChoice) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(text: Text("common.all"), isSelected: selection == nil) { selection = nil }
                    .accessibilityIdentifier("filter-all")
                ForEach(choices) { choice in
                    chip(for: choice)
                }
            }
            .padding(.vertical, 1)
        }
        // I chip arrivano al bordo dello schermo, non al margine della pagina.
        .scrollClipDisabled()
    }

    @ViewBuilder private func chip(for choice: CategoryChoice) -> some View {
        let chip = Chip(text: choice.text, isSelected: selection == choice.id) { selection = choice.id }
            .accessibilityIdentifier("filter-\(choice.id)")
        if let onDelete, choice.isCustom {
            chip.contextMenu {
                Button("native.category.delete", role: .destructive) { onDelete(choice) }
            }
        } else {
            chip
        }
    }
}
