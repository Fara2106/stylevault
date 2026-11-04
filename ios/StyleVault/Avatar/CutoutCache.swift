import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Scontorni salvati su disco (Caches/cutouts/<chiave>.png): la seconda
/// apertura dell'avatar non rifà né download né Vision.
actor CutoutCache {
    static let shared = CutoutCache()

    private var memory = [String: Cutout]()
    private let folder: URL

    /// - folder: dove salvare (i test ne usano una temporanea); di base Caches/cutouts.
    init(folder: URL? = nil) {
        let dir = folder ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cutouts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.folder = dir
    }

    /// - allInstances: true per i capi (un paio di scarpe), false per la persona.
    func cutout(for url: URL, key: String, allInstances: Bool) async throws -> Cutout {
        if let hit = cached(key) { return hit }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let raw = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw URLError(.cannotDecodeContentData)
        }
        return try await make(raw, key: key, allInstances: allInstances)
    }

    /// Scontorno di un'immagine già in memoria (il risultato realistico), ridotta
    /// come le foto: resta allineata pixel per pixel con l'immagine data.
    func cutout(image: CGImage, key: String, allInstances: Bool) async throws -> Cutout {
        if let hit = cached(key) { return hit }
        return try await make(image, key: key, allInstances: allInstances)
    }

    private func cached(_ key: String) -> Cutout? {
        if let hit = memory[key] { return hit }
        // Accanto al PNG il numero di soggetti: un paio di scarpe (2) si
        // disegna diverso da una scarpa sola (1)
        guard let image = Self.load(file(key)) else { return nil }
        let count = (try? String(contentsOf: countFile(key), encoding: .utf8)).flatMap(Int.init) ?? 1
        let cached = Cutout(image: image, bounds: PersonCutout.opaqueBounds(image), instanceCount: count)
        remember(cached, key)
        return cached
    }

    private func make(_ raw: CGImage, key: String, allInstances: Bool) async throws -> Cutout {
        let result = try await PersonCutout.cutout(ImagePrep.downscaled(raw), allInstances: allInstances)
        Self.save(result.image, to: file(key))
        try? String(result.instanceCount).write(to: countFile(key), atomically: true, encoding: .utf8)
        remember(result, key)
        return result
    }

    /// Gli scontorni del risultato realistico (`realistic-…`, fino a 2048 px, uno
    /// per vista) restano solo su disco: la vista composta li ha già dentro.
    private func remember(_ cutout: Cutout, _ key: String) {
        guard !key.hasPrefix("realistic-") else { return }
        memory[key] = cutout
    }

    private func file(_ key: String) -> URL { folder.appendingPathComponent("\(key).png") }
    private func countFile(_ key: String) -> URL { folder.appendingPathComponent("\(key).count") }

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
