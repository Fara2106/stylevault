import Accelerate
import CoreGraphics
import Foundation

/// Dove il risultato realistico è diverso dalla foto di partenza (stessa
/// geometria, pixel per pixel): è la parte di sopra nuova, che va ridisegnata
/// sopra i pantaloni del collage. CoreGraphics e vImage: gira ovunque.
enum GarmentMask {
    /// Maschera in scala di grigi (bianco = parte nuova) grande come `original`.
    /// - threshold: differenza minima sul canale che cambia di più (0…255).
    /// - rows: righe da tenere (pixel, origine in alto), di solito dal collo alle
    ///   ginocchia; fuori resta nero, così viso e piedi non si toccano mai.
    static func make(original: CGImage, result: CGImage, threshold: UInt8 = 40,
                     rows: ClosedRange<CGFloat>? = nil) -> CGImage {
        let width = original.width, height = original.height
        let a = rgba(original, width: width, height: height)
        let b = rgba(result, width: width, height: height)
        var mask = [UInt8](repeating: 0, count: width * height)
        let firstRow = rows.map { min(height, max(0, Int($0.lowerBound.rounded()))) } ?? 0
        let lastRow = rows.map { min(height - 1, Int($0.upperBound.rounded())) } ?? height - 1
        if firstRow <= lastRow {
            let limit = Int(threshold)
            a.withUnsafeBufferPointer { a in
                b.withUnsafeBufferPointer { b in
                    mask.withUnsafeMutableBufferPointer { mask in
                        for p in (firstRow * width)..<((lastRow + 1) * width) {
                            let i = p * 4
                            let diff = max(abs(Int(a[i]) - Int(b[i])), abs(Int(a[i + 1]) - Int(b[i + 1])),
                                           abs(Int(a[i + 2]) - Int(b[i + 2])))
                            if diff >= limit { mask[p] = 255 }
                        }
                    }
                }
            }
        }
        // Chiusura 5×5 (riempie i buchi dei pixel simili per caso), poi bordo morbido di 2 px
        var scratch = [UInt8](repeating: 0, count: width * height)
        mask.withUnsafeMutableBytes { m in
            scratch.withUnsafeMutableBytes { s in
                var src = vImage_Buffer(data: m.baseAddress, height: vImagePixelCount(height),
                                        width: vImagePixelCount(width), rowBytes: width)
                var tmp = vImage_Buffer(data: s.baseAddress, height: vImagePixelCount(height),
                                        width: vImagePixelCount(width), rowBytes: width)
                vImageMax_Planar8(&src, &tmp, nil, 0, 0, 5, 5, vImage_Flags(kvImageNoFlags))
                vImageMin_Planar8(&tmp, &src, nil, 0, 0, 5, 5, vImage_Flags(kvImageNoFlags))
                vImageBoxConvolve_Planar8(&src, &tmp, nil, 0, 0, 5, 5, 0, vImage_Flags(kvImageEdgeExtend))
            }
        }
        // La sfocatura non deve uscire dalle righe chieste
        if rows != nil {
            scratch.withUnsafeMutableBufferPointer { out in
                // Righe chieste fuori dall'immagine (firstRow > lastRow): tutto nero
                let top = firstRow * width, bottom = max(lastRow + 1, firstRow) * width
                UnsafeMutableBufferPointer(rebasing: out[0..<top]).update(repeating: 0)
                UnsafeMutableBufferPointer(rebasing: out[bottom...]).update(repeating: 0)
            }
        }
        let provider = CGDataProvider(data: Data(scratch) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    /// RGBA8 sRGB della dimensione data (il risultato si porta alla misura della foto).
    private static func rgba(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }
}
