import CoreGraphics
import Foundation
import ImageIO

public enum FashnError: Error, CustomStringConvertible {
    case image(String)
    case model(String)

    public var description: String {
        switch self {
        case .image(let text), .model(let text): return text
        }
    }
}

/// Gli ingressi del modello per una coppia persona + capo, più ciò che serve a togliere i bordi dal risultato.
public struct FashnInputs: Sendable {
    /// Tensori in ordine canale-riga-colonna, valori da -1 a 1.
    public let person: [Float]
    public let garment: [Float]
    public let personPose: [Float]
    public let garmentPose: [Float]
    public let category: GarmentCategory
    /// Dove sta la persona dentro il riquadro del modello.
    public let personFrame: Frame
    /// Il disegno della posa, per guardarlo.
    public let personPoseSketch: GrayCanvas
    /// Quanti punti del corpo ha visto Vision, su 18.
    public let bodyPointsFound: Int

    public init(person: [Float], garment: [Float], personPose: [Float], garmentPose: [Float], category: GarmentCategory,
                personFrame: Frame, personPoseSketch: GrayCanvas, bodyPointsFound: Int) {
        self.person = person
        self.garment = garment
        self.personPose = personPose
        self.garmentPose = garmentPose
        self.category = category
        self.personFrame = personFrame
        self.personPoseSketch = personPoseSketch
        self.bodyPointsFound = bodyPointsFound
    }
}

public enum FashnPrepare {
    /// Prepara gli ingressi come `TryOnPipeline.__call__` con `segmentation_free=True`.
    /// - Parameter garmentIsWorn: il capo è addosso a qualcuno nella foto (`garment_photo_type="model"`). L'originale in quel
    ///   caso ritaglia il capo con un modello di segmentazione che qui non c'è (licenza solo ricerca): la foto entra intera,
    ///   con la sua posa.
    public static func inputs(person: CGImage, garment: CGImage, category: GarmentCategory, garmentIsWorn: Bool = false) throws -> FashnInputs {
        let personImage = try preResized(person)
        let garmentImage = try preResized(garment)

        let personKeypoints = try VisionPose.detect(personImage)
        let garmentKeypoints = garmentIsWorn ? try VisionPose.detect(garmentImage) : PoseKeypoints.none
        let personSketch = PoseSketch.draw(personKeypoints, width: personImage.width, height: personImage.height)
        let garmentSketch = PoseSketch.draw(garmentKeypoints, width: garmentImage.width, height: garmentImage.height)

        let personFrame = Frame(sourceWidth: personImage.width, sourceHeight: personImage.height)
        let garmentFrame = Frame(sourceWidth: garmentImage.width, sourceHeight: garmentImage.height)
        return FashnInputs(person: try colorTensor(personImage, frame: personFrame),
                           garment: try colorTensor(garmentImage, frame: garmentFrame),
                           personPose: grayTensor(personSketch, frame: personFrame),
                           garmentPose: grayTensor(garmentSketch, frame: garmentFrame),
                           category: category, personFrame: personFrame,
                           personPoseSketch: personSketch.resizedNearest(width: personFrame.width, height: personFrame.height).padded(to: personFrame),
                           bodyPointsFound: personKeypoints.body.compactMap { $0 }.count)
    }

    /// Il lato lungo a 864 al massimo, su fondo bianco se la foto ha trasparenze (i capi scontornati).
    static func preResized(_ image: CGImage) throws -> CGImage {
        let size = Frame.preResized(width: image.width, height: image.height)
        return try redraw(image, width: size.width, height: size.height, canvasWidth: size.width, canvasHeight: size.height, left: 0, top: 0, white: true)
    }

    /// Ridisegna l'immagine a `width`×`height` dentro una tela, nera fuori dall'immagine.
    static func redraw(_ image: CGImage, width: Int, height: Int, canvasWidth: Int, canvasHeight: Int, left: Int, top: Int, white: Bool) throws -> CGImage {
        guard let context = CGContext(data: nil, width: canvasWidth, height: canvasHeight, bitsPerComponent: 8, bytesPerRow: canvasWidth * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw FashnError.image("tela \(canvasWidth)×\(canvasHeight) non creata")
        }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        // CoreGraphics ha l'origine in basso
        let rect = CGRect(x: left, y: canvasHeight - top - height, width: width, height: height)
        if white {
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(rect)
        }
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        guard let out = context.makeImage() else { throw FashnError.image("immagine non creata") }
        return out
    }

    /// La foto dentro il riquadro del modello, con i bordi neri, come tensore da -1 a 1.
    static func colorTensor(_ image: CGImage, frame: Frame) throws -> [Float] {
        let framed = try redraw(image, width: frame.width, height: frame.height, canvasWidth: frame.targetWidth, canvasHeight: frame.targetHeight,
                                left: frame.left, top: frame.top, white: false)
        return try colorTensor(framed)
    }

    static func colorTensor(_ image: CGImage) throws -> [Float] {
        let width = image.width, height = image.height, plane = width * height
        var bytes = [UInt8](repeating: 0, count: plane * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw FashnError.image("pixel non letti") }
        var out = [Float](repeating: 0, count: plane * 3)
        for i in 0..<plane {
            for c in 0..<3 { out[c * plane + i] = Float(bytes[i * 4 + c]) / 127.5 - 1 }
        }
        return out
    }

    static func grayTensor(_ sketch: GrayCanvas, frame: Frame) -> [Float] {
        sketch.resizedNearest(width: frame.width, height: frame.height).padded(to: frame).pixels.map { Float($0) / 127.5 - 1 }
    }

    /// L'uscita del modello (canale-riga-colonna, da -1 a 1) come immagine, senza i bordi neri della persona.
    public static func image(fromOutput values: [Float], frame: Frame) -> CGImage? {
        let width = frame.targetWidth, height = frame.targetHeight, plane = width * height
        guard values.count >= 3 * plane else { return nil }
        var bytes = [UInt8](repeating: 255, count: frame.width * frame.height * 4)
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                let source = (y + frame.top) * width + x + frame.left
                let target = (y * frame.width + x) * 4
                for c in 0..<3 {
                    let v = values[c * plane + source]
                    bytes[target + c] = UInt8(((v.isNaN ? 0 : min(max(v, -1), 1)) + 1) * 127.5)
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.width * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Una foto da file, già raddrizzata secondo l'orientamento EXIF.
    public static func loadImage(_ url: URL, maxSide: Int = 4096) throws -> CGImage {
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxSide]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw FashnError.image("\(url.lastPathComponent): non si apre")
        }
        return image
    }
}
