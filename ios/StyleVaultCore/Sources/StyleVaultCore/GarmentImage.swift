import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Le immagini di un capo. Niente UIKit: il pacchetto si prova sul Mac, dove Vision gira.
public enum GarmentImage {
    public static let photoMaxSide = 1600
    public static let jpegQuality = 0.85
    /// Il PNG con la trasparenza pesa: l'avatar non chiede di più.
    public static let cutoutMaxSide = 1024
    public static let thumbnailMaxSide = 400

    /// JPEG raddrizzato e ridotto, con la trasparenza su fondo bianco. `nil` se i dati non sono un'immagine.
    public static func prepared(_ data: Data) -> Data? {
        guard let image = decoded(data, maxSide: photoMaxSide),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let frame = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(frame)
        context.draw(image, in: frame)
        guard let flattened = context.makeImage() else { return nil }
        return encoded(flattened, type: .jpeg, quality: jpegQuality)
    }

    public static func thumbnail(_ data: Data, maxSide: Int = thumbnailMaxSide) -> CGImage? {
        decoded(data, maxSide: maxSide)
    }

    /// PNG con sfondo trasparente. `nil` se non trova un soggetto o se Vision non è disponibile.
    public static func cutout(_ data: Data) async -> Data? {
        #if targetEnvironment(simulator)
        // Vision non gira nel simulatore iOS 27: il capo resta senza scontorno.
        return nil
        #else
        await Task.detached(priority: .utility) { () -> Data? in
            guard let image = decoded(data, maxSide: cutoutMaxSide) else { return nil }
            do {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: image)
                try handler.perform([request])
                guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
                // Tutte le istanze: un paio di scarpe sono due soggetti.
                let buffer = try observation.generateMaskedImage(
                    ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false)
                let masked = CIImage(cvPixelBuffer: buffer)
                guard let cgImage = CIContext().createCGImage(masked, from: masked.extent) else { return nil }
                return encoded(cgImage, type: .png, quality: nil)
            } catch {
                return nil
            }
        }.value
        #endif
    }

    /// Decodifica già ridotta e raddrizzata: una foto da 48 MP non entra mai intera in memoria.
    private static func decoded(_ data: Data, maxSide: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: min(maxSide, max(width, height)),
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func encoded(_ image: CGImage, type: UTType, quality: Double?) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return nil
        }
        let options = quality.map { [kCGImageDestinationLossyCompressionQuality: $0] as CFDictionary }
        CGImageDestinationAddImage(destination, image, options)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
