import CoreGraphics

/// Mette insieme la vista realistica: il risultato del modello prende il posto
/// della foto del corpo, sopra si disegnano pantaloni e scarpe del collage e
/// infine si ridisegna la parte di sopra nuova (dal collo alle ginocchia), così
/// l'orlo del maglione copre la vita dei jeans. Usa Vision: si prova su macOS.
enum RealisticComposer {
    /// Top e capospalla li ha già ridisegnati il modello: col collage restano gli altri.
    static func collageGarments(_ garments: [AvatarComposer.Garment]) -> [AvatarComposer.Garment] {
        garments.filter { $0.slot != "top" && $0.slot != "outerwear" }
    }

    /// - original: la foto del corpo data al modello (stessa misura di `realistic`).
    /// - garments: i capi del collage per questa vista (top e capospalla si scartano qui).
    /// - key: chiave dello scontorno del risultato (`realistic-…`).
    static func compose(original: CGImage, realistic: CGImage, garments: [AvatarComposer.Garment],
                        view: BodyView, key: String, cache: CutoutCache = .shared) async throws -> CGImage? {
        let person = try await cache.cutout(image: realistic, key: key, allInstances: false)
        // Senza posa valgono le proporzioni medie di GarmentLayout
        let pose = try await BodyPose.detect(person.image) ?? Pose(points: [:])
        let rows = GarmentLayout.overlayRows(pose: pose, bodyBounds: person.bounds)
        let mask = GarmentMask.make(original: original, result: realistic, rows: rows)
        // Si ridisegna lo scontorno, non il risultato intero: il fondo resta quello da studio
        return AvatarComposer.render(person: person, pose: pose, garments: collageGarments(garments), view: view,
                                     overlay: (image: person.image, mask: mask))
    }
}
