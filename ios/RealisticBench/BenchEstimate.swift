import Foundation

/// Tempo di una chiamata di ciascun modello, in secondi.
struct BenchTimes: Codable {
    var textEncoder: Double
    var textEncoder2: Double
    var imageEncoder: Double
    var vaeEncoder: Double
    var denoiserGarment: Double
    var denoiser: Double
    var vaeDecoder: Double
}

enum BenchDevice: String {
    case iPhone18ProMax = "iPhone 18 Pro Max"
    case iPhone15Pro = "iPhone 15 Pro"
    case iPad = "iPad"
}

enum BenchEstimate {
    /// Vista davanti completa: testi e capo una volta, due codifiche VAE
    /// (persona e capo), a ogni passo UNet del capo + UNet di prova, decodifica.
    static func frontView(_ t: BenchTimes, steps: Int) -> Double {
        let once = t.textEncoder + t.textEncoder2 + t.imageEncoder + 2 * t.vaeEncoder + t.vaeDecoder
        return once + Double(steps) * (t.denoiserGarment + t.denoiser)
    }

    /// Tempo in più della prima esecuzione di ogni modello (preparazione per
    /// GPU/Neural Engine), da pagare una volta dopo l'installazione.
    static func firstRunExtra(first: BenchTimes, steady: BenchTimes) -> Double {
        let f = [first.textEncoder, first.textEncoder2, first.imageEncoder, first.vaeEncoder,
                 first.denoiserGarment, first.denoiser, first.vaeDecoder]
        let s = [steady.textEncoder, steady.textEncoder2, steady.imageEncoder, steady.vaeEncoder,
                 steady.denoiserGarment, steady.denoiser, steady.vaeDecoder]
        return zip(f, s).map { max(0, $0 - $1) }.reduce(0, +)
    }

    /// Soglie del design §6.1: 60 s sul 18 Pro Max, 90 s sul 15 Pro; per l'iPad
    /// (non previsto dal design) la stessa del 18 Pro Max.
    static func passes(seconds: Double, device: BenchDevice) -> Bool {
        seconds <= limit(device)
    }

    static func limit(_ device: BenchDevice) -> Double {
        switch device {
        case .iPhone18ProMax: 60
        case .iPhone15Pro: 90
        case .iPad: 60
        }
    }
}
