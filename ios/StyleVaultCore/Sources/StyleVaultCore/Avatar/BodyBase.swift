import CoreGraphics
import Foundation

/// Il corpo su cui si disegnano i capi. I pantaloni della foto del corpo spuntano attorno a quelli nuovi (tra le
/// gambe, ai lati, sul ginocchio piegato): quando si mette un capo sotto, quelli della foto si tolgono. I pantaloni
/// nuovi scendono sempre dalla vita alle caviglie, quindi dietro non resta scoperto niente.
/// Il sopra non si tocca: senza la maglia della foto resterebbero le mani staccate dal corpo, e colorare braccia e
/// busto "color pelle" è stato provato sul banco del Mac (2026-11-10) e viene peggio delle maniche vere.
/// Se la foto non dà abbastanza (niente fianchi, gambe nude) il corpo resta com'è.
enum BodyBase {
    /// Le zone colore si cercano su una copia piccola: bastano, e il conto resta leggero su una foto da 2048.
    static let analysisMaxSide = 900

    static func prepared(_ person: CGImage, pose: Pose, slots: Set<String>) -> CGImage {
        guard slots.contains("bottom") else { return person }
        let small = ImagePrep.downscaled(person, maxSide: analysisMaxSide)
        let scale = CGFloat(small.width) / CGFloat(person.width)
        let smallPose = Pose(points: pose.points.mapValues { CGPoint(x: $0.x * scale, y: $0.y * scale) })
        let pixels = RGBAPixels(small)
        let subject = PersonCutout.opaqueBounds(small)
        guard !subject.isEmpty, let zones = ColorZones(pixels),
              let regions = WornGarment.regions(slot: "bottom", pose: smallPose, subject: subject),
              let legs = WornGarment.mask(zones, regions: regions) else { return person }
        let w = pixels.width, h = pixels.height

        // Sopra la vita dei pantaloni nuovi resta tutto: lì quelli della foto non sarebbero coperti
        let waist = min(max(0, Int(GarmentLayout.waistY(pose: smallPose, bodyBounds: subject).rounded(.up))), h)
        let hem = min(max(Int(regions.rows.upperBound), waist), h - 1)
        // La pelle non si toglie mai: gambe nude e mani lungo i fianchi restano
        let skin = zones.dominant(in: regions.face, except: nil)
        func isSkin(_ i: Int) -> Bool { skin.map { Int(zones.cluster[i]) == $0 } ?? false }
        var erase = legs
        for i in erase.indices where erase[i] && (i < waist * w || isSkin(i)) { erase[i] = false }
        guard erase.contains(true) else { return person }
        // Lo scontorno sfuma sul bordo: qualche pixel in più, o resta il filo del vecchio orlo
        let edge = 2 + Int((0.004 * subject.height).rounded())
        let wide = Morphology.dilate(erase, width: w, height: h, radius: edge)
        // Quello che resta dei pantaloni in strisce sottili (un'ombra, una piega di un altro colore) va via con loro
        var rest = [Bool](repeating: false, count: w * h)
        for y in waist...hem { for x in 0..<w where zones.opaque[y * w + x] && !erase[y * w + x] { rest[y * w + x] = true } }
        let thin = max(2, Int((0.006 * subject.height).rounded()))
        let solid = Morphology.dilate(Morphology.erode(rest, width: w, height: h, radius: thin), width: w, height: h, radius: thin)
        let near = Morphology.dilate(erase, width: w, height: h, radius: 2 * thin + 1)
        for y in waist...hem {
            for x in 0..<w {
                let i = y * w + x
                if wide[i] && !isSkin(i) { erase[i] = true }
                if skin != nil, rest[i], !solid[i], near[i], !isSkin(i) { erase[i] = true }
            }
        }
        guard erase.contains(true), let hole = layer(mask: erase, width: w, height: h),
              let ctx = CGContext(data: nil, width: person.width, height: person.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return person }
        let frame = CGRect(x: 0, y: 0, width: person.width, height: person.height)
        ctx.interpolationQuality = .high
        ctx.draw(person, in: frame)
        ctx.setBlendMode(.destinationOut)
        ctx.draw(hole, in: frame)
        return ctx.makeImage() ?? person
    }

    /// Un livello grande come la copia piccola, pieno dove c'è la maschera, col bordo sfumato.
    private static func layer(mask: [Bool], width: Int, height: Int) -> CGImage? {
        let soft = Morphology.softened(mask, width: width, height: height)
        var out = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) where soft[i] > 0 { out[i * 4 + 3] = UInt8(255 * soft[i]) }
        guard let provider = CGDataProvider(data: Data(out) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
