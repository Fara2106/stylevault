import Foundation

/// I conti della generazione che non sono reti neurali, come in
/// tryon_pipeline_full_cat.py e tools/avatar-realistico/coreml_pipeline.py.
/// Tensori come [Float] piatti in ordine C (ultimo asse più veloce).
enum BenchMath {
    // Normalizzazione dei latenti del VAE
    static let vaeScale: Float = 1.5305
    static let vaeShift: Float = 0.0609

    /// CLIP-L e CLIP-G affiancati per token, allargati a `width` e seguiti da
    /// `zeroTokens` token a zero (il ramo T5 che Mobile-VTON non carica).
    static func textEmbedding(_ l: [Float], lDim: Int, _ g: [Float], gDim: Int,
                              tokens: Int, width: Int, zeroTokens: Int) -> [Float] {
        var out = [Float](repeating: 0, count: (tokens + zeroTokens) * width)
        for t in 0..<tokens {
            for j in 0..<lDim { out[t * width + j] = l[t * lDim + j] }
            for j in 0..<gDim { out[t * width + lDim + j] = g[t * gDim + j] }
        }
        return out
    }

    /// Media della distribuzione del VAE (prima metà dei canali), normalizzata.
    static func vaeLatent(moments: [Float], channels: Int, plane: Int) -> [Float] {
        moments[0..<(channels * plane)].map { ($0 - vaeShift) * vaeScale }
    }

    /// Due tensori [C, h, w] impilati in altezza → [C, 2h, w].
    static func stackHeight(top: [Float], bottom: [Float], channels: Int, plane: Int) -> [Float] {
        var out = [Float]()
        out.reserveCapacity(2 * channels * plane)
        for c in 0..<channels {
            out += top[(c * plane)..<((c + 1) * plane)]
            out += bottom[(c * plane)..<((c + 1) * plane)]
        }
        return out
    }

    /// Guida (incondizionato + g·(condizionato − incondizionato)) e passo di
    /// Eulero del FlowMatch: latents += dt · guidato, con dt = σ(i+1) − σ(i).
    static func eulerStep(_ latents: inout [Float], noisePred: [Float], guidance: Float, dt: Float) {
        let n = latents.count
        noisePred.withUnsafeBufferPointer { p in
            latents.withUnsafeMutableBufferPointer { l in
                for i in 0..<n {
                    let u = p[i], c = p[n + i]
                    l[i] += dt * (u + guidance * (c - u))
                }
            }
        }
    }

    /// Metà di sopra dei latenti impilati (la persona) pronta per il decoder.
    static func personLatent(_ latents: [Float], channels: Int, rows: Int, cols: Int) -> [Float] {
        let plane = rows * cols
        var out = [Float]()
        out.reserveCapacity(channels * plane)
        for c in 0..<channels {
            let start = c * 2 * plane
            out += latents[start..<(start + plane)].map { $0 / vaeScale + vaeShift }
        }
        return out
    }

    /// Una feature della UNet del capo [1, rows, cols] nell'ingresso della UNet
    /// di prova [2, 2·rows, cols]: ramo incondizionato a zero, ramo condizionato [d; d].
    static func garmentFeature(_ d: UnsafePointer<Float>, rows: Int, cols: Int, into dst: UnsafeMutablePointer<Float>) {
        let n = rows * cols
        dst.update(repeating: 0, count: 2 * n)
        (dst + 2 * n).update(from: d, count: n)
        (dst + 3 * n).update(from: d, count: n)
    }

    static func garmentFeature(_ d: [Float], rows: Int, cols: Int, into dst: UnsafeMutablePointer<Float>) {
        d.withUnsafeBufferPointer { garmentFeature($0.baseAddress!, rows: rows, cols: cols, into: dst) }
    }

    /// Uscita del decoder [3, H, W] in [-1, 1] → pixel RGBA.
    static func rgba(_ image: [Float], width: Int, height: Int) -> [UInt8] {
        let plane = width * height
        var px = [UInt8](repeating: 255, count: plane * 4)
        for i in 0..<plane {
            for ch in 0..<3 {
                let v = min(max(image[ch * plane + i] / 2 + 0.5, 0), 1)
                px[i * 4 + ch] = UInt8((v * 255).rounded())
            }
        }
        return px
    }
}
