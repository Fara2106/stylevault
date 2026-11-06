import XCTest
@testable import StyleVaultCore

/// Stessi casi di src/utils/statistics.test.js.
final class WardrobeStatisticsTests: XCTestCase {
    private let top = mk("top1", "tops", colors: ["white", "navy"], price: 60)
    private let bottom = mk("bottom1", "bottoms", price: 100)
    private let shoes = mk("shoes1", "shoes")
    private var items: [OutfitPiece] { [top, bottom, shoes] }
    private let history = [
        WearLog(date: "2026-07-01", worn: true, itemIDs: ["top1", "bottom1", "shoes1"]),
        WearLog(date: "2026-07-03", worn: true, itemIDs: ["top1", "shoes1"]),
        WearLog(date: "2026-07-05", worn: false, itemIDs: ["top1", "bottom1", "shoes1"]),
    ]

    func testContaSoloLeVociIndossate() {
        let stats = WardrobeStatistics.wearStats(history)
        XCTAssertEqual(stats["top1"], WearStat(count: 2, lastDate: "2026-07-03"))
        XCTAssertEqual(stats["bottom1"], WearStat(count: 1, lastDate: "2026-07-01"))
    }

    func testPiuIndossati() {
        let most = WardrobeStatistics.mostWorn(items, history)
        XCTAssertEqual(most[0].item.id, "top1")
        XCTAssertEqual(most[0].count, 2)
    }

    func testMaiIndossatiPerPrimi() {
        let least = WardrobeStatistics.leastWorn(items + [mk("nuovo", "tops")], history)
        XCTAssertEqual(least[0].item.id, "nuovo")
        XCTAssertEqual(least[0].count, 0)
    }

    func testPerCategoria() {
        let first = WardrobeStatistics.categoryBreakdown(items + [mk("top2", "tops")])[0]
        XCTAssertEqual(first.key, "tops")
        XCTAssertEqual(first.count, 2)
    }

    func testPerColore() {
        let byColor = WardrobeStatistics.colorBreakdown(items)
        XCTAssertEqual(byColor.first { $0.key == "black" }?.count, 2)
        XCTAssertEqual(byColor.first { $0.key == "white" }?.count, 1)
    }

    func testCostoPerUtilizzo() {
        let result = WardrobeStatistics.costPerWear(items, history)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].item.id, "top1")
        XCTAssertEqual(result[0].costPerWear, 30)
        XCTAssertEqual(result[1].costPerWear, 100)
    }
}
