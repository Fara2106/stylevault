import CoreGraphics
import FashnKit
import StyleVaultCore

/// Un capo fotografato addosso a qualcuno, pronto per FASHN.
/// La pipeline originale lì ritaglia il capo con un modello di segmentazione a licenza solo ricerca. Senza ritaglio il
/// modello copia anche la pelle di chi indossa il capo (prova dell'11/11 sull'iPhone: braccia e pancia chiare su una persona
/// scura). Qui il capo si isola con lo scontorno di Style Vault (`WornGarment`) e si dà al modello come capo da solo.
public enum WornGarmentPhoto {
    public struct Prepared: @unchecked Sendable {
        /// Il capo isolato su trasparente, oppure la foto intera se isolarlo non è riuscito.
        public let image: CGImage
        public let isolated: Bool
    }

    static func slot(for category: GarmentCategory) -> String {
        switch category {
        case .tops: return "top"
        case .bottoms: return "bottom"
        case .onePieces: return "dress"
        }
    }

    public static func prepared(_ photo: CGImage, category: GarmentCategory) async -> Prepared {
        guard let cutout = try? await PersonCutout.cutout(photo),
              let piece = await WornGarment.piece(from: cutout, photo: photo, slot: slot(for: category)) else {
            return Prepared(image: photo, isolated: false)
        }
        return Prepared(image: piece.image, isolated: true)
    }
}
