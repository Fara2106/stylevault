import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Scontorni salvati su disco (Caches/cutouts/<chiave>.png): la seconda
/// apertura dell'avatar non rifà Vision. Sono rigenerabili: stanno in Caches, fuori da iCloud.
public actor CutoutCache {
    public static let shared = CutoutCache()

    private var memory = [String: Cutout]()
    /// Dal meno recente al più recente: quando si supera il limite esce il primo.
    private var usage: [String] = []
    private let memoryLimit: Int
    private let folder: URL

    var keysInMemory: [String] { usage }

    /// - folder: dove salvare (i test ne usano una temporanea); di base Caches/cutouts.
    /// - memoryLimit: byte di immagini tenuti in memoria. Un outfit pesa circa 120 MB: ne stanno un paio,
    ///   il resto si ricarica dal disco. Senza limite, provare molti outfit di fila chiude l'app.
    public init(folder: URL? = nil, memoryLimit: Int = 256 * 1024 * 1024) {
        self.memoryLimit = memoryLimit
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
        if let hit = memory[key] {
            remember(hit, key: key)
            return hit
        }
        // Accanto al PNG il numero di soggetti: un paio di scarpe (2) si
        // disegna diverso da una scarpa sola (1)
        guard let image = Self.load(file(key)) else { return nil }
        let count = (try? String(contentsOf: countFile(key), encoding: .utf8)).flatMap(Int.init) ?? 1
        let cached = Cutout(image: image, bounds: PersonCutout.opaqueBounds(image), instanceCount: count)
        remember(cached, key: key)
        return cached
    }

    private func make(_ raw: CGImage, key: String, allInstances: Bool) async throws -> Cutout {
        let result = try await PersonCutout.cutout(ImagePrep.downscaled(raw), allInstances: allInstances)
        Self.save(result.image, to: file(key))
        try? String(result.instanceCount).write(to: countFile(key), atomically: true, encoding: .utf8)
        remember(result, key: key)
        return result
    }

    /// Solo il capo, se la foto lo mostra addosso a qualcuno (vedi `WornGarment`); nil se va usato intero.
    /// Si salva anche l'esito negativo: la seconda apertura non rifà Vision.
    public func piece(photo: CGImage, cutout: Cutout, key: String, slot: String) async -> GarmentPiece? {
        let name = "\(key)-\(slot)-\(Self.pieceVersion)"
        if let hit = pieces[name] { return hit }
        if FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(name).nessuno").path) { return nil }
        if let image = Self.load(file(name)) {
            let data = try? Data(contentsOf: folder.appendingPathComponent("\(name).posa"))
            let piece = GarmentPiece(image: image, pose: data.flatMap(Self.decodePose))
            rememberPiece(piece, name: name)
            return piece
        }
        guard let piece = await WornGarment.piece(from: cutout, photo: photo, slot: slot) else {
            FileManager.default.createFile(atPath: folder.appendingPathComponent("\(name).nessuno").path, contents: nil)
            return nil
        }
        Self.save(piece.image, to: file(name))
        if let pose = piece.pose { try? Self.encodePose(pose).write(to: folder.appendingPathComponent("\(name).posa")) }
        rememberPiece(piece, name: name)
        return piece
    }

    /// Cambia quando cambia il modo di ritagliare: i ritagli vecchi non si usano più.
    static let pieceVersion = "capo2"
    private var pieces = [String: GarmentPiece]()
    private var pieceUsage: [String] = []

    private func rememberPiece(_ piece: GarmentPiece, name: String) {
        pieces[name] = piece
        pieceUsage.removeAll { $0 == name }
        pieceUsage.append(name)
        while pieceUsage.count > 24 { pieces.removeValue(forKey: pieceUsage.removeFirst()) }
    }

    static func encodePose(_ pose: Pose) -> Data {
        let values = Dictionary(uniqueKeysWithValues: pose.points.map { ("\($0.key)", [Double($0.value.x), Double($0.value.y)]) })
        return (try? JSONSerialization.data(withJSONObject: values)) ?? Data()
    }

    static func decodePose(_ data: Data) -> Pose? {
        guard let values = (try? JSONSerialization.jsonObject(with: data)) as? [String: [Double]] else { return nil }
        var points = [Joint: CGPoint]()
        for joint in Joint.allCases {
            if let v = values["\(joint)"], v.count == 2 { points[joint] = CGPoint(x: v[0], y: v[1]) }
        }
        return points.isEmpty ? nil : Pose(points: points)
    }

    private func remember(_ cutout: Cutout, key: String) {
        memory[key] = cutout
        usage.removeAll { $0 == key }
        usage.append(key)
        var used = usage.reduce(0) { $0 + (memory[$1].map(Self.bytes) ?? 0) }
        while used > memoryLimit, usage.count > 1 {
            let oldest = usage.removeFirst()
            used -= memory.removeValue(forKey: oldest).map(Self.bytes) ?? 0
        }
    }

    private static func bytes(_ cutout: Cutout) -> Int { cutout.image.bytesPerRow * cutout.image.height }

    /// Una foto del corpo cancellata non deve restare nemmeno come scontorno.
    public func removeAll(prefix: String) {
        memory = memory.filter { !$0.key.hasPrefix(prefix) }
        usage.removeAll { $0.hasPrefix(prefix) }
        pieces = pieces.filter { !$0.key.hasPrefix(prefix) }
        pieceUsage.removeAll { $0.hasPrefix(prefix) }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where name.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    /// Tiene solo gli scontorni delle foto del corpo che esistono ancora. Una foto cancellata o cambiata su un
    /// altro dispositivo arriva da iCloud senza passare dall'editor: qui i suoi scontorni resterebbero.
    public func keepBodyCutouts(for keys: Set<String>) {
        func isStale(_ name: String) -> Bool { name.hasPrefix("body-") && !keys.contains { name.hasPrefix($0) } }
        memory = memory.filter { !isStale($0.key) }
        usage.removeAll(where: isStale)
        pieces = pieces.filter { !isStale($0.key) }
        pieceUsage.removeAll(where: isStale)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where isStale(name) {
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
