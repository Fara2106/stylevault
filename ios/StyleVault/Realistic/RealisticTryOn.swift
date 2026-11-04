import CoreGraphics
import CoreML
import Foundation

/// Avanzamento vero della generazione: `fraction` da 0 a 1 (mai indietro, finisce a 1)
/// e quante delle `modelCount` reti sono già caricate. Al primo uso caricare una rete
/// prepara il Neural Engine e dura minuti: ogni rete caricata manda un aggiornamento.
struct TryOnProgress: Equatable {
    /// Reti che il motore carica in una generazione.
    static let modelCount = 7
    let fraction: Double
    var loaded: Int = 0
}

protocol RealisticTryOn: Sendable {
    /// person e garment come arrivano (qualsiasi proporzione); il risultato ha la dimensione di person.
    func generate(person: CGImage, garment: CGImage, item: AvatarItem,
                  progress: @Sendable (TryOnProgress) -> Void) async throws -> CGImage
}

enum TryOnError: LocalizedError {
    /// loadFailed: il modello compilato c'è ma Core ML non lo carica (file rovinato).
    case missingModel(String), loadFailed(String), missingOutput(String), image, tokenizer
    var errorDescription: String? {
        switch self {
        case .missingModel(let n): "Manca il modello \(n)"
        case .loadFailed(let n): "Il modello \(n) non si carica"
        case .missingOutput(let n): "Il modello non ha dato \(n)"
        case .image: "Immagine non valida"
        case .tokenizer: "Tokenizzatore non caricato"
        }
    }
}

/// Mobile-VTON su Core ML: stesse fasi di coreml_pipeline.py (e del banco RealisticBench),
/// con ingressi veri al posto dei file esportati. Una rete grande alla volta.
struct MobileVTONTryOn: RealisticTryOn {
    static let steps = 10
    static let shift = 3.0
    static let guidance: Float = 2.5
    static let channels = 16
    private static let textWidth = 4096

    private let models: @Sendable (String) -> URL?
    private let tokenizer: (vocab: URL, merges: URL)
    private let noise: [Float]?
    private let seed: UInt64
    private let units: MLComputeUnits
    private let denoiserUnits: MLComputeUnits
    private let workDirectory: URL

    init(models: @escaping @Sendable (String) -> URL?, tokenizer: (vocab: URL, merges: URL),
         noise: [Float]? = nil, seed: UInt64 = 42,
         units: MLComputeUnits = .cpuAndNeuralEngine, denoiserUnits: MLComputeUnits = .cpuAndGPU,
         workDirectory: URL = FileManager.default.temporaryDirectory) {
        self.models = models; self.tokenizer = tokenizer; self.noise = noise; self.seed = seed
        self.units = units; self.denoiserUnits = denoiserUnits; self.workDirectory = workDirectory
    }

    func generate(person: CGImage, garment: CGImage, item: AvatarItem,
                  progress: @Sendable (TryOnProgress) -> Void) async throws -> CGImage {
        let out = try await generatePadded(person: person, garment: garment, item: item, progress: progress)
        return TryOnInputs.unpad(out.result, content: out.content,
                                 to: CGSize(width: person.width, height: person.height))
    }

    /// Il risultato 768×1024 con il bordo, e dove sta la foto al suo interno.
    func generatePadded(person: CGImage, garment: CGImage, item: AvatarItem,
                        progress: @Sendable (TryOnProgress) -> Void) async throws
        -> (result: CGImage, content: CGRect) {
        var percent = 0, loaded = 0
        func send() { progress(TryOnProgress(fraction: Double(percent) / 100, loaded: loaded)) }
        func advance(_ by: Int) { percent += by; send() }
        /// Carica una rete e lo dice (la barra non resta ferma mentre Core ML la prepara).
        func load(_ name: String, _ units: MLComputeUnits) async throws -> MLModel {
            let model = try await self.load(name, units)
            loaded += 1
            send()
            return model
        }

        let (personPadded, content) = TryOnInputs.pad3x4(person)
        let garmentPadded = TryOnInputs.pad3x4(garment).image
        let personTensor = TryOnInputs.modelTensor(personPadded)
        let garmentTensor = TryOnInputs.modelTensor(garmentPadded)
        let dino = TryOnInputs.dinoPixels(garmentPadded)

        let rows = TryOnInputs.height / 8, cols = TryOnInputs.width / 8, plane = rows * cols
        let latentCount = Self.channels * plane
        let noiseValues = noise ?? TryOnInputs.noise(count: latentCount, seed: seed)
        guard noiseValues.count == latentCount else { throw TryOnError.image }
        let (timesteps, sigmas) = TryOnInputs.schedule(steps: Self.steps, shift: Self.shift)

        // Fase 1: testi, immagine del capo, VAE
        let texts = [GarmentCaption.negative, GarmentCaption.person(item), GarmentCaption.cloth(item)]
        let prompt: [Float], promptCloth: [Float]
        do {
            let l = try await hidden(load("TextEncoder", units), pad: "<|endoftext|>", texts)
            let g = try await hidden(load("TextEncoder2", units), pad: "!", texts)
            func text(_ i: Int) -> [Float] {
                TryOnMath.textEmbedding(l[i].values, lDim: l[i].dim, g[i].values, gDim: g[i].dim,
                                        tokens: l[i].tokens, width: Self.textWidth, zeroTokens: 256)
            }
            prompt = text(0) + text(1)
            promptCloth = text(2)
        }
        let imageEmbeds: [Float]
        do {
            let ie = try await load("ImageEncoder", units)
            let shape = [1, 3, 224, 224]
            let black = try array([Float](repeating: 0, count: dino.count), shape)
            let real = try array(dino, shape)
            imageEmbeds = TryOnTensors.floats(try output(await predict(ie, ["pixel_values": black]), "image_embeds"))
                + TryOnTensors.floats(try output(await predict(ie, ["pixel_values": real]), "image_embeds"))
        }
        let condition: [Float], clothLatent: [Float]
        do {
            let vae = try await load("VAEEncoder", units)
            func latent(_ pixels: [Float]) async throws -> [Float] {
                let m = try output(await predict(vae, ["image": array(pixels, [1, 3, TryOnInputs.height, TryOnInputs.width])]),
                                   "moments")
                return TryOnMath.vaeLatent(moments: TryOnTensors.floats(m), channels: Self.channels, plane: plane)
            }
            let p = try await latent(personTensor), c = try await latent(garmentTensor)
            condition = TryOnMath.stackHeight(top: p, bottom: c, channels: Self.channels, plane: plane)
            clothLatent = c
        }
        advance(5)

        // Feature della UNet del capo per tutti i passi, su file fp16 (cancellati a fine chiamata)
        let featureDir = workDirectory.appending(path: "tryon-features-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: featureDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: featureDir) }

        var featureRows = 0, featureCols = 0
        var garmentFeatures: [[String: URL]] = []
        do {
            let garmentModel = try await load("DenoiserGarment", units)
            let gStep = try array([0], [1])
            let gInputs: [String: MLMultiArray] = [
                "sample": try array(clothLatent, [1, Self.channels, rows, cols]),
                "timestep": gStep,
                "encoder_hidden_states": try array(promptCloth, [1, promptCloth.count / Self.textWidth, Self.textWidth])]
            for i in 0..<Self.steps {
                gStep[0] = NSNumber(value: Float(timesteps[i]))
                let out = try await predict(garmentModel, gInputs)
                var step: [String: URL] = [:]
                for name in out.featureNames where name.hasPrefix("garment_feature_") {
                    let f = try output(out, name)
                    if featureRows == 0 { featureRows = f.shape[1].intValue; featureCols = f.shape[2].intValue }
                    let url = featureDir.appending(path: "\(i)-\(name).f16")
                    try TryOnTensors.halves(f).withUnsafeBytes { try Data($0).write(to: url) }
                    step[name] = url
                }
                garmentFeatures.append(step)
                advance(1)
            }
        }

        // La UNet di prova, passo per passo, guida a batch 2: incondizionato poi condizionato
        var latents = TryOnMath.stackHeight(top: noiseValues, bottom: noiseValues,
                                            channels: Self.channels, plane: plane)
        do {
            let denoiser = try await load("Denoiser", denoiserUnits)
            let tokens = prompt.count / 2 / Self.textWidth, imageTokens = imageEmbeds.count / 2 / Self.textWidth
            let dStep = try array([0, 0], [2])
            let sample = try MLMultiArray(shape: [2, NSNumber(value: 2 * Self.channels), NSNumber(value: 2 * rows),
                                                  NSNumber(value: cols)], dataType: .float32)
            var inputs: [String: MLMultiArray] = [
                "sample": sample, "timestep": dStep,
                "encoder_hidden_states": try array(prompt, [2, tokens, Self.textWidth]),
                "image_embeds": try array(imageEmbeds, [2, imageTokens, Self.textWidth])]
            let desc = denoiser.modelDescription.inputDescriptionsByName
            let featureNames = desc.keys.filter { $0.hasPrefix("garment_feature_") }
            guard let first = featureNames.first, let shape = desc[first]?.multiArrayConstraint?.shape else {
                throw TryOnError.missingOutput("garment_feature_*")
            }
            for name in featureNames {   // zeri: il ramo incondizionato non li cambia mai
                let a = try MLMultiArray(shape: shape, dataType: .float32)
                a.dataPointer.initializeMemory(as: Float.self, repeating: 0, count: a.count)
                inputs[name] = a
            }
            let n = featureRows * featureCols
            let half = Self.channels * 2 * plane
            for i in 0..<Self.steps {
                let t = Float(timesteps[i])
                for b in 0..<2 { dStep[b] = NSNumber(value: t) }
                for name in featureNames {
                    let k = Int(name.dropFirst("garment_feature_".count))!
                    let source = "garment_feature_\(TryOnTensors.duplicates[k] ?? k)"
                    guard let url = garmentFeatures[i][source] else { throw TryOnError.missingOutput(source) }
                    let d = try Data(contentsOf: url, options: .alwaysMapped)
                    // ramo condizionato [d; d]
                    let target = inputs[name]!.dataPointer.assumingMemoryBound(to: Float.self) + 2 * n
                    d.withUnsafeBytes { TryOnTensors.halfToFloat($0.bindMemory(to: UInt16.self), into: target) }
                    (target + n).update(from: target, count: n)
                }
                // sample = [latenti; condizione] sui canali, uguale nei due rami della guida
                let p = sample.dataPointer.assumingMemoryBound(to: Float.self)
                for b in 0..<2 {
                    latents.withUnsafeBufferPointer { (p + b * 2 * half).update(from: $0.baseAddress!, count: half) }
                    condition.withUnsafeBufferPointer { (p + b * 2 * half + half).update(from: $0.baseAddress!, count: half) }
                }
                let noisePred = TryOnTensors.floats(try output(await predict(denoiser, inputs), "noise_pred"))
                TryOnMath.eulerStep(&latents, noisePred: noisePred, guidance: Self.guidance,
                                    dt: Float(sigmas[i + 1] - sigmas[i]))
                advance(8)
            }
        }

        // Decoder
        let image: CGImage
        do {
            let decoder = try await load("VAEDecoder", units)
            let personLatent = TryOnMath.personLatent(latents, channels: Self.channels, rows: rows, cols: cols)
            let decoded = try output(await predict(decoder, ["latents": array(personLatent, [1, Self.channels, rows, cols])]),
                                     "image")
            let h = decoded.shape[2].intValue, w = decoded.shape[3].intValue
            image = try Self.cgImage(TryOnMath.rgba(TryOnTensors.floats(decoded), width: w, height: h), width: w, height: h)
        }
        advance(5)
        return (image, content)
    }

    // MARK: - Core ML

    private func load(_ name: String, _ units: MLComputeUnits) async throws -> MLModel {
        try Task.checkCancellation()
        guard let url = models(name) else { throw TryOnError.missingModel(name) }
        let config = MLModelConfiguration()
        config.computeUnits = units
        do {
            return try await MLModel.load(contentsOf: url, configuration: config)
        } catch {
            try Task.checkCancellation()
            throw TryOnError.loadFailed(name)
        }
    }

    private func predict(_ model: MLModel, _ values: [String: MLMultiArray]) async throws -> MLFeatureProvider {
        try Task.checkCancellation()
        return try await model.prediction(from: MLDictionaryFeatureProvider(
            dictionary: values.mapValues { MLFeatureValue(multiArray: $0) }))
    }

    private func output(_ p: MLFeatureProvider, _ name: String) throws -> MLMultiArray {
        guard let a = p.featureValue(for: name)?.multiArrayValue else { throw TryOnError.missingOutput(name) }
        return a
    }

    private func array(_ data: [Float], _ shape: [Int]) throws -> MLMultiArray {
        let a = try MLMultiArray(shape: shape.map { NSNumber(value: $0) }, dataType: .float32)
        data.withUnsafeBufferPointer { a.dataPointer.copyMemory(from: $0.baseAddress!, byteCount: $0.count * 4) }
        return a
    }

    /// Penultimo strato nascosto di un codificatore di testo, per ogni testo.
    private func hidden(_ m: MLModel, pad: String, _ texts: [String]) async throws
        -> [(values: [Float], tokens: Int, dim: Int)] {
        guard let tok = try? CLIPTokenizer(vocab: tokenizer.vocab, merges: tokenizer.merges, padToken: pad)
        else { throw TryOnError.tokenizer }
        var out: [(values: [Float], tokens: Int, dim: Int)] = []
        for text in texts {
            let ids = try MLMultiArray(shape: [1, 77], dataType: .int32)
            let p = ids.dataPointer.assumingMemoryBound(to: Int32.self)
            for (i, id) in tok.ids(text).enumerated() { p[i] = id }
            let h = try output(await predict(m, ["input_ids": ids]), "hidden_penultimate")
            out.append((TryOnTensors.floats(h), h.shape[1].intValue, h.shape[2].intValue))
        }
        return out
    }

    private static func cgImage(_ px: [UInt8], width: Int, height: Int) throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(px) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw TryOnError.image }
        return image
    }
}
