import Accelerate
import CoreML
import Foundation

/// Helper dei tensori Core ML condivisi tra l'app, il banco di prova e i test.
enum TryOnTensors {
    // Le feature 8–11 della UNet del capo sono le 12–15 (vedi components.py)
    static let duplicates = [8: 12, 9: 13, 10: 14, 11: 15]

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
}
