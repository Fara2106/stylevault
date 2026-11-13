import Foundation
import StyleVaultCore

/// La temperatura come si legge, nell'unità scelta nel Profilo.
enum TemperatureText {
    static let storageKey = "units.temperature"

    /// «Automatica» segue l'unità di temperatura del telefono (Impostazioni → Lingua e zona), non solo il sistema di misura.
    static var unit: TemperatureUnit {
        TemperatureUnit.resolve(UserDefaults.standard.string(forKey: storageKey) ?? "auto",
                                usesFahrenheit: UnitTemperature(forLocale: .current) == .fahrenheit)
    }

    static func string(_ celsius: Double) -> String {
        "\(Temperature.value(celsius, unit: unit))°"
    }
}
