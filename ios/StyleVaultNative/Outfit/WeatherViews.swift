import StyleVaultCore
import SwiftUI

/// Il riquadro comune delle schede.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
    }
}

/// I due tasti delle schede: stessa forma e stessa altezza, pieno quello principale.
struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(Palette.bg)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(Palette.ink)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.border))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// La scheda meteo del giorno, come src/components/WeatherBadge.
struct WeatherCard: View {
    let weather: DayForecast
    let stale: Bool
    let fetchedAt: Date?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: weather.icon.symbol).font(.title).foregroundStyle(Palette.ink)
                    Text(verbatim: "\(jsRound(weather.temperature))°").font(.display(34)).foregroundStyle(Palette.ink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: weather.city).font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                        Text(LocalizedStringKey(weather.descriptionKey)).font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
                HStack(spacing: 12) {
                    if let low = weather.tMin, let high = weather.tMax {
                        Text(verbatim: "\(jsRound(low))° / \(jsRound(high))°")
                    }
                    if let rain = weather.precipProb {
                        Label { Text(verbatim: "\(rain)%") } icon: { Image(systemName: "drop") }
                    }
                    Label { Text(verbatim: "\(jsRound(weather.windSpeed)) km/h") } icon: { Image(systemName: "wind") }
                }
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                if let url = URL(string: "https://open-meteo.com/") {
                    // Licenza CC BY 4.0: la fonte va citata.
                    Link(destination: url) { Text("weather.openMeteoCredit").font(.caption) }
                        .tint(Palette.link)
                }
                if stale, let fetchedAt {
                    Text("weather.staleNotice \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .accessibilityIdentifier("weather-card")
    }
}

/// La giornata in tre fasce, come src/components/DayStrip.
struct DayStripView: View {
    let parts: [DayPart]

    var body: some View {
        if parts.contains(where: { $0.temperature != nil }) {
            Card {
                HStack(alignment: .top) {
                    ForEach(parts, id: \.key) { part in
                        VStack(spacing: 4) {
                            Text(part.key.title).font(.caption).foregroundStyle(Palette.muted)
                            // Le fasce passate in grigio, senza trasparenza: sbiadite scenderebbero sotto il contrasto minimo.
                            Image(systemName: part.icon.symbol).foregroundStyle(part.past ? Palette.muted : Palette.ink)
                            Text(verbatim: part.temperature.map { "\(jsRound($0))°" } ?? "–")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(part.past ? Palette.muted : Palette.ink)
                            if let rain = part.precipProb, rain > 0 {
                                Text(verbatim: "\(rain)%").font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .accessibilityIdentifier("day-strip")
        }
    }
}
