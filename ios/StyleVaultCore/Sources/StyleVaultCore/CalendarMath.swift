import Foundation

/// Una voce del calendario per l'avviso di ripetizione.
public struct RepeatLog: Equatable, Sendable {
    public let id: String
    public let date: String
    public let itemIDs: [String]

    public init(id: String, date: String, itemIDs: [String]) {
        self.id = id
        self.date = date
        self.itemIDs = itemIDs
    }
}

/// I giorni sono stringhe `yyyy-MM-dd`, come in `CalendarEntry`: cambiando fuso non si spostano.
public enum CalendarMath {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    /// Il calendario del telefono può essere buddista o giapponese: i giorni dell'app sono sempre gregoriani.
    public static var local: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = .current
        return calendar
    }

    private static func date(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    public static func iso(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Il giorno di `date` nel calendario del telefono.
    public static func iso(_ date: Date, calendar: Calendar = CalendarMath.local) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return iso(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// Una data vera nel formato `yyyy-MM-dd`: i file importati possono contenere di tutto.
    public static func isValid(_ day: String) -> Bool {
        guard let parsed = date(day) else { return false }
        return iso(parsed, calendar: utc) == day
    }

    /// Giorni da `start` a `end`; negativo se `end` viene prima.
    public static func daysBetween(_ start: String, and end: String) -> Int? {
        guard let first = date(start), let second = date(end) else { return nil }
        return utc.dateComponents([.day], from: first, to: second).day
    }

    /// Le settimane del mese (`month` da 1 a 12), dal lunedì; `nil` per le caselle vuote.
    public static func monthMatrix(year: Int, month: Int) -> [[Int?]] {
        guard let first = utc.date(from: DateComponents(year: year, month: month, day: 1)),
              let days = utc.range(of: .day, in: .month, for: first)?.count else { return [] }
        let offset = (utc.component(.weekday, from: first) + 5) % 7 // lunedì = 0
        var cells: [Int?] = Array(repeating: nil, count: offset) + (1...days).map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// La data più vicina, nei 7 giorni prima di `entry`, in cui è stato messo uno dei suoi capi.
    public static func repeatDate(for entry: RepeatLog, in logs: [RepeatLog]) -> String? {
        let ids = Set(entry.itemIDs)
        return logs
            .filter { log in
                guard log.id != entry.id, log.date != entry.date,
                      let days = daysBetween(log.date, and: entry.date), (1...7).contains(days) else { return false }
                return log.itemIDs.contains(where: ids.contains)
            }
            .map(\.date)
            .max()
    }
}
