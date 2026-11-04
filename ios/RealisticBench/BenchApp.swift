import CoreML
import SwiftUI
import UIKit

@main
struct BenchApp: App {
    var body: some Scene {
        WindowGroup { BenchView() }
    }
}

/// Una schermata: scegli telefono e unità di calcolo, tocca "Misura". Ogni riga
/// finisce anche nella console di Xcode/devicectl col prefisso SVBENCH.
struct BenchView: View {
    @State private var device: BenchDevice = Self.guessDevice()
    @State private var units = 0
    @State private var lines: [String] = []
    @State private var running = false
    @State private var phases: Set<Int>?
    @State private var generated: CGImage?

    // Mista: tutto sul Neural Engine tranne la UNet di prova, sulla GPU
    private let unitChoices: [(String, MLComputeUnits, MLComputeUnits?)] = [
        ("Neural Engine", .cpuAndNeuralEngine, nil), ("GPU", .cpuAndGPU, nil),
        ("Mista", .cpuAndNeuralEngine, .cpuAndGPU), ("CPU", .cpuOnly, nil)]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Telefono", selection: $device) {
                    Text(BenchDevice.iPhone18ProMax.rawValue).tag(BenchDevice.iPhone18ProMax)
                    Text(BenchDevice.iPhone15Pro.rawValue).tag(BenchDevice.iPhone15Pro)
                    Text(BenchDevice.iPad.rawValue).tag(BenchDevice.iPad)
                }
                Picker("Unità di calcolo", selection: $units) {
                    ForEach(unitChoices.indices, id: \.self) { Text(unitChoices[$0].0).tag($0) }
                }
                .pickerStyle(.segmented)
                Button(running ? "Misuro…" : "Misura") { Task { await run() } }
                    .disabled(running)
                Button("Genera la vista davanti") { Task { await generate() } }
                    .disabled(running)
                if let generated {
                    Image(decorative: generated, scale: 1).resizable().scaledToFit()
                }
                Section("Risultati") {
                    ForEach(lines.indices, id: \.self) { Text(lines[$0]).font(.caption.monospaced()) }
                }
            }
            .navigationTitle("RealisticBench")
            .task {
                // Avvio da Mac senza toccare il telefono:
                // devicectl … launch <bundle> --units gpu|ane|mix|cpu [--models 6bit] [--phases 2,3] [--generate] [--split]
                let args = ProcessInfo.processInfo.arguments
                func value(_ key: String) -> String? {
                    args.firstIndex(of: key).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
                }
                guard let u = value("--units") else { return }
                units = ["ane": 0, "gpu": 1, "mix": 2, "cpu": 3][u] ?? 1
                if value("--models") == "6bit" { BenchRunner.folder = "Models-6bit" }
                BenchRunner.splitGuidance = args.contains("--split")
                phases = value("--phases").map { Set($0.split(separator: ",").compactMap { Int($0) }) }
                if args.contains("--generate") { await generate() } else { await run() }
            }
        }
    }

    private func run() async {
        running = true
        defer { running = false }
        let (label, mlUnits, denoiserUnits) = unitChoices[units]
        let device = device
        log("— \(device.rawValue), \(label) —")
        do {
            let r = try await BenchRunner.measure(units: mlUnits, denoiserUnits: denoiserUnits,
                                                  phases: phases) { line in
                Task { @MainActor in log(line) }
            }
            let estimate = BenchEstimate.frontView(r.steady, steps: 10)
            let warmup = BenchEstimate.firstRunExtra(first: r.firstRun, steady: r.steady)
            let verdict = BenchEstimate.passes(seconds: estimate, device: device) ? "PASSA" : "NON PASSA"
            log("vista davanti stimata (10 passi): \(fmt(estimate)) s; al primo avvio + \(fmt(warmup)) s di preparazione")
            log("caricamento totale: \(fmt(r.loadSeconds.values.reduce(0, +))) s")
            log("memoria di picco: \(fmt(r.peakMemoryMB)) MB")
            log("\(verdict) (soglia \(Int(BenchEstimate.limit(device))) s, \(label))")
        } catch {
            log("ERRORE: \(error.localizedDescription)")
        }
    }

    /// La generazione vera con gli ingressi esportati dal Mac: immagine a schermo
    /// e in Documents/Output, tempi per fase.
    private func generate() async {
        running = true
        defer { running = false }
        let (label, mlUnits, denoiserUnits) = unitChoices[units]
        log("— generazione, \(label), \(BenchRunner.folder) —")
        do {
            let out = try await BenchGenerator.run(units: mlUnits, denoiserUnits: denoiserUnits) { line in
                Task { @MainActor in log(line) }
            }
            generated = out.image
            for (name, s) in out.seconds { log("\(name): \(fmt(s)) s") }
            log("generazione completa: \(fmt(out.total)) s → \(out.png.lastPathComponent)")
        } catch {
            log("ERRORE: \(error.localizedDescription)")
        }
    }

    @MainActor private func log(_ line: String) {
        lines.append(line)
        print("SVBENCH \(line)")
        fflush(stdout)
    }

    /// iPad dall'idioma; iPhone16,1 è il 15 Pro di Mary; il resto è il 18 Pro Max di Lorenzo.
    private static func guessDevice() -> BenchDevice {
        if UIDevice.current.userInterfaceIdiom == .pad { return .iPad }
        var info = utsname()
        uname(&info)
        let id = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return id == "iPhone16,1" ? .iPhone15Pro : .iPhone18ProMax
    }
}
