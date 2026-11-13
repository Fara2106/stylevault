import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Le immagini generate, per non rifare minuti di lavoro quando si riapre lo stesso outfit.
/// Stanno nella cartella Caches del dispositivo: non vanno in iCloud e il sistema può cancellarle.
enum RealisticCache {
    /// Cambia se cambia il modo di generare: le immagini vecchie non si riusano.
    static let version = "v1-\(SystemRealisticGenerator.steps)"

    static var folder: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("realistic", isDirectory: true)
    }

    /// Stessa foto del corpo e stessi capi nello stesso ordine: stessa chiave. Il nome comincia con il segno
    /// della foto del corpo, così dal nome del file si sa con quale foto è stata fatta l'immagine.
    static func key(bodyKey: String, pieces: [RealisticPlan.Piece]) -> String {
        let text = ([version, bodyKey] + pieces.map { "\($0.slot):\($0.key)" }).joined(separator: "|")
        return owner(bodyKey) + hex(text)
    }

    private static func owner(_ bodyKey: String) -> String { "\(hex(bodyKey).prefix(16))-" }

    private static func hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func load(_ key: String, in folder: URL = folder) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(folder.appendingPathComponent("\(key).png") as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func save(_ image: CGImage, key: String, in folder: URL = folder) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent("\(key).png") as CFURL,
                                                                UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    /// Quando cambia la foto del corpo le immagini generate non valgono più.
    static func removeAll(in folder: URL = folder) {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Le immagini valgono per una foto del corpo: quelle fatte con un'altra, da qualsiasi dispositivo sia
    /// arrivata la modifica, si tolgono. Si guarda il nome di ogni file, non un segno salvato a parte: così
    /// anche un'immagine arrivata tardi, o una pulizia non riuscita, si sistema al controllo dopo.
    /// `bodyKey` è vuota quando la foto non c'è.
    static func keep(for bodyKey: String, in folder: URL = folder) {
        guard !bodyKey.isEmpty else { return removeAll(in: folder) }
        let mine = owner(bodyKey)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where !name.hasPrefix(mine) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}
