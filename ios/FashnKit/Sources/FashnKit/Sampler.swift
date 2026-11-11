import CoreGraphics
import CoreML
import Foundation

/// La stessa schedule della pipeline originale (`get_rf_schedule`, mu 1,5): da 0 (rumore) a 1 (immagine).
public func rectifiedFlowSchedule(steps: Int, mu: Double = 1.5) -> [Double] {
    let shift = exp(-mu)
    let values = (0...steps).map { index -> Double in
        let t = 1 - Double(index) / Double(steps)
        return t <= 0 ? 0 : shift / (shift + (1 / t - 1))
    }
    return values.reversed()
}

/// A che punto è la generazione. La frazione conta i passaggi del modello: due a passo, uno solo all'ultimo.
public struct FashnProgress: Equatable, Sendable {
    public let step: Int
    public let steps: Int
    public let passesDone: Int
    public let passesTotal: Int

    public init(step: Int, steps: Int, passesDone: Int, passesTotal: Int) {
        self.step = step
        self.steps = steps
        self.passesDone = passesDone
        self.passesTotal = passesTotal
    }

    public var fraction: Double { passesTotal == 0 ? 0 : Double(passesDone) / Double(passesTotal) }
    public var percent: Int { Int((fraction * 100).rounded(.down)) }

    public static func passes(steps: Int) -> Int { max(0, 2 * steps - 1) }
}

/// Rumore gaussiano ripetibile: stesso seme, stessa immagine.
struct GaussianNoise {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    private mutating func nextUniform() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return (Double(z >> 11) + 0.5) / Double(1 << 53)
    }

    mutating func fill(count: Int) -> [Float] {
        var out = [Float](repeating: 0, count: count)
        var i = 0
        while i < count {
            let radius = (-2 * log(nextUniform())).squareRoot(), angle = 2 * Double.pi * nextUniform()
            out[i] = Float(radius * cos(angle))
            if i + 1 < count { out[i + 1] = Float(radius * sin(angle)) }
            i += 2
        }
        return out
    }
}

/// Il campionamento di FASHN VTON con Core ML: Eulero, guida 1,5, ultimo passo senza guida, come `TryOnPipeline._sample`.
public final class FashnSampler: @unchecked Sendable {
    public static let guidance: Float = 1.5
    private let model: MLModel

    public init(modelURL: URL, units: MLComputeUnits = .cpuAndGPU) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = units
        model = try MLModel(contentsOf: modelURL, configuration: configuration)
    }

    /// Genera l'immagine. Lavora sul filo di chi chiama: va lanciato fuori dal filo principale.
    /// - Parameter noise: il rumore di partenza, se si vuole ripetere una generazione nota; altrimenti nasce dal seme.
    public func generate(_ inputs: FashnInputs, steps: Int = 20, seed: UInt64 = 42, noise: [Float]? = nil,
                         progress: (FashnProgress) -> Void = { _ in }) throws -> [Float] {
        let shape = [1, FashnModel.channels, FashnModel.height, FashnModel.width]
        let poseShape = [1, 1, FashnModel.height, FashnModel.width]
        let count = shape.reduce(1, *)
        var images: [Float]
        if let noise {
            guard noise.count == count else { throw FashnError.model("rumore di \(noise.count) numeri, attesi \(count)") }
            images = noise
        } else {
            var generator = GaussianNoise(seed: seed)
            images = generator.fill(count: count)
        }

        let conditioned: [String: MLMultiArray] = [
            "ca_images": try Self.float16Array(inputs.person, shape: shape),
            "garment_images": try Self.float16Array(inputs.garment, shape: shape),
            "person_poses": try Self.float16Array(inputs.personPose, shape: poseShape),
            "garment_poses": try Self.float16Array(inputs.garmentPose, shape: poseShape),
        ]
        // Senza guida: tutto a zero e categoria 0
        let free: [String: MLMultiArray] = [
            "ca_images": try Self.float16Array([], shape: shape), "garment_images": try Self.float16Array([], shape: shape),
            "person_poses": try Self.float16Array([], shape: poseShape), "garment_poses": try Self.float16Array([], shape: poseShape),
        ]

        let schedule = rectifiedFlowSchedule(steps: steps)
        let total = FashnProgress.passes(steps: steps)
        var done = 0
        progress(FashnProgress(step: 0, steps: steps, passesDone: 0, passesTotal: total))
        for index in 0..<steps {
            try Task.checkCancellation()
            let x = try Self.float16Array(images, shape: shape)
            let times = try Self.float16Array([Float(schedule[index])], shape: [1])
            var velocity = try predict(x: x, times: times, parts: conditioned, category: inputs.category.rawValue)
            done += 1
            progress(FashnProgress(step: index + 1, steps: steps, passesDone: done, passesTotal: total))
            if index < steps - 1 {
                try Task.checkCancellation()
                let unguided = try predict(x: x, times: times, parts: free, category: 0)
                for i in velocity.indices { velocity[i] = unguided[i] + Self.guidance * (velocity[i] - unguided[i]) }
                done += 1
                progress(FashnProgress(step: index + 1, steps: steps, passesDone: done, passesTotal: total))
            }
            guard velocity.count == images.count else { throw FashnError.model("uscita di \(velocity.count) numeri, attesi \(images.count)") }
            let dt = Float(schedule[index + 1] - schedule[index])
            for i in images.indices { images[i] += dt * velocity[i] }
        }
        return images
    }

    private func predict(x: MLMultiArray, times: MLMultiArray, parts: [String: MLMultiArray], category: Int) throws -> [Float] {
        let cat = try MLMultiArray(shape: [1], dataType: .int32)
        cat[0] = NSNumber(value: category)
        var features: [String: Any] = ["x": x, "times": times, "category": cat]
        for (name, value) in parts { features[name] = value }
        let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: features))
        guard let out = output.featureValue(for: "velocity")?.multiArrayValue else { throw FashnError.model("manca l'uscita velocity") }
        return Self.floats(out)
    }

    /// Un tensore a 16 bit; i valori mancanti restano a zero.
    static func float16Array(_ values: [Float], shape: [Int]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape.map { NSNumber(value: $0) }, dataType: .float16)
        array.withUnsafeMutableBytes { buffer, _ in
            let out = buffer.bindMemory(to: Float16.self)
            for i in 0..<out.count { out[i] = i < values.count ? Float16(values[i]) : 0 }
        }
        return array
    }

    /// I numeri di un'uscita, in ordine riga per riga, qualunque passo abbia in memoria.
    static func floats(_ array: MLMultiArray) -> [Float] {
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
}
