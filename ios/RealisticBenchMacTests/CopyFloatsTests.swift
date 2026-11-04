import CoreML
import XCTest

final class CopyFloatsTests: XCTestCase {
    /// Uscita fp16 [1, 2, 3] con righe allungate a 4 elementi, come quelle della GPU.
    func testFp16ConRigheAllungate() throws {
        let raw = UnsafeMutablePointer<Float16>.allocate(capacity: 8)
        let values: [Float16] = [1, 2, 3, 99, 4, 5, 6, 99]
        raw.initialize(from: values, count: 8)
        let a = try MLMultiArray(dataPointer: raw, shape: [1, 2, 3], dataType: .float16,
                                 strides: [8, 4, 1]) { $0.deallocate() }
        XCTAssertEqual(BenchRunner.floats(a), [1, 2, 3, 4, 5, 6])
    }

    func testFp32ConRigheAllungate() throws {
        let raw = UnsafeMutablePointer<Float>.allocate(capacity: 8)
        raw.initialize(from: [1, 2, 3, -1, 4, 5, 6, -1], count: 8)
        let a = try MLMultiArray(dataPointer: raw, shape: [1, 2, 3], dataType: .float32,
                                 strides: [8, 4, 1]) { $0.deallocate() }
        XCTAssertEqual(BenchRunner.floats(a), [1, 2, 3, 4, 5, 6])
    }

    func testPassiQualsiasiElementoPerElemento() throws {
        // trasposta: passi [1, 2] su [2, 2]
        let raw = UnsafeMutablePointer<Float>.allocate(capacity: 4)
        raw.initialize(from: [1, 2, 3, 4], count: 4)
        let a = try MLMultiArray(dataPointer: raw, shape: [2, 2], dataType: .float32,
                                 strides: [1, 2]) { $0.deallocate() }
        XCTAssertEqual(BenchRunner.floats(a), [1, 3, 2, 4])
    }

    func testFp16AndataERitorno() throws {
        let raw = UnsafeMutablePointer<Float>.allocate(capacity: 3)
        raw.initialize(from: [0.5, -2, 1000], count: 3)
        let a = try MLMultiArray(dataPointer: raw, shape: [3], dataType: .float32, strides: [1]) { $0.deallocate() }
        let h = BenchRunner.halves(a)
        var back = [Float](repeating: 0, count: 3)
        back.withUnsafeMutableBufferPointer { BenchRunner.halfToFloat(h, into: $0.baseAddress!) }
        XCTAssertEqual(back, [0.5, -2, 1000])
    }
}
