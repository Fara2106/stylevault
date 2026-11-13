import SwiftUI

/// Il riquadro di un campo di testo, con i colori del tema anche in scuro.
/// SwiftUI apre la tastiera solo sulla riga del testo: qui la apre tutto il riquadro.
struct FieldBox: ViewModifier {
    var minHeight: CGFloat = 52
    var inset: CGFloat = 14

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .padding(.horizontal, inset)
            .frame(minHeight: minHeight)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border))
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture { isFocused = true }
    }
}
