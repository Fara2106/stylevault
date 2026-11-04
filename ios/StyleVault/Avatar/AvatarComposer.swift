import CoreGraphics

/// Disegna una vista dell'avatar: fondo da studio, ombra, persona scontornata
/// e capi scontornati nell'ordine scarpe → pantaloni → top → capospalla.
/// CoreGraphics puro: uguale su iPhone e Mac (dove lo si verifica a occhio).
enum AvatarComposer {
    struct Garment {
        let slot: String
        let cutout: Cutout
    }

    static let drawOrder = ["shoes", "bottom", "top", "outerwear"]

    /// - overlay: immagine grande come `person` ridisegnata attraverso `mask`
    ///   (scala di grigi, bianco = si vede) DOPO scarpe e pantaloni: la parte di
    ///   sopra realistica che copre la vita dei pantaloni.
    static func render(person: Cutout, pose: Pose, garments: [Garment], view: BodyView,
                       overlay: (image: CGImage, mask: CGImage)? = nil) -> CGImage? {
        let width = person.image.width, height = person.image.height
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let H = CGFloat(height)
        // Da rettangolo con origine in alto (Vision, layout) a CoreGraphics (in basso)
        func flipped(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: H - r.maxY, width: r.width, height: r.height) }

        // Fondo da studio come il sito (#F5F0E8 → #EAE2D5)
        let colors = [CGColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1),
                      CGColor(red: 0.918, green: 0.886, blue: 0.835, alpha: 1)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: H), end: .zero, options: [])
        }
        // Ombra a terra sotto i piedi
        let feet = person.bounds.maxY
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.10))
        ctx.fillEllipse(in: flipped(CGRect(x: person.bounds.midX - person.bounds.width * 0.55,
                                           y: feet - person.bounds.height * 0.015,
                                           width: person.bounds.width * 1.1,
                                           height: person.bounds.height * 0.03)))

        ctx.draw(person.image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let body = Silhouette(person.image)
        ctx.interpolationQuality = .high
        for slot in drawOrder {
            for garment in garments where garment.slot == slot {
                guard let piece = garment.cutout.image.cropping(to: garment.cutout.bounds.integral) else { continue }
                if slot == "shoes" {
                    for shoe in GarmentLayout.shoeFrames(pose: pose, bodyBounds: person.bounds, shoe: Silhouette(piece),
                                                         pair: garment.cutout.instanceCount > 1, view: view,
                                                         silhouette: body) {
                        draw(piece, in: flipped(shoe.frame), mirrored: shoe.mirrored, on: ctx)
                    }
                    continue
                }
                guard let frame = GarmentLayout.frame(for: slot, pose: pose, bodyBounds: person.bounds,
                                                      garmentAspect: CGFloat(piece.width) / CGFloat(piece.height),
                                                      view: view, silhouette: body) else { continue }
                ctx.draw(piece, in: flipped(frame))
            }
        }
        if let overlay {
            let full = CGRect(x: 0, y: 0, width: width, height: height)
            ctx.saveGState()
            ctx.clip(to: full, mask: overlay.mask)
            ctx.draw(overlay.image, in: full)
            ctx.restoreGState()
        }
        return ctx.makeImage()
    }

    private static func draw(_ image: CGImage, in rect: CGRect, mirrored: Bool, on ctx: CGContext) {
        guard mirrored else { return ctx.draw(image, in: rect) }
        ctx.saveGState()
        ctx.translateBy(x: rect.maxX + rect.minX, y: 0)
        ctx.scaleBy(x: -1, y: 1)
        ctx.draw(image, in: rect)
        ctx.restoreGState()
    }
}
