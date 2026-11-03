import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Scontorni salvati su disco (Caches/cutouts/<chiave>.png): la seconda
/// apertura dell'avatar non rifà né download né Vision.
actor CutoutCache {
    static let shared = CutoutCache()

    private var memory = [String: Cutout]()
    private let folder: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("cutouts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// - allInstances: true per i capi (un paio di scarpe), false per la persona.
    func cutout(for url: URL, key: String, allInstances: Bool) async throws -> Cutout {
        if let hit = memory[key] { return hit }
        let file = folder.appendingPathComponent("\(key).png")
        // Accanto al PNG il numero di soggetti: un paio di scarpe (2) si
        // disegna diverso da una scarpa sola (1)
        let countFile = folder.appendingPathComponent("\(key).count")
        if let image = Self.load(file) {
            let count = (try? String(contentsOf: countFile, encoding: .utf8)).flatMap(Int.init) ?? 1
            let cached = Cutout(image: image, bounds: PersonCutout.opaqueBounds(image), instanceCount: count)
            memory[key] = cached
            return cached
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let raw = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw URLError(.cannotDecodeContentData)
        }
        let result = try await PersonCutout.cutout(ImagePrep.downscaled(raw), allInstances: allInstances)
        Self.save(result.image, to: file)
        try? String(result.instanceCount).write(to: countFile, atomically: true, encoding: .utf8)
        memory[key] = result
        return result
    }

    /// Chiave stabile: le URL firmate cambiano a ogni login, il percorso no.
    static func key(_ prefix: String, _ url: URL) -> String {
        let stable = url.host.map { $0 + url.path } ?? url.absoluteString
        let hash = stable.unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1.value) }
        return "\(prefix)-\(String(hash, radix: 36))"
    }

    private static func load(_ file: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func save(_ image: CGImage, to file: URL) {
        guard let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
