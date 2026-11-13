import Foundation

/// Testi delle pagine dei negozi.
public enum LinkText {
    public static func httpURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// "Maglione - ecru - Zalando.it" → "Maglione - ecru": il negozio in coda non serve nel nome del capo.
    public static func stripShopSuffix(_ title: String, site: String) -> String {
        let shop = strippingWWW(site.lowercased()).split(separator: ".").first.map(String.init) ?? ""
        guard !shop.isEmpty else { return title }
        let separators = title.ranges(of: #/\s+[-|–]\s+/#)
        guard let last = separators.last,
              title[last.upperBound...].lowercased().contains(shop) else { return title }
        return String(title[..<last.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Il nome del negozio dall'host: la pagina letta sul telefono non dichiara l'editore.
    public static func siteName(host: String) -> String {
        let parts = strippingWWW(host.lowercased()).split(separator: ".").map(String.init)
        let name: String
        switch parts.count {
        case 0: return ""
        case 1, 2: name = parts[0]
        default:
            // "zalando.co.uk": il penultimo pezzo è il suffisso del paese, non il negozio.
            name = parts[parts.count - 2].count <= 3 ? parts[parts.count - 3] : parts[parts.count - 2]
        }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// I muri anti-bot rispondono con una pagina vera: il suo titolo non deve diventare il nome del capo.
    public static func isBlockedTitle(_ title: String) -> Bool {
        let lowered = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return blockedPrefixes.contains { lowered.hasPrefix($0) }
    }

    private static let blockedPrefixes = [
        "access denied", "just a moment", "attention required", "forbidden",
        "403", "404", "page not found", "pagina non trovata", "robot check",
    ]

    private static func strippingWWW(_ host: String) -> String {
        host.replacing(#/^www\d*\./#, with: "")
    }
}
