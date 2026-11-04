import CoreGraphics
import CoreML
import XCTest

/// Il motore MobileVTONTryOn con Core ML vero sul Mac. Serve una cartella con
/// Models-6bit/ e Inputs/noise.bin (TEST_RUNNER_BENCH_ROOT) e la foto di prova
/// in ios/build/foto-corpo-test (non in git); senza, i test si saltano.
final class MobileVTONTryOnMacTests: XCTestCase {
    static let descriptor = "cream white cable-knit crew neck sweater with long sleeves, ribbed cuffs and hem, made of a soft chunky wool knit"

    private let ios = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private struct Setup {
        let engine: MobileVTONTryOn
        let person: CGImage
        let garment: CGImage
        let item: AvatarItem
        let workDir: URL
    }

    private func setup() throws -> Setup {
        guard let root = ProcessInfo.processInfo.environment["BENCH_ROOT"] else {
            throw XCTSkip("BENCH_ROOT non impostata")
        }
        let personURL = ios.appending(path: "build/foto-corpo-test/1-davanti.jpg")
        guard let personData = try? Data(contentsOf: personURL), let person = TryOnInputs.image(from: personData) else {
            throw XCTSkip("Manca la foto di prova \(personURL.path)")
        }
        let garmentData = try Data(contentsOf: ios.appending(path: "StyleVaultTests/Fixtures/maglione.jpg"))
        let garment = try XCTUnwrap(TryOnInputs.image(from: garmentData))
        let item = AvatarItem(id: "t", category: "top", slot: "top", photo: "", name: "Maglione",
                              descriptor: Self.descriptor)
        // common.DESC, parola per parola
        XCTAssertEqual(GarmentCaption.cloth(item),
                       "The item is a cream white cable-knit crew neck sweater with long sleeves, ribbed cuffs and hem, made of a soft chunky wool knit.")
        let noiseData = try Data(contentsOf: URL(filePath: root).appending(path: "Inputs/noise.bin"))
        let noise = noiseData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        XCTAssertEqual(noise.count, 16 * 128 * 96)
        let models = URL(filePath: root).appending(path: "Models-6bit")
        let tok = ios.appending(path: "StyleVaultTests/Fixtures/realistic/tokenizer")
        let workDir = FileManager.default.temporaryDirectory.appending(path: "tryon-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        let engine = MobileVTONTryOn(
            models: { models.appending(path: "\($0).mlmodelc") },
            tokenizer: (tok.appending(path: "vocab.json"), tok.appending(path: "merges.txt")),
            noise: noise, units: .cpuAndGPU, denoiserUnits: .cpuAndGPU, workDirectory: workDir)
        return Setup(engine: engine, person: person, garment: garment, item: item, workDir: workDir)
    }

    private final class Box<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: T
        init(_ v: T) { value = v }
        func mutate(_ f: (inout T) -> Void) { lock.withLock { f(&value) } }
        var get: T { lock.withLock { value } }
    }

    private func rgb(_ image: CGImage) -> [UInt8] {
        let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: p, count: image.width * image.height * 4))
    }

    private func psnr(_ a: CGImage, _ b: CGImage) -> Double {
        XCTAssertEqual(a.width, b.width); XCTAssertEqual(a.height, b.height)
        let x = rgb(a), y = rgb(b)
        var sum = 0.0, n = 0
        for i in stride(from: 0, to: x.count, by: 4) {
            for c in 0..<3 { let d = Double(x[i + c]) - Double(y[i + c]); sum += d * d; n += 1 }
        }
        let mse = sum / Double(n)
        return mse == 0 ? .infinity : 10 * log10(255 * 255 / mse)
    }

    func testMatchesPythonCoreML() async throws {
        let s = try setup()
        defer { try? FileManager.default.removeItem(at: s.workDir) }
        let start = Date()
        let fractions = Box<[Double]>([])
        let out = try await s.engine.generatePadded(person: s.person, garment: s.garment, item: s.item) { p in
            fractions.mutate { $0.append(p.fraction) }
            print("SVBENCH progresso \(p.fraction) — \(fmt(Date().timeIntervalSince(start))) s")
        }
        print("SVBENCH totale motore: \(fmt(Date().timeIntervalSince(start))) s")
        XCTAssertEqual(out.result.width, 768); XCTAssertEqual(out.result.height, 1024)
        let refURL = ios.deletingLastPathComponent().appending(path: "docs/verifiche/2026-11-03-avatar-realistico/coreml-6bit.png")
        let reference = try XCTUnwrap(TryOnInputs.image(from: Data(contentsOf: refURL)))
        let value = psnr(out.result, reference)
        print("SVBENCH PSNR contro coreml-6bit.png: \(value) dB")
        XCTAssertGreaterThanOrEqual(value, 35)
        // generate = generatePadded + unpad alla dimensione di person
        let final = TryOnInputs.unpad(out.result, content: out.content,
                                      to: CGSize(width: s.person.width, height: s.person.height))
        XCTAssertEqual(final.width, s.person.width); XCTAssertEqual(final.height, s.person.height)
    }

    func testProgressReachesOne() async throws {
        let s = try setup()
        defer { try? FileManager.default.removeItem(at: s.workDir) }
        let events = Box<[TryOnProgress]>([])
        let image = try await s.engine.generate(person: s.person, garment: s.garment, item: s.item) { p in
            events.mutate { $0.append(p) }
        }
        XCTAssertEqual(image.width, s.person.width); XCTAssertEqual(image.height, s.person.height)
        let e = events.get
        let f = e.map(\.fraction), loaded = e.map(\.loaded)
        XCTAssertEqual(f.last, 1)
        XCTAssertEqual(f, f.sorted(), "l'avanzamento non deve mai scendere")
        XCTAssertEqual(loaded, loaded.sorted())
        XCTAssertEqual(loaded.last, TryOnProgress.modelCount)
        for (a, b) in zip(e, e.dropFirst()) {
            XCTAssertTrue(b.fraction > a.fraction || b.loaded > a.loaded, "ogni aggiornamento deve far avanzare")
        }
        // fase 1, capo ×10, prova ×10, decoder, più una per ogni rete caricata
        XCTAssertEqual(e.count, 1 + 10 + 10 + 1 + TryOnProgress.modelCount)
    }

    func testCancellationStopsBetweenSteps() async throws {
        let s = try setup()
        defer { try? FileManager.default.removeItem(at: s.workDir) }
        let taskBox = Box<Task<CGImage, Error>?>(nil)
        let count = Box(0)
        let after = Box(0)
        let task = Task { () -> CGImage in
            try await s.engine.generate(person: s.person, garment: s.garment, item: s.item) { _ in
                count.mutate { $0 += 1 }
                if count.get == 3 { taskBox.get?.cancel() }
                if count.get > 3 { after.mutate { $0 += 1 } }
            }
        }
        taskBox.mutate { $0 = task }
        do {
            _ = try await task.value
            XCTFail("doveva essere annullata")
        } catch is CancellationError {
        }
        XCTAssertLessThanOrEqual(after.get, 1, "entro un passo dall'annullamento")
        let left = try FileManager.default.contentsOfDirectory(atPath: s.workDir.path)
        XCTAssertEqual(left, [], "la cartella delle feature temporanee non deve restare")
    }
}
