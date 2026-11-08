import CoreGraphics
import CoreImage
import Vision

public struct Cutout: @unchecked Sendable {
    /// RGBA con sfondo trasparente, stesse dimensioni dell'immagine di partenza.
    public let image: CGImage
    /// Riquadro del soggetto in pixel (origine in alto a sinistra).
    public let bounds: CGRect
    /// Quanti soggetti ha trovato Vision (per la persona: 1 atteso).
    public let instanceCount: Int

    public init(image: CGImage, bounds: CGRect, instanceCount: Int) {
        self.image = image
        self.bounds = bounds
        self.instanceCount = instanceCount
    }
}

public enum CutoutError: Error, Equatable {
    case noSubject
}

/// Scontorno con "stacca il soggetto" di iOS (VNGenerateForegroundInstanceMaskRequest).
public enum PersonCutout {
    /// - allInstances: false per la persona (tiene il soggetto più grande),
    ///   true per i capi (un paio di scarpe sono due soggetti).
    public static func cutout(_ image: CGImage, allInstances: Bool = false) async throws -> Cutout {
        try await Task.detached(priority: .userInitiated) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: image)
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
                throw CutoutError.noSubject
            }
            let instances = allInstances
                ? observation.allInstances
                : IndexSet(integer: largestInstance(in: observation))
            let buffer = try observation.generateMaskedImage(
                ofInstances: instances, from: handler, croppedToInstancesExtent: false
            )
            let ciImage = CIImage(cvPixelBuffer: buffer)
            guard let masked = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
                throw CutoutError.noSubject
            }
            let bounds = opaqueBounds(masked)
            guard !bounds.isEmpty else { throw CutoutError.noSubject }
            return Cutout(image: masked, bounds: bounds, instanceCount: observation.allInstances.count)
        }.value
    }

    /// Quante persone ci sono nella foto (corpo intero o parziale), senza i passanti piccoli sullo sfondo.
    public static func peopleCount(_ image: CGImage) async throws -> Int {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectHumanRectanglesRequest()
            request.upperBodyOnly = false
            try VNImageRequestHandler(cgImage: image).perform([request])
            return countedPeople(heights: (request.results ?? []).map { Double($0.boundingBox.height) })
        }.value
    }

    /// Per strada dietro c'è quasi sempre qualcuno: conta solo chi è alto almeno metà della persona principale.
    /// Chi sta accanto, anche un passo indietro, resta sopra la metà (coppia di prova: 0,53 accanto a 0,61);
    /// un passante lontano no (0,30 accanto a 0,93).
    static let backgroundPersonRatio = 0.5

    static func countedPeople(heights: [Double]) -> Int {
        guard let tallest = heights.max() else { return 0 }
        return heights.filter { $0 >= tallest * backgroundPersonRatio }.count
    }

    /// Etichetta del soggetto con più pixel nella maschera a bassa risoluzione.
    private static func largestInstance(in observation: VNInstanceMaskObservation) -> Int {
        let mask = observation.instanceMask
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        let base = CVPixelBufferGetBaseAddress(mask)!.assumingMemoryBound(to: UInt8.self)
        var counts = [Int: Int]()
        for y in 0..<height {
            for x in 0..<width {
                let label = Int(base[y * rowBytes + x])
                if label != 0 { counts[label, default: 0] += 1 }
            }
        }
        return counts.max { $0.value < $1.value }?.key ?? observation.allInstances.first!
    }

    /// Frazione di pixel trasparenti (alpha < 10%).
    static func transparentFraction(_ image: CGImage) -> Double {
        let alpha = alphaChannel(image)
        let transparent = alpha.pixels.reduce(0) { $0 + ($1 < 26 ? 1 : 0) }
        return Double(transparent) / Double(max(alpha.pixels.count, 1))
    }

    /// Riquadro dei pixel visibili, in pixel con origine in alto a sinistra.
    static func opaqueBounds(_ image: CGImage) -> CGRect {
        let alpha = alphaChannel(image)
        var minX = alpha.width, minY = alpha.height, maxX = -1, maxY = -1
        for y in 0..<alpha.height {
            for x in 0..<alpha.width where alpha.pixels[y * alpha.width + x] >= 26 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    static func alphaChannel(_ image: CGImage) -> (pixels: [UInt8], width: Int, height: Int) {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        pixels.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return (pixels, width, height)
    }
}
