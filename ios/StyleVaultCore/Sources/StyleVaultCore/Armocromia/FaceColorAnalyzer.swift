import CoreGraphics
import Vision

/// Legge pelle, capelli e occhi da una foto, sul dispositivo. Ciò che non trova resta vuoto:
/// la schermata lo fa correggere a mano. Vision non ha i modelli nel simulatore iOS.
public enum FaceColorAnalyzer {
    private static let minimumRegionPixels = 40

    public static func analyze(_ image: CGImage) async throws -> FaceColors {
        let source = ImagePrep.downscaled(image)
        guard let face = try await detectFace(source) else { return FaceColors() }
        let pixels = PixelGrid(source)
        let mask = try? await PersonCutout.cutout(source)
        let maskGrid = mask.map { PixelGrid($0.image) }

        let skinPixels = face.cheeks.flatMap { pixels.disc(center: $0, radius: face.box.width * 0.08) }
        let skin = skinPixels.count >= minimumRegionPixels ? ColorLab.representative(skinPixels) : nil
        return FaceColors(skin: skin,
                          hair: hairColor(face, pixels: pixels, mask: maskGrid, skin: skin),
                          eyes: eyesColor(face, pixels: pixels))
    }

    /// Fascia sopra il viso, solo dentro la persona e scartando ciò che somiglia alla pelle della fronte.
    private static func hairColor(_ face: DetectedFace, pixels: PixelGrid, mask: PixelGrid?, skin: String?) -> String? {
        let skinLab = skin.flatMap { ColorLab.lab(hex: $0) }
        let box = face.box
        let top = max(0, Int(box.minY - box.height * 0.45))
        let bottom = max(0, Int(box.minY + box.height * 0.02))
        let left = max(0, Int(box.minX + box.width * 0.15))
        let right = min(pixels.width - 1, Int(box.maxX - box.width * 0.15))
        guard top < bottom, left < right else { return nil }
        var found: [RGB] = []
        for y in stride(from: top, to: bottom, by: 2) {
            for x in stride(from: left, to: right, by: 2) {
                if let mask, mask.alpha(x: x, y: y) < 128 { continue }
                let color = pixels.color(x: x, y: y)
                if let skinLab, ColorLab.deltaE(ColorLab.lab(color), skinLab) < 18 { continue }
                found.append(color)
            }
        }
        return found.count >= minimumRegionPixels ? ColorLab.representative(found) : nil
    }

    private static func eyesColor(_ face: DetectedFace, pixels: PixelGrid) -> String? {
        let radius = face.irisRadius
        guard radius >= 1.5 else { return nil } // iride troppo piccola per campionare
        let found = face.pupils.flatMap { pixels.disc(center: $0, radius: radius) }
        return found.count >= 12 ? ColorLab.representative(found, trim: 0.35) : nil // via pupilla e riflessi
    }

    private struct DetectedFace {
        let box: CGRect
        let cheeks: [CGPoint]
        let pupils: [CGPoint]
        let irisRadius: Double
    }

    /// Il viso più grande, in pixel con origine in alto a sinistra.
    private static func detectFace(_ image: CGImage) async throws -> DetectedFace? {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectFaceLandmarksRequest()
            try VNImageRequestHandler(cgImage: image).perform([request])
            let results = request.results ?? []
            guard let best = results.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
                  let marks = best.landmarks,
                  let leftPupil = marks.leftPupil, let rightPupil = marks.rightPupil,
                  let lips = marks.outerLips else { return nil }
            let size = CGSize(width: image.width, height: image.height)
            func flipped(_ points: [CGPoint]) -> [CGPoint] { points.map { CGPoint(x: $0.x, y: size.height - $0.y) } }
            func middle(_ points: [CGPoint]) -> CGPoint {
                CGPoint(x: points.map(\.x).reduce(0, +) / CGFloat(max(points.count, 1)),
                        y: points.map(\.y).reduce(0, +) / CGFloat(max(points.count, 1)))
            }
            let pupils = [middle(flipped(leftPupil.pointsInImage(imageSize: size))),
                          middle(flipped(rightPupil.pointsInImage(imageSize: size)))]
            let mouth = middle(flipped(lips.pointsInImage(imageSize: size)))
            let box = VNImageRectForNormalizedRect(best.boundingBox, image.width, image.height)
            let top = CGRect(x: box.minX, y: size.height - box.maxY, width: box.width, height: box.height)
            // Guance: sotto gli occhi, a metà strada dalla bocca.
            let cheeks = pupils.map { CGPoint(x: $0.x, y: ($0.y + mouth.y) / 2) }
            let distance = hypot(pupils[0].x - pupils[1].x, pupils[0].y - pupils[1].y)
            return DetectedFace(box: top, cheeks: cheeks, pupils: pupils, irisRadius: Double(distance) * 0.06)
        }.value
    }
}

/// Pixel RGBA leggibili con origine in alto a sinistra.
private struct PixelGrid {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        data.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: info)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        bytes = data
    }

    func color(x: Int, y: Int) -> RGB {
        let o = (y * width + x) * 4
        return RGB(r: Int(bytes[o]), g: Int(bytes[o + 1]), b: Int(bytes[o + 2]))
    }

    func alpha(x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        return bytes[(y * width + x) * 4 + 3]
    }

    func disc(center: CGPoint, radius: Double) -> [RGB] {
        let (cx, cy) = (Double(center.x), Double(center.y))
        var found: [RGB] = []
        for y in max(0, Int(cy - radius))...max(0, min(height - 1, Int(cy + radius))) {
            for x in max(0, Int(cx - radius))...max(0, min(width - 1, Int(cx + radius))) {
                let (dx, dy) = (Double(x) - cx, Double(y) - cy)
                if dx * dx + dy * dy <= radius * radius { found.append(color(x: x, y: y)) }
            }
        }
        return found
    }
}
