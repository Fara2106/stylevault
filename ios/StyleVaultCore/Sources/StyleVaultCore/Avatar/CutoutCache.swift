import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Scontorni salvati su disco (Caches/cutouts/<chiave>.png): la seconda
/// apertura dell'avatar non rifà Vision. Sono rigenerabili: stanno in Caches, fuori da iCloud.
public actor CutoutCache {
    public static let shared = CutoutCache()

    private var memory = [String: Cutout]()
    private let folder: URL

    /// - folder: dove salvare (i test ne usano una temporanea); di base Caches/cutouts.
    public init(folder: URL? = nil) {
        let dir = folder ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cutouts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.folder = dir
    }

    /// - allInstances: true per i capi (un paio di scarpe), false per la persona.
    public func cutout(image: CGImage, key: String, allInstances: Bool) async throws -> Cutout {
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
        memory[key] = cached
        return cached
    }

    private func make(_ raw: CGImage, key: String, allInstances: Bool) async throws -> Cutout {
        let result = try await PersonCutout.cutout(ImagePrep.downscaled(raw), allInstances: allInstances)
        Self.save(result.image, to: file(key))
        try? String(result.instanceCount).write(to: countFile(key), atomically: true, encoding: .utf8)
        memory[key] = result
        return result
    }

    /// Una foto del corpo cancellata non deve restare nemmeno come scontorno.
    public func removeAll(prefix: String) {
        memory = memory.filter { !$0.key.hasPrefix(prefix) }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where name.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    private func file(_ key: String) -> URL { folder.appendingPathComponent("\(key).png") }
    private func countFile(_ key: String) -> URL { folder.appendingPathComponent("\(key).count") }

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
