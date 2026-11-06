import Foundation
import StyleVaultCore

/// I giorni come si leggono sullo schermo. Mezzogiorno locale: nessun fuso sposta il giorno.
enum DayText {
    private static func date(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// "ven 6"
    static func short(_ day: String) -> String {
        date(day)?.formatted(.dateTime.weekday(.abbreviated).day()) ?? day
    }

    /// "venerdì 6 novembre"
    static func long(_ day: String) -> String {
        date(day)?.formatted(.dateTime.weekday(.wide).day().month(.wide)) ?? day
    }

    /// "6 nov 2026"
    static func medium(_ day: String) -> String {
        date(day)?.formatted(.dateTime.day().month(.abbreviated).year()) ?? day
    }

    static func adding(_ days: Int, to day: String) -> String {
        guard let start = date(day),
              let end = Calendar.current.date(byAdding: .day, value: days, to: start) else { return day }
        return CalendarMath.iso(end)
    }
}
