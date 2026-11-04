import Foundation
import CoreGraphics
import ImageIO

/// Ingressi del modello di prova virtuale, identici a quelli di Python (`common.py`, DINOv2, FlowMatch).
/// Solo Foundation, CoreGraphics, ImageIO: compila anche su macOS.
enum TryOnInputs {
    static let width = 768, height = 1024

    private static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    // MARK: - Decodifica con EXIF

    /// Decodifica una foto applicando l'orientamento EXIF (un CGImage non ce l'ha).
    static func image(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(w, h),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: - Bordo 3:4

    /// Come PIL `ImageOps.pad(img, (768, 1024), color=white)`: adatta mantenendo le proporzioni,
    /// centra, bordo bianco. `content` è dove sta la foto, in pixel con origine in alto a sinistra.
    static func pad3x4(_ image: CGImage) -> (image: CGImage, content: CGRect) {
        let w = Double(image.width), h = Double(image.height)
        let imRatio = w / h
        let target = Double(width) / Double(height)
        var rw = width, rh = height
        if imRatio > target {
            rh = Int((Double(width) / imRatio).rounded(.toNearestOrEven))
        } else if imRatio < target {
            rw = Int((Double(height) * imRatio).rounded(.toNearestOrEven))
        }
        rw = max(1, min(width, rw)); rh = max(1, min(height, rh))
        let x = (width - rw) / 2, y = (height - rh) / 2
        let ctx = makeContext(width: width, height: height)
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.interpolationQuality = .high
        // CoreGraphics ha l'origine in basso: si capovolge la y.
        ctx.draw(image, in: CGRect(x: x, y: height - y - rh, width: rw, height: rh))
        return (ctx.makeImage()!, CGRect(x: x, y: y, width: rw, height: rh))
    }

    /// Ritaglia il risultato (768×1024) sul rettangolo della foto e lo riporta alla dimensione di partenza.
    static func unpad(_ result: CGImage, content: CGRect, to size: CGSize) -> CGImage {
        let sx = Double(result.width) / Double(width), sy = Double(result.height) / Double(height)
        let rect = CGRect(x: content.minX * sx, y: content.minY * sy,
                          width: content.width * sx, height: content.height * sy).integral
        let cropped = result.cropping(to: rect) ?? result
        let ctx = makeContext(width: max(1, Int(size.width)), height: max(1, Int(size.height)))
        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        return ctx.makeImage()!
    }

    // MARK: - Tensori

    /// Python `to_model`: (pixel / 127,5 − 1), CHW, RGB, da un'immagine già 768×1024. [3, 1024, 768].
    static func modelTensor(_ image: CGImage) -> [Float] {
        let ctx = makeContext(width: width, height: height)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return planar(ctx, x: 0, y: 0, w: width, h: height) { c, _ in Float(c) / 127.5 - 1 }
    }

    /// DINOv2: lato corto a 256 (bicubico/alta qualità), ritaglio centrale 224, ÷255, media e dev. std ImageNet.
    /// [3, 224, 224].
    static func dinoPixels(_ image: CGImage) -> [Float] {
        let short = 256, crop = 224
        let w = image.width, h = image.height
        var nw = short, nh = short
        if w <= h { nh = max(short, Int(Double(short) * Double(h) / Double(w))) }
        else { nw = max(short, Int(Double(short) * Double(w) / Double(h))) }
        let ctx = makeContext(width: nw, height: nh)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        let top = (nh - crop) / 2, left = (nw - crop) / 2   // divisione intera, come transformers
        let mean: [Float] = [0.485, 0.456, 0.406]
        let std: [Float] = [0.229, 0.224, 0.225]
        return planar(ctx, x: left, y: top, w: crop, h: crop) { c, ch in
            (Float(c) / 255 - mean[ch]) / std[ch]
        }
    }

    // MARK: - Scheduler

    /// diffusers `FlowMatchEulerDiscreteScheduler`: `shifted(s) = shift·s / (1 + (shift−1)·s)`,
    /// `t_i = linspace(1, shifted(1/1000), steps)`, `sigma_i = shifted(t_i)` più lo 0 finale, `timesteps = sigma·1000`.
    static func schedule(steps: Int, shift: Double) -> (timesteps: [Double], sigmas: [Double]) {
        func shifted(_ s: Double) -> Double { shift * s / (1 + (shift - 1) * s) }
        let start = 1.0, end = shifted(1.0 / 1000.0)
        var sigmas = (0..<steps).map { i -> Double in
            let t = steps == 1 ? start : start + (end - start) * Double(i) / Double(steps - 1)
            return shifted(t)
        }
        let timesteps = sigmas.map { $0 * 1000 }
        sigmas.append(0)
        return (timesteps, sigmas)
    }

    // MARK: - Rumore

    /// Gaussiana N(0,1) riproducibile: SplitMix64 + Box–Muller.
    static func noise(count: Int, seed: UInt64) -> [Float] {
        var state = seed
        func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        func uniform() -> Double { (Double(next() >> 11) + 1) / 9007199254740993.0 } // (0, 1]
        var out = [Float](repeating: 0, count: count)
        var i = 0
        while i < count {
            let r = (-2 * log(uniform())).squareRoot()
            let a = 2 * Double.pi * uniform()
            out[i] = Float(r * cos(a)); i += 1
            if i < count { out[i] = Float(r * sin(a)); i += 1 }
        }
        return out
    }

    // MARK: - Utilità

    private static func makeContext(width: Int, height: Int) -> CGContext {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    }

    /// Legge un RGBA8 (riga 0 = alto) e lo mette in piani R, G, B.
    private static func planar(_ ctx: CGContext, x: Int, y: Int, w: Int, h: Int,
                               _ f: (UInt8, Int) -> Float) -> [Float] {
        let bytes = ctx.data!.assumingMemoryBound(to: UInt8.self)
        let stride = ctx.bytesPerRow
        var out = [Float](repeating: 0, count: 3 * w * h)
        out.withUnsafeMutableBufferPointer { o in
            for ch in 0..<3 {
                let base = ch * w * h
                for row in 0..<h {
                    let src = bytes + (y + row) * stride + x * 4 + ch
                    let dst = base + row * w
                    for col in 0..<w { o[dst + col] = f(src[col * 4], ch) }
                }
            }
        }
        return out
    }
}
