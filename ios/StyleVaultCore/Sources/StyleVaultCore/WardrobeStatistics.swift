import Foundation

/// Una voce del calendario per le statistiche.
public struct WearLog: Equatable, Sendable {
    public let date: String
    public let worn: Bool
    public let itemIDs: [String]

    public init(date: String, worn: Bool, itemIDs: [String]) {
        self.date = date
        self.worn = worn
        self.itemIDs = itemIDs
    }
}

public struct WearStat: Equatable, Sendable {
    public var count: Int
    public var lastDate: String?

    public init(count: Int, lastDate: String?) {
        self.count = count
        self.lastDate = lastDate
    }
}

public struct WornPiece: Equatable, Sendable {
    public let item: OutfitPiece
    public let count: Int
}

public struct CostPerWear: Equatable, Sendable {
    public let item: OutfitPiece
    public let count: Int
    public let costPerWear: Double
}

public struct Breakdown: Identifiable, Equatable, Sendable {
    public let key: String
    public let count: Int
    public var id: String { key }
}

/// Statistiche del guardaroba. Contano solo le voci indossate.
public enum WardrobeStatistics {
    public static func wearStats(_ history: [WearLog]) -> [String: WearStat] {
        var stats: [String: WearStat] = [:]
        for log in history where log.worn {
            for id in log.itemIDs {
                var current = stats[id] ?? WearStat(count: 0, lastDate: nil)
                current.count += 1
                if current.lastDate.map({ log.date > $0 }) ?? true { current.lastDate = log.date }
                stats[id] = current
            }
        }
        return stats
    }

    /// `sort` di Swift non promette di tenere l'ordine a parità: l'indice lo tiene fermo.
    private static func stableSorted<T, K: Comparable>(_ values: [T], by key: (T) -> K, descending: Bool = false) -> [T] {
        values.enumerated().sorted { a, b in
            let (first, second) = (key(a.element), key(b.element))
            if first != second { return descending ? first > second : first < second }
            return a.offset < b.offset
        }.map(\.element)
    }

    public static func mostWorn(_ items: [OutfitPiece], _ history: [WearLog], limit: Int = 5) -> [WornPiece] {
        let stats = wearStats(history)
        let worn = items.map { WornPiece(item: $0, count: stats[$0.id]?.count ?? 0) }.filter { $0.count > 0 }
        return Array(stableSorted(worn, by: \.count, descending: true).prefix(limit))
    }

    public static func leastWorn(_ items: [OutfitPiece], _ history: [WearLog], limit: Int = 5) -> [WornPiece] {
        let stats = wearStats(history)
        // Chi è già fra i più indossati non è "dimenticato": con pochi capi le due liste sarebbero uguali.
        let most = Set(mostWorn(items, history, limit: limit).map(\.item.id))
        let rest = items.filter { !most.contains($0.id) }
        return Array(stableSorted(rest.map { WornPiece(item: $0, count: stats[$0.id]?.count ?? 0) }, by: \.count).prefix(limit))
    }

    private static func breakdown(_ keys: [String]) -> [Breakdown] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for key in keys {
            if counts[key] == nil { order.append(key) }
            counts[key, default: 0] += 1
        }
        return stableSorted(order.map { Breakdown(key: $0, count: counts[$0] ?? 0) }, by: \.count, descending: true)
    }

    public static func categoryBreakdown(_ items: [OutfitPiece]) -> [Breakdown] { breakdown(items.map(\.category)) }

    public static func colorBreakdown(_ items: [OutfitPiece]) -> [Breakdown] { breakdown(items.flatMap(\.colors)) }

    /// I capi mai indossati riportano il prezzo pieno.
    public static func costPerWear(_ items: [OutfitPiece], _ history: [WearLog], limit: Int = 5) -> [CostPerWear] {
        let stats = wearStats(history)
        let costs = items.compactMap { item -> CostPerWear? in
            guard let price = item.price, price > 0 else { return nil }
            let count = stats[item.id]?.count ?? 0
            return CostPerWear(item: item, count: count, costPerWear: price / Double(max(1, count)))
        }
        return Array(stableSorted(costs, by: \.costPerWear).prefix(limit))
    }
}
