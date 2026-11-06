import StyleVaultCore
import SwiftUI

extension DayPartKey {
    var inlineText: String {
        switch self {
        case .morning: return String(localized: "weather.part.morning")
        case .afternoon: return String(localized: "weather.part.afternoon")
        case .evening: return String(localized: "weather.part.evening")
        }
    }

    // Scritte per intero: una chiave composta con `\()` cercherebbe "weather.partTitle.%@".
    var title: LocalizedStringKey {
        switch self {
        case .morning: return "weather.partTitle.morning"
        case .afternoon: return "weather.partTitle.afternoon"
        case .evening: return "weather.partTitle.evening"
        }
    }
}

extension OutfitAdvice {
    var text: String {
        switch self {
        case .tooManyColors: return String(localized: "advice.tooManyColors")
        case .monochrome: return String(localized: "advice.monochrome")
        case .colorsHarmonious: return String(localized: "advice.colorsHarmonious")
        case .colorsClash: return String(localized: "advice.colorsClash")
        case .tooLight(let temp): return String(localized: "advice.tooLight \(Temperature.value(Double(temp), unit: TemperatureText.unit))")
        case .tooWarm(let temp): return String(localized: "advice.tooWarm \(Temperature.value(Double(temp), unit: TemperatureText.unit))")
        case .perfectWarmth: return String(localized: "advice.perfectWarmth")
        case .layers(let cold, let coldPart, let warm, let warmPart):
            return String(localized: "advice.layers \(cold) \(coldPart.inlineText) \(warm) \(warmPart.inlineText)")
        case .rainLater(let hour): return String(localized: "advice.rainLater \(hour)")
        case .rainShoes: return String(localized: "advice.rainShoes")
        case .rainOuter: return String(localized: "advice.rainOuter")
        case .uvHigh: return String(localized: "advice.uvHigh")
        case .windStrong: return String(localized: "advice.windStrong")
        case .wornRecently(let date): return String(localized: "advice.wornRecently \(DayText.medium(date))")
        case .elevated: return String(localized: "advice.elevated")
        }
    }
}

extension WeatherIcon {
    var symbol: String {
        switch self {
        case .sun: return "sun.max"
        case .cloud: return "cloud"
        case .rain: return "cloud.rain"
        case .snow: return "cloud.snow"
        }
    }
}
