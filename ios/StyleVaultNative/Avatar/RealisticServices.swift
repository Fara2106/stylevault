import CoreGraphics
import CoreML
import FashnKit
import FashnWorn
import Foundation
import StyleVaultCore
import SwiftUI
import UIKit

/// Perché la generazione è ferma.
enum RealisticPause: Equatable, Sendable {
    /// iOS segnala che il dispositivo è caldo: si aspetta che si raffreddi.
    case heat
    /// L'app non è in primo piano: lì iOS non lascia usare la GPU.
    case background
}

struct RealisticProgress: Equatable, Sendable {
    let fraction: Double
    /// Il capo in lavorazione, da 1.
    let garment: Int
    let garments: Int
    var pause: RealisticPause?

    var percent: Int { Int((min(max(fraction, 0), 1) * 100).rounded(.down)) }
}

enum RealisticError: Error {
    case unavailable, unreadablePhoto
}

/// La versione realistica di "Vedilo addosso": un'immagine generata sul dispositivo con FASHN VTON v1.5 (Apache 2.0).
/// Le foto non escono dal telefono.
protocol RealisticGenerating: Sendable {
    /// Falso se il dispositivo non regge il modello o il modello non è nell'app: la funzione non si mostra.
    var isAvailable: Bool { get }
    func generate(body: Data, bodyKey: String, pieces: [RealisticPlan.Piece],
                  progress: @escaping @Sendable (RealisticProgress) -> Void) async throws -> CGImage
}

struct SystemRealisticGenerator: RealisticGenerating {
    /// Provati l'11/11/2026 sull'iPhone 18 Pro Max: 20 passi tengono le trame, circa 70 s a capo.
    static let steps = 20
    /// Sotto gli 8 GB il modello non è mai stato provato: meglio non offrirlo che chiudersi a metà.
    /// Un dispositivo «da 8 GB» ne dichiara circa 7,5 e uno «da 6 GB» meno di 6: la soglia sta in mezzo.
    static let minimumMemory: UInt64 = 13 * 1_073_741_824 / 2

    static var modelURL: URL? { Bundle.main.url(forResource: "FashnTryOn", withExtension: "mlmodelc") }

    static func supports(memory: UInt64, hasModel: Bool, systemIsRecentEnough: Bool) -> Bool {
        hasModel && systemIsRecentEnough && memory >= minimumMemory
    }

    var isAvailable: Bool {
        // Il modello convertito chiede iOS 18
        guard #available(iOS 18, *) else { return false }
        return Self.supports(memory: ProcessInfo.processInfo.physicalMemory, hasModel: Self.modelURL != nil, systemIsRecentEnough: true)
    }

    func generate(body: Data, bodyKey: String, pieces: [RealisticPlan.Piece],
                  progress: @escaping @Sendable (RealisticProgress) -> Void) async throws -> CGImage {
        guard isAvailable, let modelURL = Self.modelURL else { throw RealisticError.unavailable }
        guard let photo = ImagePrep.decodedForAnalysis(body) else { throw RealisticError.unreadablePhoto }
        progress(RealisticProgress(fraction: 0, garment: 1, garments: pieces.count))

        // La persona occupa spesso una parte piccola della foto: al modello va il suo riquadro
        let cache = CutoutCache.shared
        let bounds = (try? await cache.cutout(image: photo, key: bodyKey, allInstances: false))?.bounds ?? .zero
        let person = PersonFraming.cropped(photo, around: bounds)

        var garments: [TryOnGarment] = []
        for piece in pieces {
            guard let image = ImagePrep.decodedForAnalysis(piece.photo) else { throw RealisticError.unreadablePhoto }
            // Come l'avatar a collage: il capo scontornato, e solo il capo se nella foto è addosso a qualcuno
            var garment = image
            if let cutout = try? await cache.cutout(image: image, key: piece.key, allInstances: true) {
                garment = await cache.piece(photo: image, cutout: cutout, key: piece.key, slot: piece.slot)?.image ?? cutout.image
            }
            garments.append(TryOnGarment(photo: garment, category: piece.category))
        }

        // Il modello si carica a ogni generazione e si lascia andare alla fine: tenerlo occuperebbe 700 MB a riposo
        let sampler = try await Task.detached(priority: .userInitiated) { try FashnSampler(modelURL: modelURL) }.value
        let pauses = GenerationPauses()
        let last = LastProgress()
        return try await OutfitTryOn.generate(
            person: person, garments: garments, steps: Self.steps, seed: UInt64.random(in: 0...UInt64.max), sampler: sampler,
            betweenPasses: {
                pauses.waitIfNeeded { reason in
                    if var value = last.value {
                        value.pause = reason
                        progress(value)
                    }
                }
            },
            progress: { value in
                let mapped = RealisticProgress(fraction: value.fraction, garment: value.garment, garments: value.garments)
                last.value = mapped
                progress(mapped)
            })
    }
}

/// L'ultimo avanzamento, per ripeterlo con il motivo della pausa.
private final class LastProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: RealisticProgress?
    var value: RealisticProgress? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

/// Ferma la generazione tra un passaggio e l'altro quando il dispositivo è caldo o l'app non è in primo piano.
/// Provato l'11/11/2026: dalla seconda generazione di fila iOS segnala «caldo»; fuori dal primo piano la GPU non lavora.
final class GenerationPauses: @unchecked Sendable {
    private let lock = NSLock()
    private var away = false
    private var tokens: [NSObjectProtocol] = []
    private let thermalState: @Sendable () -> ProcessInfo.ThermalState
    private let sleep: @Sendable (TimeInterval) -> Void

    init(thermalState: @escaping @Sendable () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState },
         sleep: @escaping @Sendable (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }) {
        self.thermalState = thermalState
        self.sleep = sleep
        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.setAway(true)
        })
        tokens.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.setAway(false)
        })
    }

    deinit { tokens.forEach(NotificationCenter.default.removeObserver) }

    func setAway(_ value: Bool) { lock.withLock { away = value } }

    var reason: RealisticPause? {
        if lock.withLock({ away }) { return .background }
        return thermalState().rawValue >= ProcessInfo.ThermalState.serious.rawValue ? .heat : nil
    }

    /// Aspetta finché c'è un motivo per fermarsi. `report` riceve il motivo quando cambia e `nil` quando si riparte.
    func waitIfNeeded(report: (RealisticPause?) -> Void) {
        var current: RealisticPause?
        while let reason, !Task.isCancelled {
            if reason != current {
                current = reason
                report(reason)
            }
            sleep(1)
        }
        if current != nil { report(nil) }
    }
}

#if DEBUG
/// Sul simulatore il modello non gira: per i test UI, solo con `-SVFakeTryOn`. Fa scorrere la barra e restituisce la foto.
/// Con `-SVFakeTryOnSlow` dura abbastanza da poter annullare o chiudere a metà anche su un Mac lento.
struct FakeRealisticGenerator: RealisticGenerating {
    private struct NotAPhoto: Error {}

    private var pace: Duration {
        ProcessInfo.processInfo.arguments.contains("-SVFakeTryOnSlow") ? .milliseconds(1500) : .milliseconds(250)
    }

    var isAvailable: Bool { true }

    func generate(body: Data, bodyKey: String, pieces: [RealisticPlan.Piece],
                  progress: @escaping @Sendable (RealisticProgress) -> Void) async throws -> CGImage {
        guard let image = ImagePrep.decodedForAnalysis(body) else { throw NotAPhoto() }
        let count = max(pieces.count, 1), ticks = 12
        for garment in 1...count {
            for tick in 0...ticks {
                try Task.checkCancellation()
                progress(RealisticProgress(fraction: (Double(garment - 1) + Double(tick) / Double(ticks)) / Double(count),
                                           garment: garment, garments: count))
                try await Task.sleep(for: pace)
            }
        }
        return image
    }
}
#endif

private struct RealisticGeneratorKey: EnvironmentKey {
    static let defaultValue: any RealisticGenerating = SystemRealisticGenerator()
}

extension EnvironmentValues {
    var realisticGenerator: any RealisticGenerating {
        get { self[RealisticGeneratorKey.self] }
        set { self[RealisticGeneratorKey.self] = newValue }
    }
}
