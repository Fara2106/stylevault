import SwiftUI

/// Controlli affiancati che, quando con il testo grande non stanno su una riga, vanno uno sotto l'altro:
/// così le parole non si spezzano a metà («Modifi-ca», «Chat-GPT»).
struct AdaptiveRow<Content: View>: View {
    var spacing: CGFloat = 12
    var alignment: HorizontalAlignment = .center
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) { content }
            VStack(alignment: alignment, spacing: spacing) { content }
        }
    }
}

/// In riga con il testo di misura normale, in colonna con le misure grandi dell'accessibilità.
/// Serve dove c'è testo che va a capo: lì `ViewThatFits` sceglierebbe la colonna anche quando la riga basta.
struct AccessibleRow<Content: View>: View {
    var spacing: CGFloat = 12
    var alignment: HorizontalAlignment = .leading
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: alignment, spacing: spacing) { content }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}
