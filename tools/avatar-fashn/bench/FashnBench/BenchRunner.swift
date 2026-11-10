import CoreGraphics
import CoreML
import Foundation
import ImageIO
import Observation
import os
import UniformTypeIdentifiers

/// Un file .npy di numpy: forma e dati grezzi (little endian, ordine C).
struct NumpyArray {
    let shape: [Int]
    let descr: String
    let data: Data

    init(contentsOf url: URL) throws {
        let raw = try Data(contentsOf: url, options: .mappedIfSafe)
        guard raw.count > 12, raw[0] == 0x93, String(data: raw[1..<6], encoding: .ascii) == "NUMPY" else {
            throw BenchError.input("\(url.lastPathComponent): non è un .npy")
        }
        let major = raw[6]
        let headerLength = major == 1 ? Int(raw[8]) | Int(raw[9]) << 8
            : Int(raw[8]) | Int(raw[9]) << 8 | Int(raw[10]) << 16 | Int(raw[11]) << 24
        let start = major == 1 ? 10 : 12
        guard let header = String(data: raw[start..<(start + headerLength)], encoding: .ascii) else {
            throw BenchError.input("\(url.lastPathComponent): intestazione illeggibile")
        }
        guard !header.contains("'fortran_order': True") else { throw BenchError.input("ordine Fortran non gestito") }
        func field(_ name: String, until end: Character) -> String? {
            guard let range = header.range(of: "'\(name)':") else { return nil }
            let rest = header[range.upperBound...].drop { $0 == " " || $0 == "'" || $0 == "(" }
            return String(rest.prefix { $0 != end })
        }
        descr = field("descr", until: "'") ?? ""
        shape = (field("shape", until: ")") ?? "").split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        data = raw.subdata(in: (start + headerLength)..<raw.count)
    }

    /// I numeri del primo elemento del lotto (la metà condizionata), come Float.
    func firstBatchFloats() throws -> [Float] {
        guard descr == "<f4" else { throw BenchError.input("atteso <f4, trovato \(descr)") }
        let count = shape.dropFirst().reduce(1, *)
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self).prefix(count)) }
    }

    func firstInteger() throws -> Int {
        switch descr {
        case "<i8": return data.withUnsafeBytes { Int($0.loadUnaligned(as: Int64.self)) }
        case "<i4": return data.withUnsafeBytes { Int($0.loadUnaligned(as: Int32.self)) }
        default: throw BenchError.input("intero atteso, trovato \(descr)")
        }
    }
}

enum BenchError: Error, CustomStringConvertible {
    case input(String)
    case model(String)

    var description: String {
        switch self {
        case .input(let text), .model(let text): return text
        }
    }
}

/// La stessa schedule della pipeline originale (`get_rf_schedule`, mu 1,5): da 0 (rumore) a 1 (immagine).
func rectifiedFlowSchedule(steps: Int, mu: Double = 1.5) -> [Double] {
    let shift = exp(-mu)
    let values = (0...steps).map { index -> Double in
        let t = 1 - Double(index) / Double(steps)
        return t <= 0 ? 0 : shift / (shift + (1 / t - 1))
    }
    return values.reversed()
}

/// Memoria dell'app come la conta iOS per chiuderla (phys_footprint), in MB.
func memoryFootprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
}

@MainActor @Observable final class BenchRunner {
    var status = "Pronto"
    var log = ""
    var running = false
    var result: CGImage?

    private let guidance: Float = 1.5
    private var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private func argument(_ name: String) -> String? {
        let args = CommandLine.arguments
        return args.firstIndex(of: name).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
    }

    private func say(_ line: String) {
        print("FASHN \(line)")
        log += line + "\n"
        try? log.write(to: documents.appendingPathComponent("fashn-log.txt"), atomically: true, encoding: .utf8)
    }

    func start() {
        guard !running else { return }
        running = true
        result = nil
        log = ""
        let unitsName = argument("--units") ?? "gpu"
        let steps = argument("--steps").flatMap(Int.init) ?? 30
        try? FileManager.default.removeItem(at: documents.appendingPathComponent("fashn-result.json"))
        Task {
            do {
                try await run(unitsName: unitsName, steps: steps)
            } catch {
                say("ERRORE \(error)")
                status = "Errore"
                write(["error": "\(error)"])
            }
            running = false
            // Lanciata dal Mac con la console attaccata: chiudendosi fa finire il comando
            if CommandLine.arguments.contains("--esci") { exit(0) }
        }
    }

    private func write(_ info: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: documents.appendingPathComponent("fashn-result.json"))
    }

    private func run(unitsName: String, steps: Int) async throws {
        // La cartella entra nel pacchetto col nome che ha su disco
        guard let payload = Bundle.main.url(forResource: "bench-payload", withExtension: nil) else {
            throw BenchError.input("manca Payload nel pacchetto")
        }
        let kind = (try? String(contentsOf: payload.appendingPathComponent("modello.txt"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
        let units: MLComputeUnits
        switch unitsName {
        case "all": units = .all
        case "ne": units = .cpuAndNeuralEngine
        case "cpu": units = .cpuOnly
        default: units = .cpuAndGPU
        }
        var device = utsname()
        uname(&device)
        let machine = withUnsafeBytes(of: &device.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        say("dispositivo \(machine), modello \(kind), unità \(unitsName), passi \(steps)")
        say(String(format: "memoria libera per l'app %.0f MB", Double(os_proc_available_memory()) / 1_048_576))

        // Picco di memoria: campionato mentre il modello lavora
        let peak = PeakMemory()
        peak.start()
        defer { peak.stop() }

        status = "Carico il modello…"
        let loadStart = Date()
        let model = try await Task.detached(priority: .userInitiated) { () -> MLModel in
            let config = MLModelConfiguration()
            config.computeUnits = units
            return try MLModel(contentsOf: payload.appendingPathComponent("FashnTryOn.mlmodelc"), configuration: config)
        }.value
        let loadSeconds = Date().timeIntervalSince(loadStart)
        say(String(format: "modello caricato in %.1f s, memoria %.0f MB", loadSeconds, memoryFootprintMB()))

        let inputs = payload.appendingPathComponent("inputs")
        func load(_ name: String) throws -> NumpyArray { try NumpyArray(contentsOf: inputs.appendingPathComponent("\(name).npy")) }
        let noise = try load("x")
        let shape = [1] + Array(noise.shape.dropFirst())
        guard shape.count == 4 else { throw BenchError.input("forma di x inattesa: \(noise.shape)") }
        var images = try noise.firstBatchFloats()
        let names = ["ca_images", "garment_images", "person_poses", "garment_poses"]
        var cond = [String: MLMultiArray](), uncond = [String: MLMultiArray]()
        for name in names {
            let array = try load(name)
            let arrayShape = [1] + Array(array.shape.dropFirst())
            cond[name] = try Self.float16Array(try array.firstBatchFloats(), shape: arrayShape)
            uncond[name] = try Self.float16Array([Float](repeating: 0, count: arrayShape.reduce(1, *)), shape: arrayShape)
        }
        let category = try load("garment_categories").firstInteger()
        let condInputs = cond, uncondInputs = uncond
        say("ingressi: x \(shape), categoria \(category)")

        let schedule = rectifiedFlowSchedule(steps: steps)
        var stepSeconds = [Double]()
        let guidance = guidance
        for index in 0..<steps {
            let tCurr = schedule[index], tPrev = schedule[index + 1]
            status = "Passo \(index + 1) di \(steps)…"
            let stepStart = Date()
            let current = images
            let last = index == steps - 1
            let velocity = try await Task.detached(priority: .userInitiated) { () -> [Float] in
                let x = try Self.float16Array(current, shape: shape)
                let times = try Self.float16Array([Float(tCurr)], shape: [1])
                func predict(_ parts: [String: MLMultiArray], category: Int) throws -> [Float] {
                    let cat = try MLMultiArray(shape: [1], dataType: .int32)
                    cat[0] = NSNumber(value: category)
                    var features: [String: Any] = ["x": x, "times": times, "category": cat]
                    for (name, value) in parts { features[name] = value }
                    let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: features))
                    guard let out = output.featureValue(for: "velocity")?.multiArrayValue else {
                        throw BenchError.model("manca l'uscita velocity")
                    }
                    return Self.floats(out)
                }
                let conditioned = try predict(condInputs, category: category)
                // Come l'originale: all'ultimo passo niente guida, un passaggio solo
                guard !last else { return conditioned }
                let free = try predict(uncondInputs, category: 0)
                return zip(free, conditioned).map { $0 + guidance * ($1 - $0) }
            }.value
            guard velocity.count == images.count else { throw BenchError.model("uscita di \(velocity.count) numeri, attesi \(images.count)") }
            let dt = Float(tPrev - tCurr)
            for i in images.indices { images[i] += dt * velocity[i] }
            stepSeconds.append(Date().timeIntervalSince(stepStart))
            say(String(format: "passo %d: %.2f s, memoria %.0f MB, picco %.0f MB", index + 1, stepSeconds[index], memoryFootprintMB(), peak.value))
        }

        let hasNaN = images.contains { $0.isNaN }
        let picture = Self.image(images, width: shape[3], height: shape[2])
        result = picture
        if let picture { Self.savePNG(picture, to: documents.appendingPathComponent("fashn-result.png")) }
        let total = stepSeconds.reduce(0, +)
        let middle = stepSeconds.dropFirst().dropLast()
        let mean = middle.isEmpty ? 0 : middle.reduce(0, +) / Double(middle.count)
        status = String(format: "Fatto in %.0f s", total)
        say(String(format: "TOTALE %.1f s, media a passo %.2f s, primo %.2f s, picco %.0f MB, NaN %@", total, mean,
                   stepSeconds.first ?? 0, peak.value, hasNaN ? "sì" : "no"))
        write(["device": machine, "model": kind, "units": unitsName, "steps": steps, "load_s": (loadSeconds * 10).rounded() / 10,
               "step_s": stepSeconds.map { ($0 * 100).rounded() / 100 }, "step_s_mean": (mean * 100).rounded() / 100,
               "first_step_s": ((stepSeconds.first ?? 0) * 100).rounded() / 100, "total_s": (total * 10).rounded() / 10,
               "peak_mb": peak.value.rounded(), "nan": hasNaN])
    }

    // MARK: - Numeri

    nonisolated static func float16Array(_ values: [Float], shape: [Int]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape.map { NSNumber(value: $0) }, dataType: .float16)
        array.withUnsafeMutableBytes { buffer, _ in
            let out = buffer.bindMemory(to: Float16.self)
            for i in 0..<min(values.count, out.count) { out[i] = Float16(values[i]) }
        }
        return array
    }

    /// I numeri di un'uscita, in ordine C, qualunque passo abbia in memoria.
    nonisolated static func floats(_ array: MLMultiArray) -> [Float] {
        let shape = array.shape.map(\.intValue)
        let count = shape.reduce(1, *)
        var out = [Float](repeating: 0, count: count)
        array.withUnsafeBytes { buffer in
            let strides = array.strides.map(\.intValue)
            var contiguous = [Int](repeating: 1, count: shape.count)
            for d in stride(from: shape.count - 2, through: 0, by: -1) { contiguous[d] = contiguous[d + 1] * shape[d + 1] }
            func value(_ offset: Int) -> Float {
                switch array.dataType {
                case .float16: return Float(buffer.load(fromByteOffset: offset * 2, as: Float16.self))
                case .float32: return buffer.load(fromByteOffset: offset * 4, as: Float.self)
                default: return Float(buffer.load(fromByteOffset: offset * 8, as: Double.self))
                }
            }
            if strides == contiguous {
                for i in 0..<count { out[i] = value(i) }
            } else {
                for i in 0..<count {
                    var rest = i, offset = 0
                    for d in 0..<shape.count { offset += (rest / contiguous[d]) * strides[d]; rest %= contiguous[d] }
                    out[i] = value(offset)
                }
            }
        }
        return out
    }

    /// Da CHW in [-1, 1] a un'immagine RGB.
    nonisolated static func image(_ values: [Float], width: Int, height: Int) -> CGImage? {
        let plane = width * height
        guard values.count >= 3 * plane else { return nil }
        var bytes = [UInt8](repeating: 255, count: plane * 4)
        for i in 0..<plane {
            for c in 0..<3 {
                let v = min(max(values[c * plane + i], -1), 1)
                bytes[i * 4 + c] = UInt8(((v.isNaN ? 0 : v) + 1) * 127.5)
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    nonisolated static func savePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}

/// Il picco di memoria, campionato quattro volte al secondo su un filo a parte.
final class PeakMemory: @unchecked Sendable {
    private let lock = NSLock()
    private var peak = 0.0
    private var timer: DispatchSourceTimer?

    var value: Double { lock.withLock { peak } }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "picco", qos: .utility))
        timer.schedule(deadline: .now(), repeating: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            let now = memoryFootprintMB()
            self?.lock.withLock { self?.peak = max(self?.peak ?? 0, now) }
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
