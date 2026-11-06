import Foundation
import StyleVaultCore

/// La temperatura come si legge, nell'unità scelta nel Profilo.
enum TemperatureText {
    static let storageKey = "units.temperature"

    static var unit: TemperatureUnit {
        TemperatureUnit.resolve(UserDefaults.standard.string(forKey: storageKey) ?? "auto",
                                usesFahrenheit: Locale.current.measurementSystem == .us)
    }

    static func string(_ celsius: Double) -> String {
        "\(Temperature.value(celsius, unit: unit))°"
    }
}
