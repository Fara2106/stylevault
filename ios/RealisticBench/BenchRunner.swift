import Accelerate
import CoreML
import Foundation
import os

/// Carica i 7 modelli di Mobile-VTON dal bundle e misura ogni pezzo: prima
/// esecuzione, mediana di 3 a regime e memoria di picco.
enum BenchRunner {
    // Le feature 8–11 della UNet del capo sono le 12–15 (vedi components.py)
    static let duplicates = [8: 12, 9: 13, 10: 14, 11: 15]

    struct Result {
        var steady: BenchTimes
        var firstRun: BenchTimes
        var loadSeconds: [String: Double]
        var peakMemoryMB: Double
    }

    /// Le fasi della generazione vera: ogni fase carica solo i suoi modelli e li
    /// libera prima della successiva (tutti e 7 insieme non stanno nella memoria
    /// GPU del 18 Pro Max: crash di MPSGraph sulla UNet del capo).
    static let phases = [["TextEncoder", "TextEncoder2", "ImageEncoder", "VAEEncoder"],
                         ["DenoiserGarment", "Denoiser"],
                         ["VAEDecoder"]]

    /// I modelli compilati stanno in Documents/Models (copiati una volta dal Mac con
    /// devicectl, così reinstallare l'app non ricopia 3 GB) o, se no, nel bundle.
    /// `folder`: "Models" (fp16) o "Models-6bit".
    nonisolated(unsafe) static var folder = "Models"
    /// Cartella con Models*/, Inputs/ e Output/: Documents sul telefono, una
    /// cartella del Mac nel test macOS.
    nonisolated(unsafe) static var root = URL.documentsDirectory
    /// Guida in due chiamate a batch 1 (Denoiser1.mlmodelc) invece di una a batch 2.
    nonisolated(unsafe) static var splitGuidance = false

    /// Memoria che iOS lascia ancora all'app (sul Mac non c'è un limite per app).
    static func availableMB() -> Double {
        #if os(iOS)
        Double(os_proc_available_memory()) / 1_048_576
        #else
        .infinity
        #endif
    }

    static func modelURL(_ name: String) -> URL? {
        let docs = root.appending(path: "\(folder)/\(name).mlmodelc")
        if FileManager.default.fileExists(atPath: docs.path) { return docs }
        return Bundle.main.url(forResource: name, withExtension: "mlmodelc")
    }

    /// `denoiserUnits`: unità a parte per la UNet di prova (modalità mista: il
    /// Neural Engine non riesce a preparare il Denoiser fp16, il resto sì).
    static func measure(units: MLComputeUnits, denoiserUnits: MLComputeUnits? = nil,
                        phases selected: Set<Int>? = nil,
                        log: @escaping (String) -> Void) async throws -> Result {
        log("modelli: \(folder)")
        log("memoria libera per l'app: \(fmt(availableMB())) MB")
        let sampler = MemorySampler()
        sampler.start()
        defer { sampler.stop() }

        var load: [String: Double] = [:]
        var first: [String: Double] = [:]
        var steady: [String: Double] = [:]
        var garmentOut: MLFeatureProvider?
        for (index, phase) in phases.enumerated() where selected?.contains(index + 1) ?? true {
            var models: [String: MLModel] = [:]
            for name in phase {
                guard let url = modelURL(name) else {
                    throw BenchError.missingModel(name)
                }
                let config = MLModelConfiguration()
                config.computeUnits = name == "Denoiser" ? denoiserUnits ?? units : units
                let t0 = Date()
                models[name] = try await MLModel.load(contentsOf: url, configuration: config)
                load[name] = Date().timeIntervalSince(t0)
                log("caricato \(name) in \(fmt(load[name]!)) s — memoria \(fmt(sampler.peakMB)) MB, "
                    + "libera \(fmt(availableMB())) MB")
            }
            for name in phase {
                let model = models[name]!
                let inputs: MLFeatureProvider
                if name == "Denoiser", let garmentOut {
                    inputs = try denoiserInputs(model, garment: garmentOut)
                } else {
                    inputs = try randomInputs(model)
                }
                var runs: [Double] = []
                for i in 0..<4 {
                    let t0 = Date()
                    let out = try await model.prediction(from: inputs)
                    runs.append(Date().timeIntervalSince(t0))
                    if name == "DenoiserGarment", i == 0 { garmentOut = out }
                }
                first[name] = runs[0]
                steady[name] = median(Array(runs.dropFirst()))
                log("\(name): prima \(fmt(runs[0])) s, regime \(fmt(steady[name]!)) s — memoria \(fmt(sampler.peakMB)) MB")
            }
            if let g = models["DenoiserGarment"], let d = models["Denoiser"] {
                let loop = try await denoiseLoop(garment: g, denoiser: d, steps: 10)
                log("10 passi veri: \(fmt(loop.total)) s (UNet capo \(fmt(loop.garment)) s, UNet prova "
                    + "\(fmt(loop.denoiser)) s, feature \(fmt(loop.glue)) s) — controllo \(loop.check)")
                // Con ingressi identici Core ML ricicla il lavoro e il "regime" delle
                // UNet esce falsato: per la stima valgono i passi veri
                steady["DenoiserGarment"] = loop.garment / 10
                steady["Denoiser"] = (loop.denoiser + loop.glue) / 10
            }
            log("fase \(index + 1) finita — memoria ora \(fmt(MemorySampler.footprintMB())) MB")
        }
        guard steady.count == phases.joined().count else { throw BenchError.partial(sampler.peakMB) }
        return Result(steady: times(steady), firstRun: times(first), loadSeconds: load,
                      peakMemoryMB: sampler.peakMB)
    }

    /// I 10 passi come nella generazione vera: a ogni passo cambia il timestep,
    /// la UNet di prova riceve le feature appena uscite dalla UNet del capo e il
    /// risultato viene letto (nessuna risposta riciclata, nessun calcolo pendente).
    /// Gli ingressi si preparano una volta e si aggiornano sul posto, come farà l'app.
    private static func denoiseLoop(garment: MLModel, denoiser: MLModel, steps: Int) async throws
        -> (total: Double, garment: Double, denoiser: Double, glue: Double, check: String) {
        var g = 0.0, d = 0.0, glue = 0.0
        var sums: [String] = []
        var gIn = dictionary(try randomInputs(garment))
        var dIn = dictionary(try randomInputs(denoiser))
        let gStep = try timestep(0, count: 1), dStep = try timestep(0, count: 2)
        gIn["timestep"] = MLFeatureValue(multiArray: gStep)
        dIn["timestep"] = MLFeatureValue(multiArray: dStep)
        let gInputs = try MLDictionaryFeatureProvider(dictionary: gIn)
        let dInputs = try MLDictionaryFeatureProvider(dictionary: dIn)
        let start = Date()
        for step in 0..<steps {
            let t = Float(1000 - 100 * step)
            for i in 0..<1 { gStep[i] = NSNumber(value: t) }
            for i in 0..<2 { dStep[i] = NSNumber(value: t) }
            var t0 = Date()
            let gOut = try await garment.prediction(from: gInputs)
            g += Date().timeIntervalSince(t0)

            t0 = Date()
            for (name, value) in dIn where name.hasPrefix("garment_feature_") {
                let k = Int(name.dropFirst("garment_feature_".count))!
                let source = "garment_feature_\(duplicates[k] ?? k)"
                guard let f = gOut.featureValue(for: source)?.multiArrayValue else {
                    throw BenchError.missingFeature(source)
                }
                try stackGarment(f, into: value.multiArrayValue!)
            }
            glue += Date().timeIntervalSince(t0)

            t0 = Date()
            let out = try await denoiser.prediction(from: dInputs)
            guard let noise = out.featureValue(for: "noise_pred")?.multiArrayValue else {
                throw BenchError.missingFeature("noise_pred")
            }
            let values = floats(noise)
            d += Date().timeIntervalSince(t0)
            sums.append(String(format: "%.1f", values.prefix(4096).reduce(0, +)))
        }
        return (Date().timeIntervalSince(start), g, d, glue, sums.joined(separator: " "))
    }

    private static func dictionary(_ p: MLFeatureProvider) -> [String: MLFeatureValue] {
        Dictionary(uniqueKeysWithValues: p.featureNames.compactMap { n in p.featureValue(for: n).map { (n, $0) } })
    }

    private static func timestep(_ t: Float, count: Int) throws -> MLMultiArray {
        let a = try MLMultiArray(shape: [NSNumber(value: count)], dataType: .float32)
        for i in 0..<count { a[i] = NSNumber(value: t) }
        return a
    }

    private static func times(_ d: [String: Double]) -> BenchTimes {
        BenchTimes(textEncoder: d["TextEncoder"]!, textEncoder2: d["TextEncoder2"]!,
                   imageEncoder: d["ImageEncoder"]!, vaeEncoder: d["VAEEncoder"]!,
                   denoiserGarment: d["DenoiserGarment"]!, denoiser: d["Denoiser"]!,
                   vaeDecoder: d["VAEDecoder"]!)
    }

    /// Ingressi casuali con le forme e i tipi dichiarati dal modello.
    private static func randomInputs(_ model: MLModel) throws -> MLFeatureProvider {
        var values: [String: MLFeatureValue] = [:]
        for (name, desc) in model.modelDescription.inputDescriptionsByName {
            guard let c = desc.multiArrayConstraint else { continue }
            let array = try MLMultiArray(shape: c.shape, dataType: c.dataType)
            fill(array, name: name)
            values[name] = MLFeatureValue(multiArray: array)
        }
        return try MLDictionaryFeatureProvider(dictionary: values)
    }

    /// Come nella pipeline: ogni feature del capo [1,C,W] diventa [d; d] in
    /// altezza, e nel ramo incondizionato (batch 0) resta a zero.
    private static func denoiserInputs(_ model: MLModel, garment: MLFeatureProvider) throws -> MLFeatureProvider {
        var values: [String: MLFeatureValue] = [:]
        for (name, desc) in model.modelDescription.inputDescriptionsByName {
            guard let c = desc.multiArrayConstraint else { continue }
            let array = try MLMultiArray(shape: c.shape, dataType: .float32)
            if name.hasPrefix("garment_feature_"), let k = Int(name.dropFirst("garment_feature_".count)) {
                let source = "garment_feature_\(duplicates[k] ?? k)"
                guard let d = garment.featureValue(for: source)?.multiArrayValue else {
                    throw BenchError.missingFeature(source)
                }
                try stackGarment(d, into: array)
            } else {
                fill(array, name: name)
            }
            values[name] = MLFeatureValue(multiArray: array)
        }
        return try MLDictionaryFeatureProvider(dictionary: values)
    }

    private static func stackGarment(_ d: MLMultiArray, into dst: MLMultiArray) throws {
        let rows = d.shape[1].intValue, cols = d.shape[2].intValue
        guard dst.shape.map(\.intValue) == [2, 2 * rows, cols] else { throw BenchError.shape(dst.shape) }
        let src = floats(d)
        let out = dst.dataPointer.assumingMemoryBound(to: Float.self)
        let half = 2 * rows * cols
        out.initialize(repeating: 0, count: half)            // ramo incondizionato
        for copy in 0..<2 {
            (out + half + copy * rows * cols).update(from: src, count: rows * cols)
        }
    }

    /// Valori contigui in Float32, qualunque sia il tipo e il passo dell'uscita.
    static func floats(_ a: MLMultiArray) -> [Float] {
        [Float](unsafeUninitializedCapacity: a.count) { buffer, n in
            copyFloats(a, into: buffer.baseAddress!)
            n = a.count
        }
    }

    /// Un'uscita di Core ML in fp16 contigui (bit di Float16): per tenere da parte
    /// le feature del capo di tutti i passi con metà memoria.
    static func halves(_ a: MLMultiArray) -> [UInt16] {
        let shape = a.shape.map(\.intValue), strides = a.strides.map(\.intValue)
        let contiguous = strides == shape.indices.map { shape[($0 + 1)...].reduce(1, *) }
        if contiguous, a.dataType == .float16 {
            return Array(UnsafeBufferPointer(start: a.dataPointer.assumingMemoryBound(to: UInt16.self), count: a.count))
        }
        var f = floats(a)
        return [UInt16](unsafeUninitializedCapacity: a.count) { buffer, n in
            f.withUnsafeMutableBufferPointer { src in
                var s = vImage_Buffer(data: src.baseAddress, height: 1, width: vImagePixelCount(a.count), rowBytes: a.count * 4)
                var d = vImage_Buffer(data: buffer.baseAddress, height: 1, width: vImagePixelCount(a.count), rowBytes: a.count * 2)
                vImageConvert_PlanarFtoPlanar16F(&s, &d, 0)
            }
            n = a.count
        }
    }

    /// fp16 (bit) → Float32 in `dst`.
    static func halfToFloat(_ src: UnsafeBufferPointer<UInt16>, into dst: UnsafeMutablePointer<Float>) {
        var s = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: src.baseAddress), height: 1,
                              width: vImagePixelCount(src.count), rowBytes: src.count * 2)
        var d = vImage_Buffer(data: dst, height: 1, width: vImagePixelCount(src.count), rowBytes: src.count * 4)
        vImageConvert_Planar16FtoPlanarF(&s, &d, 0)
    }

    static func halfToFloat(_ h: [UInt16], into dst: UnsafeMutablePointer<Float>) {
        h.withUnsafeBufferPointer { halfToFloat($0, into: dst) }
    }

    /// Copia un'uscita di Core ML in Float32 contigui. Caso veloce (vImage o
    /// memcpy per riga) quando solo l'ultimo asse ha righe allungate — come le
    /// uscite fp16 della GPU, allineate a 64 byte; altrimenti elemento per elemento.
    static func copyFloats(_ a: MLMultiArray, into dst: UnsafeMutablePointer<Float>) {
        let shape = a.shape.map(\.intValue), strides = a.strides.map(\.intValue)
        let n = shape.count, cols = shape[n - 1]
        let rows = shape.dropLast().reduce(1, *)
        let rowStride = n > 1 ? strides[n - 2] : cols
        let rowPadded = strides[n - 1] == 1 && rowStride >= cols
            && (0..<max(0, n - 2)).allSatisfy { strides[$0] == shape[$0 + 1] * strides[$0 + 1] }
        if rowPadded, a.dataType == .float16 {
            var src = vImage_Buffer(data: a.dataPointer, height: vImagePixelCount(rows),
                                    width: vImagePixelCount(cols), rowBytes: rowStride * 2)
            var out = vImage_Buffer(data: dst, height: vImagePixelCount(rows),
                                    width: vImagePixelCount(cols), rowBytes: cols * 4)
            vImageConvert_Planar16FtoPlanarF(&src, &out, 0)
            return
        }
        if rowPadded, a.dataType == .float32 {
            let p = a.dataPointer.assumingMemoryBound(to: Float.self)
            if rowStride == cols { dst.update(from: p, count: rows * cols); return }
            for r in 0..<rows { (dst + r * cols).update(from: p + r * rowStride, count: cols) }
            return
        }
        func read(_ offset: Int) -> Float {
            switch a.dataType {
            case .float16: Float(a.dataPointer.assumingMemoryBound(to: Float16.self)[offset])
            case .double: Float(a.dataPointer.assumingMemoryBound(to: Double.self)[offset])
            default: a.dataPointer.assumingMemoryBound(to: Float.self)[offset]
            }
        }
        for i in 0..<a.count {
            var rest = i, offset = 0
            for axis in stride(from: n - 1, through: 0, by: -1) {
                offset += (rest % shape[axis]) * strides[axis]
                rest /= shape[axis]
            }
            dst[i] = read(offset)
        }
    }

    private static func fill(_ a: MLMultiArray, name: String) {
        var seed: UInt32 = 42
        func next() -> UInt32 { seed = seed &* 1_664_525 &+ 1_013_904_223; return seed }
        switch a.dataType {
        case .int32:
            // input_ids: inizio/fine testo di CLIP e parole qualsiasi in mezzo
            let p = a.dataPointer.assumingMemoryBound(to: Int32.self)
            for i in 0..<a.count { p[i] = i == 0 ? 49406 : (i < 30 ? Int32(next() % 40000) + 300 : 49407) }
        case .float16:
            let p = a.dataPointer.assumingMemoryBound(to: Float16.self)
            for i in 0..<a.count { p[i] = Float16(Float(next() % 2000) / 1000 - 1) }
        default:
            let p = a.dataPointer.assumingMemoryBound(to: Float.self)
            let timestep = name == "timestep"
            for i in 0..<a.count { p[i] = timestep ? 500 : Float(next() % 2000) / 1000 - 1 }
        }
    }

    private static func median(_ v: [Double]) -> Double {
        let s = v.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }
}

func fmt(_ x: Double) -> String { String(format: "%.2f", x) }

enum BenchError: LocalizedError {
    case missingModel(String), missingFeature(String), shape([NSNumber]), partial(Double), missingInputs, image
    var errorDescription: String? {
        switch self {
        case .missingModel(let n): "Manca \(n).mlpackage in RealisticBench/Models"
        case .missingFeature(let n): "La UNet del capo non ha dato \(n)"
        case .shape(let s): "Forma inattesa \(s)"
        case .partial(let peak): "Misurate solo alcune fasi (picco \(fmt(peak)) MB): niente stima"
        case .missingInputs: "Mancano gli ingressi in Documents/Inputs (export_bench_inputs.py)"
        case .image: "Immagine non salvata"
        }
    }
}

/// Memoria dell'app come la conta iOS per chiuderla (phys_footprint), campionata
/// ogni 50 ms: il picco vero cade dentro le predizioni, non tra una e l'altra.
final class MemorySampler: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: Double = 0
    private var timer: DispatchSourceTimer?

    var peakMB: Double { lock.withLock { peak } }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        t.schedule(deadline: .now(), repeating: .milliseconds(50))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let now = Self.footprintMB()
            self.lock.withLock { self.peak = max(self.peak, now) }
        }
        t.resume()
        timer = t
    }

    func stop() { timer?.cancel() }

    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }
}
