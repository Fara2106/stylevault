import CoreGraphics
import FashnKit
import Foundation

/// Un capo da mettere addosso: la sua foto (da solo o indossato da qualcuno) e il tipo.
public struct TryOnGarment: @unchecked Sendable {
    public let photo: CGImage
    public let category: GarmentCategory

    public init(photo: CGImage, category: GarmentCategory) {
        self.photo = photo
        self.category = category
    }
}

/// A che punto è un outfit: una sola frazione per tutti i capi, così la barra non riparte da zero a ogni capo.
public struct OutfitProgress: Equatable, Sendable {
    /// Il capo in lavorazione, da 1.
    public let garment: Int
    public let garments: Int
    public let passesDone: Int
    public let passesTotal: Int

    public init(garment: Int, garments: Int, passesDone: Int, passesTotal: Int) {
        self.garment = garment
        self.garments = garments
        self.passesDone = passesDone
        self.passesTotal = passesTotal
    }

    public var fraction: Double { passesTotal == 0 ? 0 : Double(passesDone) / Double(passesTotal) }
    public var percent: Int { Int((fraction * 100).rounded(.down)) }
}

/// Chi fa il campionamento: il modello vero, o un finto nei test.
public protocol TryOnSampling: Sendable {
    func generate(_ inputs: FashnInputs, steps: Int, seed: UInt64, progress: (FashnProgress) -> Void) throws -> [Float]
}

extension FashnSampler: TryOnSampling {
    public func generate(_ inputs: FashnInputs, steps: Int, seed: UInt64, progress: (FashnProgress) -> Void) throws -> [Float] {
        try generate(inputs, steps: steps, seed: seed, noise: nil, progress: progress)
    }
}

/// Veste una persona con più capi, uno dopo l'altro: il risultato di un capo è la persona del successivo
/// (provato l'11/11 sull'iPhone: maglietta e poi jeans).
public enum OutfitTryOn {
    public typealias Prepare = @Sendable (_ person: CGImage, _ garment: TryOnGarment) async throws -> FashnInputs

    /// La preparazione vera: il capo indossato si isola da solo, poi posa e tensori.
    public static let systemPrepare: Prepare = { person, garment in
        let prepared = await WornGarmentPhoto.prepared(garment.photo, category: garment.category)
        return try FashnPrepare.inputs(person: person, garment: prepared.image, category: garment.category,
                                       garmentIsWorn: prepared.outcome == .notIsolated)
    }

    /// - Parameters:
    ///   - betweenPasses: chiamata dopo ogni passaggio del modello, sul filo che lavora: chi la fornisce può fermarsi lì
    ///     (telefono caldo, app in secondo piano) e la generazione aspetta.
    public static func generate(person: CGImage, garments: [TryOnGarment], steps: Int, seed: UInt64, sampler: any TryOnSampling,
                                prepare: @escaping Prepare = systemPrepare,
                                betweenPasses: @escaping @Sendable () -> Void = {},
                                progress: @escaping @Sendable (OutfitProgress) -> Void = { _ in }) async throws -> CGImage {
        let perGarment = FashnProgress.passes(steps: steps)
        let total = perGarment * garments.count
        var current = person
        for (index, garment) in garments.enumerated() {
            try Task.checkCancellation()
            progress(OutfitProgress(garment: index + 1, garments: garments.count, passesDone: perGarment * index, passesTotal: total))
            let inputs = try await prepare(current, garment)
            let work = Task.detached(priority: .userInitiated) {
                try sampler.generate(inputs, steps: steps, seed: seed &+ UInt64(index)) { value in
                    progress(OutfitProgress(garment: index + 1, garments: garments.count,
                                            passesDone: perGarment * index + value.passesDone, passesTotal: total))
                    betweenPasses()
                }
            }
            let output = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
            guard let image = FashnPrepare.image(fromOutput: output, frame: inputs.personFrame) else {
                throw FashnError.model("uscita del modello non leggibile")
            }
            current = image
        }
        return current
    }
}
