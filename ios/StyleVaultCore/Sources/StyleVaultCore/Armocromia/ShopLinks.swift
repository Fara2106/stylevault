import Foundation

public enum ShopKind: Sendable { case clothing, makeup }

public struct ShopLink: Equatable, Identifiable, Sendable {
    public let shop: String
    public let label: String
    public let url: URL

    public var id: String { shop }
}

/// Link di ricerca ai negozi, senza API e senza costi. Solo negozi con la ricerca verificata sul campo.
public enum ShopLinks {
    private typealias Entry = (shop: String, label: String, it: String, en: String)

    private static let clothing: [Entry] = [
        ("zalando", "Zalando", "https://www.zalando.it/catalogo/?q=", "https://www.zalando.co.uk/catalog/?q="),
        ("asos", "ASOS", "https://www.asos.com/it/search/?q=", "https://www.asos.com/search/?q="),
        ("amazon", "Amazon", "https://www.amazon.it/s?k=", "https://www.amazon.com/s?k="),
    ]
    private static let makeup: [Entry] = [
        ("notino", "Notino", "https://www.notino.it/search.asp?exps=", "https://www.notino.co.uk/search.asp?exps="),
        ("amazon", "Amazon", "https://www.amazon.it/s?k=", "https://www.amazon.com/s?k="),
    ]
    private static let single: [Entry] = [
        ("zara", "Zara", "https://www.zara.com/it/it/search?searchTerm=", "https://www.zara.com/uk/en/search?searchTerm="),
        ("hm", "H&M", "https://www2.hm.com/it_it/search-results.html?q=", "https://www2.hm.com/en_gb/search-results.html?q="),
        ("zalando", "Zalando", "https://www.zalando.it/catalogo/?q=", "https://www.zalando.co.uk/catalog/?q="),
        ("asos", "ASOS", "https://www.asos.com/it/search/?q=", "https://www.asos.com/search/?q="),
    ]
    /// Senza ricerca collegabile: si apre la home e il colore si cerca lì.
    private static let homes: [ShopKind: [Entry]] = [
        .clothing: [("bershka", "Bershka", "https://www.bershka.com/it/", "https://www.bershka.com/gb/")],
        .makeup: [("sephora", "Sephora", "https://www.sephora.it/", "https://www.sephora.com/"),
                  ("douglas", "Douglas", "https://www.douglas.it/", "https://www.douglas.de/")],
    ]

    /// I caratteri che `encodeURIComponent` lascia in chiaro.
    private static let unreserved = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")

    private static func base(_ entry: Entry, _ language: String) -> String {
        language == "en" ? entry.en : entry.it
    }

    private static func link(_ entry: Entry, query: String, language: String) -> ShopLink? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: unreserved),
              let url = URL(string: base(entry, language) + encoded) else { return nil }
        return ShopLink(shop: entry.shop, label: entry.label, url: url)
    }

    public static func search(kind: ShopKind, query: String, language: String) -> [ShopLink] {
        (kind == .makeup ? makeup : clothing).compactMap { link($0, query: query, language: language) }
    }

    public static func one(shop: String, query: String, language: String) -> ShopLink? {
        single.first { $0.shop == shop }.flatMap { link($0, query: query, language: language) }
    }

    public static func home(kind: ShopKind, language: String) -> [ShopLink] {
        (homes[kind] ?? []).compactMap { entry in
            URL(string: base(entry, language)).map { ShopLink(shop: entry.shop, label: entry.label, url: $0) }
        }
    }
}
