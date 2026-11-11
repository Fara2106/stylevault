import CoreGraphics
import FashnKit
import StyleVaultCore
import Vision

/// Un capo fotografato addosso a qualcuno, pronto per FASHN.
/// La pipeline originale lì ritaglia il capo con un modello di segmentazione a licenza solo ricerca. Senza ritaglio il
/// modello copia anche la pelle di chi indossa il capo (prova dell'11/11 sull'iPhone: braccia e pancia chiare su una persona
/// scura). Qui il capo si isola con lo scontorno di Style Vault (`WornGarment`) e si dà al modello come capo da solo.
public enum WornGarmentPhoto {
    public enum Outcome: Sendable {
        /// Nella foto non c'è una persona: il capo è fotografato da solo.
        case alone
        /// C'era una persona e il capo è stato isolato.
        case isolated
        /// C'era una persona ma il capo non si è riconosciuto: resta la foto intera.
        case notIsolated
    }

    public struct Prepared: @unchecked Sendable {
        /// Il capo isolato su trasparente, oppure la foto com'era.
        public let image: CGImage
        public let outcome: Outcome
        public var isolated: Bool { outcome == .isolated }
    }

    /// C'è una persona nella foto? Stesso controllo di Style Vault (`VNDetectHumanRectanglesRequest`).
    public static func hasPerson(_ photo: CGImage) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let request = VNDetectHumanRectanglesRequest()
            request.upperBodyOnly = false
            try? VNImageRequestHandler(cgImage: photo).perform([request])
            return !(request.results ?? []).isEmpty
        }.value
    }

    static func slot(for category: GarmentCategory) -> String {
        switch category {
        case .tops: return "top"
        case .bottoms: return "bottom"
        case .onePieces: return "dress"
        }
    }

    /// Guarda da sola se il capo è addosso a qualcuno: chi sceglie la foto non deve dirlo.
    public static func prepared(_ photo: CGImage, category: GarmentCategory) async -> Prepared {
        guard await hasPerson(photo) else { return Prepared(image: photo, outcome: .alone) }
        guard let cutout = try? await PersonCutout.cutout(photo),
              let piece = await WornGarment.piece(from: cutout, photo: photo, slot: slot(for: category)) else {
            return Prepared(image: photo, outcome: .notIsolated)
        }
        return Prepared(image: piece.image, outcome: .isolated)
    }
}
