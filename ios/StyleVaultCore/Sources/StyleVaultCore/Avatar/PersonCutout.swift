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
    ///   true per i capi (un paio di scarpe sono due soggetti; vedi `garmentInstances`).
    public static func cutout(_ image: CGImage, allInstances: Bool = false) async throws -> Cutout {
        try await Task.detached(priority: .userInitiated) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: image)
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
                throw CutoutError.noSubject
            }
            let instances = allInstances
                ? garmentInstances(in: observation)
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
            // Per un capo contano i soggetti tenuti (un paio di scarpe si disegna diverso da una scarpa sola).
            return Cutout(image: masked, bounds: bounds,
                          instanceCount: allInstances ? instances.count : observation.allInstances.count)
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
        instanceBoxes(in: observation).max { $0.pixels < $1.pixels }?.label ?? observation.allInstances.first!
    }

    /// I soggetti da tenere per un capo. Un paio di scarpe o una collana a più fili sono più soggetti, e si tengono
    /// tutti. Ma se un soggetto sta tutto dentro la foto, quelli tagliati da almeno due lati sono lo sfondo
    /// (tazzina nell'angolo accanto agli occhiali): si scartano.
    public static func garmentInstances(in observation: VNInstanceMaskObservation) -> IndexSet {
        IndexSet(keptGarmentLabels(instanceBoxes(in: observation)))
    }

    struct InstanceBox: Equatable {
        let label: Int
        let pixels: Int
        /// Quanti lati della foto tocca (0-4).
        let edges: Int
    }

    static func keptGarmentLabels(_ boxes: [InstanceBox]) -> [Int] {
        guard boxes.contains(where: { $0.edges == 0 }) else { return boxes.map(\.label) }
        return boxes.filter { $0.edges < 2 }.map(\.label)
    }

    private static func instanceBoxes(in observation: VNInstanceMaskObservation) -> [InstanceBox] {
        let mask = observation.instanceMask
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        let base = CVPixelBufferGetBaseAddress(mask)!.assumingMemoryBound(to: UInt8.self)
        var counts = [Int: Int]()
        var sides = [Int: Set<Int>]()  // 0 sinistra, 1 sopra, 2 destra, 3 sotto
        for y in 0..<height {
            for x in 0..<width {
                let label = Int(base[y * rowBytes + x])
                guard label != 0 else { continue }
                counts[label, default: 0] += 1
                if x == 0 { sides[label, default: []].insert(0) }
                if y == 0 { sides[label, default: []].insert(1) }
                if x == width - 1 { sides[label, default: []].insert(2) }
                if y == height - 1 { sides[label, default: []].insert(3) }
            }
        }
        return counts.keys.sorted().map { InstanceBox(label: $0, pixels: counts[$0]!, edges: sides[$0]?.count ?? 0) }
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
