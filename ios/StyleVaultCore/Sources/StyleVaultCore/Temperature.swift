import Foundation

public enum TemperatureUnit: String, Sendable {
    case celsius, fahrenheit

    /// `auto` segue il paese del dispositivo; il Profilo può fissare l'unità.
    public static func resolve(_ stored: String, usesFahrenheit: Bool) -> TemperatureUnit {
        TemperatureUnit(rawValue: stored) ?? (usesFahrenheit ? .fahrenheit : .celsius)
    }
}

/// Il meteo resta in gradi centigradi: l'unità cambia solo ciò che si legge.
public enum Temperature {
    public static func value(_ celsius: Double, unit: TemperatureUnit) -> Int {
        jsRound(unit == .fahrenheit ? celsius * 9 / 5 + 32 : celsius)
    }
}
