import CoreGraphics
import CoreML
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Gli ingressi veri della coppia di prova esportati dal Mac
/// (tools/avatar-realistico/export_bench_inputs.py), in Inputs/ sotto BenchRunner.root.
struct BenchInputs {
    private struct Manifest: Decodable {
        struct Entry: Decodable { let shape: [Int]; let dtype: String }
        let timesteps: [Double]
        let sigmas: [Double]
        let guidance: Float
        let tensors: [String: Entry]
    }

    let timesteps: [Double]
    let sigmas: [Double]
    let guidance: Float
    private let dir: URL
    private let entries: [String: Manifest.Entry]

    static func load() throws -> BenchInputs {
        let dir = BenchRunner.root.appending(path: "Inputs")
        guard let data = try? Data(contentsOf: dir.appending(path: "manifest.json")) else {
            throw BenchError.missingInputs
        }
        let m = try JSONDecoder().decode(Manifest.self, from: data)
        return BenchInputs(timesteps: m.timesteps, sigmas: m.sigmas, guidance: m.guidance, dir: dir, entries: m.tensors)
    }

    func shape(_ name: String) -> [Int] { entries[name]?.shape ?? [] }

    func array(_ name: String) throws -> MLMultiArray {
        guard let entry = entries[name] else { throw BenchError.missingInputs }
        let data = try Data(contentsOf: dir.appending(path: "\(name).bin"))
        let type: MLMultiArrayDataType = entry.dtype == "int32" ? .int32 : .float32
        let array = try MLMultiArray(shape: entry.shape.map { NSNumber(value: $0) }, dataType: type)
        data.withUnsafeBytes { array.dataPointer.copyMemory(from: $0.baseAddress!, byteCount: data.count) }
        return array
    }
}

/// La vista davanti generata davvero sul dispositivo, con gli stessi passi di
/// coreml_pipeline.py: l'immagine si confronta con quella del Mac.
enum BenchGenerator {
    struct Output {
        var image: CGImage
        var png: URL
        var seconds: [(String, Double)]
        var total: Double
    }

    static let latentChannels = 16

    static func run(units: MLComputeUnits, denoiserUnits: MLComputeUnits?,
                    log: @escaping (String) -> Void) async throws -> Output {
        let inputs = try BenchInputs.load()
        var seconds: [(String, Double)] = []
        let start = Date()
        func load(_ name: String) async throws -> MLModel {
            guard let url = BenchRunner.modelURL(name) else { throw BenchError.missingModel(name) }
            let config = MLModelConfiguration()
            config.computeUnits = name == "Denoiser" ? denoiserUnits ?? units : units
            return try await MLModel.load(contentsOf: url, configuration: config)
        }
        func predict(_ model: MLModel, _ values: [String: MLMultiArray]) async throws -> MLFeatureProvider {
            try await model.prediction(from: MLDictionaryFeatureProvider(
                dictionary: values.mapValues { MLFeatureValue(multiArray: $0) }))
        }
        func output(_ p: MLFeatureProvider, _ name: String) throws -> MLMultiArray {
            guard let a = p.featureValue(for: name)?.multiArrayValue else { throw BenchError.missingFeature(name) }
            return a
        }

        // Una rete grande alla volta, liberata appena finito: il picco di memoria
        // resta quello del modello più grande (conta per il 15 Pro e il simulatore)

        // Fase 1: testi, immagine del capo, VAE
        var t0 = Date()
        let texts = ["negative", "caption", "caption_cloth"]
        func hidden(_ model: String, _ prefix: String) async throws -> [String: (values: [Float], tokens: Int, dim: Int)] {
            let m = try await load(model)
            var out: [String: (values: [Float], tokens: Int, dim: Int)] = [:]
            for name in texts {
                let h = try output(await predict(m, ["input_ids": inputs.array("\(prefix)_\(name)")]), "hidden_penultimate")
                out[name] = (BenchRunner.floats(h), h.shape[1].intValue, h.shape[2].intValue)
            }
            return out
        }
        let clipL = try await hidden("TextEncoder", "ids"), clipG = try await hidden("TextEncoder2", "ids2")
        func text(_ name: String) -> [Float] {
            let l = clipL[name]!, g = clipG[name]!
            return TryOnMath.textEmbedding(l.values, lDim: l.dim, g.values, gDim: g.dim,
                                           tokens: l.tokens, width: 4096, zeroTokens: 256)
        }
        let prompt = text("negative") + text("caption")
        let promptCloth = text("caption_cloth")

        let imageEmbeds: [Float] = try await {
            let ie = try await load("ImageEncoder")
            let pixels = try inputs.array("cloth_pixels")
            let black = try MLMultiArray(shape: pixels.shape, dataType: .float32)
            black.dataPointer.initializeMemory(as: Float.self, repeating: 0, count: black.count)
            return try BenchRunner.floats(output(await predict(ie, ["pixel_values": black]), "image_embeds"))
                + BenchRunner.floats(output(await predict(ie, ["pixel_values": pixels]), "image_embeds"))
        }()

        let noiseShape = inputs.shape("noise")                       // [1, 16, h, w]
        let rows = noiseShape[2], cols = noiseShape[3], plane = rows * cols
        let (condition, clothLatent): ([Float], [Float]) = try await {
            let vae = try await load("VAEEncoder")
            func latent(_ name: String) async throws -> [Float] {
                let m = try output(await predict(vae, ["image": inputs.array(name)]), "moments")
                return TryOnMath.vaeLatent(moments: BenchRunner.floats(m), channels: latentChannels, plane: plane)
            }
            let person = try await latent("person"), cloth = try await latent("cloth")
            return (TryOnMath.stackHeight(top: person, bottom: cloth, channels: latentChannels, plane: plane), cloth)
        }()
        seconds.append(("testi + capo + VAE (con caricamento)", Date().timeIntervalSince(t0)))
        log("fase 1: \(fmt(seconds.last!.1)) s — memoria \(fmt(MemorySampler.footprintMB())) MB")

        func array(_ data: [Float], _ shape: [Int]) throws -> MLMultiArray {
            let a = try MLMultiArray(shape: shape.map { NSNumber(value: $0) }, dataType: .float32)
            data.withUnsafeBufferPointer { a.dataPointer.copyMemory(from: $0.baseAddress!, byteCount: $0.count * 4) }
            return a
        }
        let steps = inputs.timesteps.count

        // Fase 2a: la UNet del capo non dipende dai latenti, solo dal passo: le
        // sue feature per tutti i passi si calcolano prima e si tengono in fp16
        t0 = Date()
        var featureShape = (rows: 0, cols: 0)
        // Le feature di ogni passo vanno su file e si rileggono mappate: memoria
        // legata al file, che il sistema scarta e ricarica senza usare lo swap
        let featureDir = FileManager.default.temporaryDirectory.appending(path: "garment-features")
        try? FileManager.default.removeItem(at: featureDir)
        try FileManager.default.createDirectory(at: featureDir, withIntermediateDirectories: true)
        let garmentFeatures: [[String: URL]] = try await {
            let garment = try await load("DenoiserGarment")
            let gStep = try array([0], [1])
            let gInputs: [String: MLMultiArray] = [
                "sample": try array(clothLatent, [1, latentChannels, rows, cols]),
                "timestep": gStep,
                "encoder_hidden_states": try array(promptCloth, [1, promptCloth.count / 4096, 4096])]
            var all: [[String: URL]] = []
            for i in 0..<steps {
                gStep[0] = NSNumber(value: Float(inputs.timesteps[i]))
                let out = try await predict(garment, gInputs)
                var step: [String: URL] = [:]
                for name in out.featureNames where name.hasPrefix("garment_feature_") {
                    let f = try output(out, name)
                    if i == 0, step.isEmpty {
                        featureShape = (f.shape[1].intValue, f.shape[2].intValue)
                        log("uscite UNet capo: \(f.dataType == .float16 ? "fp16" : "fp32"), forma \(f.shape), passi \(f.strides)")
                    }
                    let url = featureDir.appending(path: "\(i)-\(name).f16")
                    try BenchRunner.halves(f).withUnsafeBytes { try Data($0).write(to: url) }
                    step[name] = url
                }
                all.append(step)
                log("UNet capo \(i + 1)/\(steps) — \(fmt(Date().timeIntervalSince(t0))) s")
            }
            return all
        }()
        let gTime = Date().timeIntervalSince(t0)
        log("feature del capo pronte: \(fmt(gTime)) s — memoria \(fmt(MemorySampler.footprintMB())) MB")

        // Fase 2b: la UNet di prova, passo per passo
        t0 = Date()
        var latents = try BenchRunner.floats(inputs.array("noise"))
        latents = TryOnMath.stackHeight(top: latents, bottom: latents, channels: latentChannels, plane: plane)
        var dTime = 0.0, glue = 0.0
        let split = BenchRunner.splitGuidance && BenchRunner.modelURL("Denoiser1") != nil
        try await {
            let denoiser = try await load(split ? "Denoiser1" : "Denoiser")
            log("caricata UNet prova\(split ? " a batch 1" : ""): \(fmt(Date().timeIntervalSince(t0))) s")
            let batch = split ? 1 : 2
            let tokens = prompt.count / 2 / 4096, imageTokens = imageEmbeds.count / 2 / 4096
            let dStep = try array([Float](repeating: 0, count: batch), [batch])
            let shape = [batch, 2 * latentChannels, 2 * rows, cols]
            // Ramo condizionato: unico ingresso nel modo a batch 1, seconda metà altrimenti
            var cond: [String: MLMultiArray] = [
                "sample": try MLMultiArray(shape: shape.map { NSNumber(value: $0) }, dataType: .float32),
                "timestep": dStep,
                "encoder_hidden_states": try array(split ? Array(prompt[(tokens * 4096)...]) : prompt, [batch, tokens, 4096]),
                "image_embeds": try array(split ? Array(imageEmbeds[(imageTokens * 4096)...]) : imageEmbeds,
                                          [batch, imageTokens, 4096])]
            var uncond: [String: MLMultiArray] = [:]
            let featureNames = denoiser.modelDescription.inputDescriptionsByName.keys.filter { $0.hasPrefix("garment_feature_") }
            let featureInputShape = denoiser.modelDescription.inputDescriptionsByName[featureNames.first!]!
                .multiArrayConstraint!.shape
            for name in featureNames {
                let a = try MLMultiArray(shape: featureInputShape, dataType: .float32)
                a.dataPointer.initializeMemory(as: Float.self, repeating: 0, count: a.count)
                cond[name] = a
            }
            if split {
                let zeros = try MLMultiArray(shape: featureInputShape, dataType: .float32)
                zeros.dataPointer.initializeMemory(as: Float.self, repeating: 0, count: zeros.count)
                uncond = cond
                uncond["sample"] = cond["sample"]   // stesso campione, rami diversi solo per testo, immagine e feature
                uncond["encoder_hidden_states"] = try array(Array(prompt[..<(tokens * 4096)]), [1, tokens, 4096])
                uncond["image_embeds"] = try array(Array(imageEmbeds[..<(imageTokens * 4096)]), [1, imageTokens, 4096])
                for name in featureNames { uncond[name] = zeros }
            }
            let n = featureShape.rows * featureShape.cols
            let offset = split ? 0 : 2 * n          // dove inizia il ramo condizionato nell'array delle feature
            for i in 0..<steps {
                let t = Float(inputs.timesteps[i])
                for b in 0..<batch { dStep[b] = NSNumber(value: t) }
                var s0 = Date()
                for name in featureNames {
                    let k = Int(name.dropFirst("garment_feature_".count))!
                    let source = "garment_feature_\(BenchRunner.duplicates[k] ?? k)"
                    guard let url = garmentFeatures[i][source] else { throw BenchError.missingFeature(source) }
                    let d = try Data(contentsOf: url, options: .alwaysMapped)
                    // ramo condizionato [d; d]
                    let target = cond[name]!.dataPointer.assumingMemoryBound(to: Float.self) + offset
                    d.withUnsafeBytes { BenchRunner.halfToFloat($0.bindMemory(to: UInt16.self), into: target) }
                    (target + n).update(from: target, count: n)
                }
                // sample = [latenti; condizione] sui canali, uguale nei due rami della guida
                let p = cond["sample"]!.dataPointer.assumingMemoryBound(to: Float.self)
                let half = latentChannels * 2 * plane
                for b in 0..<batch {
                    latents.withUnsafeBufferPointer { (p + b * 2 * half).update(from: $0.baseAddress!, count: half) }
                    condition.withUnsafeBufferPointer { (p + b * 2 * half + half).update(from: $0.baseAddress!, count: half) }
                }
                glue += Date().timeIntervalSince(s0)

                s0 = Date()
                let noisePred = split
                    ? try BenchRunner.floats(output(await predict(denoiser, uncond), "noise_pred"))
                        + BenchRunner.floats(output(await predict(denoiser, cond), "noise_pred"))
                    : try BenchRunner.floats(output(await predict(denoiser, cond), "noise_pred"))
                dTime += Date().timeIntervalSince(s0)
                let dt = Float(inputs.sigmas[i + 1] - inputs.sigmas[i])
                TryOnMath.eulerStep(&latents, noisePred: noisePred, guidance: inputs.guidance, dt: dt)
                log("passo \(i + 1)/\(steps) — \(fmt(Date().timeIntervalSince(t0))) s")
            }
        }()
        try? FileManager.default.removeItem(at: featureDir)
        seconds += [("UNet capo (\(steps) passi, con caricamento)", gTime),
                    ("UNet prova (\(steps) passi)", dTime), ("feature e ingressi", glue)]
        log("memoria dopo i passi: \(fmt(MemorySampler.footprintMB())) MB")

        // Fase 3: decoder
        t0 = Date()
        let decoder = try await load("VAEDecoder")
        let person = TryOnMath.personLatent(latents, channels: latentChannels, rows: rows, cols: cols)
        let decoded = try output(await predict(decoder, ["latents": array(person, [1, latentChannels, rows, cols])]), "image")
        let height = decoded.shape[2].intValue, width = decoded.shape[3].intValue
        let image = try cgImage(TryOnMath.rgba(BenchRunner.floats(decoded), width: width, height: height),
                                width: width, height: height)
        seconds.append(("decoder (con caricamento)", Date().timeIntervalSince(t0)))
        let png = try save(image)
        return Output(image: image, png: png, seconds: seconds, total: Date().timeIntervalSince(start))
    }

    private static func cgImage(_ px: [UInt8], width: Int, height: Int) throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(px) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw BenchError.image }
        return image
    }

    /// Documents/Output/generata-<cartella modelli>.png, da riprendere sul Mac.
    private static func save(_ image: CGImage) throws -> URL {
        let dir = BenchRunner.root.appending(path: "Output")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "generata-\(BenchRunner.folder).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw BenchError.image }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw BenchError.image }
        return url
    }
}
