import CoreML
import XCTest

/// La generazione Swift di RealisticBench fatta girare sul Mac (il simulatore
/// non ce la fa: il Mac da 16 GB finisce lo swap). Serve una cartella con
/// Models*/ (modelli compilati) e Inputs/ (export_bench_inputs.py), passata con
/// TEST_RUNNER_BENCH_ROOT; senza, il test si salta.
final class GenerationMacTests: XCTestCase {
    func testGenerazioneVistaDavanti() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let root = env["BENCH_ROOT"] else { throw XCTSkip("BENCH_ROOT non impostata") }
        BenchRunner.root = URL(filePath: root)
        BenchRunner.folder = env["BENCH_MODELS"] ?? "Models"
        BenchRunner.splitGuidance = env["BENCH_SPLIT"] == "1"
        let out = try await BenchGenerator.run(units: .cpuAndGPU, denoiserUnits: nil) { print("SVBENCH \($0)") }
        for (name, s) in out.seconds { print("SVBENCH \(name): \(fmt(s)) s") }
        print("SVBENCH totale \(fmt(out.total)) s → \(out.png.path)")
        XCTAssertEqual(out.image.width, 768)
        XCTAssertEqual(out.image.height, 1024)
    }
}
