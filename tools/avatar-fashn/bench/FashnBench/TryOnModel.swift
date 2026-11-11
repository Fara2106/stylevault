import CoreGraphics
import CoreML
import FashnKit
import FashnWorn
import Foundation
import ImageIO
import Observation
import PhotosUI
import SwiftUI

/// La prova vera: una foto della persona e una del capo scelte dal telefono, posa con Apple Vision, generazione con FASHN.
@MainActor @Observable final class TryOnModel {
    enum Phase: Equatable { case idle, preparing, loadingModel, generating, done, failed(String) }

    /// Com'è la foto del capo. Addosso a qualcuno, di base il capo si isola: la foto intera porta nel risultato anche la
    /// pelle di chi lo indossa.
    enum GarmentPhotoKind: Hashable { case alone, wornIsolated, wornWhole }

    var personItem: PhotosPickerItem? { didSet { load(personItem) { self.person = $0 } } }
    var garmentItem: PhotosPickerItem? { didSet { load(garmentItem) { self.garment = $0 } } }
    private(set) var person: CGImage?
    private(set) var garment: CGImage?
    var category = GarmentCategory.tops
    var garmentKind = GarmentPhotoKind.alone
    var steps = 20

    private(set) var phase = Phase.idle
    private(set) var progress: FashnProgress?
    private(set) var result: CGImage?
    private(set) var poseSketch: CGImage?
    /// Il capo come lo ha ricevuto il modello, quando è stato isolato da chi lo indossava.
    private(set) var isolatedGarment: CGImage?
    private(set) var bodyPoints = 0
    private(set) var summary = ""
    private(set) var elapsed: TimeInterval = 0
    /// Il telefono è troppo caldo: la generazione aspetta che si raffreddi.
    private(set) var coolingDown = false

    /// Lo stato termico in parole: la generazione tiene la GPU al massimo per un paio di minuti.
    static func thermalName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "normale"
        case .fair: return "tiepido"
        case .serious: return "caldo"
        case .critical: return "molto caldo"
        @unknown default: return "?"
        }
    }

    private var sampler: FashnSampler?
    private var task: Task<Void, Never>?
    private var startedAt = Date()
    private var clock: Timer?

    var isBusy: Bool { [.preparing, .loadingModel, .generating].contains(phase) }
    var canGenerate: Bool { person != nil && garment != nil && !isBusy }

    private func load(_ item: PhotosPickerItem?, into set: @escaping (CGImage?) -> Void) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return set(nil) }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                            kCGImageSourceThumbnailMaxPixelSize: 2048]
            let image = CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary) }
            set(image)
        }
    }

    func generate() {
        guard let person, let garment, !isBusy else { return }
        let category = category, kind = garmentKind, steps = steps
        result = nil
        poseSketch = nil
        isolatedGarment = nil
        progress = nil
        summary = ""
        phase = .preparing
        startedAt = Date()
        elapsed = 0
        clock?.invalidate()
        clock = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in if let self, self.isBusy { self.elapsed = Date().timeIntervalSince(self.startedAt) } }
        }
        UIApplication.shared.isIdleTimerDisabled = true
        let existing = sampler
        task = Task {
            let peak = PeakMemory()
            peak.start()
            defer { peak.stop(); UIApplication.shared.isIdleTimerDisabled = false; clock?.invalidate() }
            do {
                let prepareStart = Date()
                var garmentPhoto = garment
                var note = ""
                var whole = kind == .wornWhole
                if kind == .wornIsolated {
                    let prepared = await WornGarmentPhoto.prepared(garment, category: category)
                    garmentPhoto = prepared.image
                    whole = !prepared.isolated
                    isolatedGarment = prepared.isolated ? prepared.image : nil
                    note = prepared.isolated ? " Capo isolato." : " Capo non isolato: usata la foto intera."
                }
                let readyGarment = garmentPhoto, wholeWornPhoto = whole
                let inputs = try await Task.detached(priority: .userInitiated) {
                    try FashnPrepare.inputs(person: person, garment: readyGarment, category: category, garmentIsWorn: wholeWornPhoto)
                }.value
                let prepareSeconds = Date().timeIntervalSince(prepareStart)
                bodyPoints = inputs.bodyPointsFound
                poseSketch = Self.image(inputs.personPoseSketch)

                phase = .loadingModel
                let loadStart = Date()
                let sampler: FashnSampler
                if let existing {
                    sampler = existing
                } else {
                    guard let url = Bundle.main.url(forResource: "bench-payload", withExtension: nil)?.appendingPathComponent("FashnTryOn.mlmodelc") else {
                        throw FashnError.model("manca il modello nel pacchetto")
                    }
                    sampler = try await Task.detached(priority: .userInitiated) { try FashnSampler(modelURL: url) }.value
                    self.sampler = sampler
                }
                let loadSeconds = Date().timeIntervalSince(loadStart)

                phase = .generating
                let generationStart = Date()
                let seed = UInt64.random(in: 0...UInt64.max)
                let thermalBefore = ProcessInfo.processInfo.thermalState
                UIDevice.current.isBatteryMonitoringEnabled = true
                let batteryBefore = UIDevice.current.batteryLevel
                let work = Task.detached(priority: .userInitiated) {
                    try sampler.generate(inputs, steps: steps, seed: seed) { value in
                        Task { @MainActor in self.progress = value }
                        // Da «caldo» in su si aspetta tra un passaggio e l'altro: meglio più lenta che un telefono che scotta
                        var waited = false
                        while ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue, !Task.isCancelled {
                            if !waited { waited = true; Task { @MainActor in self.coolingDown = true } }
                            Thread.sleep(forTimeInterval: 1)
                        }
                        if waited { Task { @MainActor in self.coolingDown = false } }
                    }
                }
                let output = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
                let generationSeconds = Date().timeIntervalSince(generationStart)
                result = FashnPrepare.image(fromOutput: output, frame: inputs.personFrame)
                elapsed = Date().timeIntervalSince(startedAt)
                summary = String(format: "%d passi in %.0f s (preparazione %.1f s, modello %.1f s). Memoria di picco %.0f MB. Punti del corpo %d su 18.",
                                 steps, generationSeconds, prepareSeconds, loadSeconds, peak.value, inputs.bodyPointsFound) + note
                let batteryAfter = UIDevice.current.batteryLevel
                summary += " Temperatura: da \(Self.thermalName(thermalBefore)) a \(Self.thermalName(ProcessInfo.processInfo.thermalState))."
                if batteryBefore >= 0, batteryAfter >= 0 {
                    summary += String(format: " Batteria: %.0f%% → %.0f%%.", batteryBefore * 100, batteryAfter * 100)
                }
                print("FASHN \(summary)")
                phase = .done
            } catch is CancellationError {
                coolingDown = false
                phase = .idle
            } catch {
                phase = .failed("\(error)")
            }
        }
    }

    func cancel() { task?.cancel() }

    /// Il risultato diventa la persona: così si aggiunge un secondo capo (prima il sopra, poi il sotto).
    func useResultAsPerson() {
        guard let result, !isBusy else { return }
        personItem = nil
        person = result
        self.result = nil
        isolatedGarment = nil
        phase = .idle
    }

    #if targetEnvironment(simulator)
    /// Sul simulatore il modello non gira: `--finta` fa scorrere la barra per guardarla.
    func fakeProgress() {
        phase = .generating
        startedAt = Date()
        task = Task {
            let total = FashnProgress.passes(steps: steps)
            for pass in 0...total {
                progress = FashnProgress(step: (pass + 1) / 2, steps: steps, passesDone: pass, passesTotal: total)
                elapsed = Date().timeIntervalSince(startedAt)
                try? await Task.sleep(for: .milliseconds(400))
                if Task.isCancelled { break }
            }
            phase = .idle
        }
    }
    #endif

    private static func image(_ canvas: GrayCanvas) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(canvas.pixels) as CFData) else { return nil }
        return CGImage(width: canvas.width, height: canvas.height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: canvas.width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
