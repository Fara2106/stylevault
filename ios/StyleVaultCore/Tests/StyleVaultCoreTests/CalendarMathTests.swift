import XCTest
@testable import StyleVaultCore

final class CalendarMathTests: XCTestCase {
    func testSettimaneDalLunedi() {
        // Novembre 2026 inizia di domenica: sei vuoti prima.
        let weeks = CalendarMath.monthMatrix(year: 2026, month: 11)
        XCTAssertEqual(weeks[0], [nil, nil, nil, nil, nil, nil, 1])
        XCTAssertEqual(weeks.last, [30, nil, nil, nil, nil, nil, nil])
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
    }

    func testFebbraioBisestile() {
        XCTAssertEqual(CalendarMath.monthMatrix(year: 2028, month: 2).flatMap { $0 }.compactMap { $0 }.last, 29)
    }

    func testGiorniTraDueDate() {
        XCTAssertEqual(CalendarMath.daysBetween("2026-07-01", and: "2026-07-08"), 7)
        XCTAssertEqual(CalendarMath.daysBetween("2026-12-31", and: "2027-01-01"), 1)
        XCTAssertEqual(CalendarMath.daysBetween("2026-07-08", and: "2026-07-01"), -7)
        XCTAssertNil(CalendarMath.daysBetween("boh", and: "2026-07-01"))
    }

    func testRipetizioneNeiSetteGiorniPrima() {
        let logs = [
            RepeatLog(id: "a", date: "2026-07-02", itemIDs: ["x"]),
            RepeatLog(id: "b", date: "2026-07-07", itemIDs: ["x", "y"]),
            RepeatLog(id: "c", date: "2026-07-09", itemIDs: ["x"]),
            RepeatLog(id: "d", date: "2026-06-20", itemIDs: ["x"]),
        ]
        let entry = RepeatLog(id: "e", date: "2026-07-08", itemIDs: ["x"])
        XCTAssertEqual(CalendarMath.repeatDate(for: entry, in: logs + [entry]), "2026-07-07")
        XCTAssertNil(CalendarMath.repeatDate(for: RepeatLog(id: "f", date: "2026-07-08", itemIDs: ["z"]), in: logs))
    }
}
