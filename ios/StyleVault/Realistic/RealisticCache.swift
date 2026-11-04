import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Viste realistiche già calcolate (Caches/realistic/<capo>-<vista>-<corpo>-<impronta>.png):
/// riaprendo lo stesso outfit compaiono subito. La chiave è il capo usato, la
/// vista, la foto del corpo (`bodyKey`, la stessa chiave dello scontorno) e
/// un'impronta di foto del capo, descrizione e versione dei modelli: se cambia
/// una di queste cose si rigenera.
actor RealisticCache {
    /// Da cambiare quando cambiano i modelli della Release o i parametri del calcolo.
    static let modelVersion = "\(RealisticModelStore.release)-p1"

    static let shared = RealisticCache(
        folder: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "realistic", directoryHint: .isDirectory))

    private let folder: URL

    init(folder: URL) {
        self.folder = folder
    }

    func image(item: AvatarItem, view: BodyView, bodyKey: String) -> CGImage? {
        let file = url(item: item, view: view, bodyKey: bodyKey)
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    func store(_ image: CGImage, item: AvatarItem, view: BodyView, bodyKey: String) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = url(item: item, view: view, bodyKey: bodyKey)
        // Si scrive accanto e si sposta: un file a metà non viene mai letto
        let temp = folder.appending(path: ".\(UUID().uuidString).png")
        guard let dest = CGImageDestinationCreateWithURL(temp as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { try? FileManager.default.removeItem(at: temp); return }
        let fm = FileManager.default
        if fm.fileExists(atPath: file.path) {
            _ = try? fm.replaceItemAt(file, withItemAt: temp)
        } else {
            try? fm.moveItem(at: temp, to: file)
        }
        try? fm.removeItem(at: temp)
    }

    private func url(item: AvatarItem, view: BodyView, bodyKey: String) -> URL {
        folder.appending(path: Self.key(item: item, view: view, bodyKey: bodyKey) + ".png")
    }

    /// Nome del file (senza estensione).
    static func key(item: AvatarItem, view: BodyView, bodyKey: String) -> String {
        "\(safe(item.id))-\(view.rawValue)-\(safe(bodyKey))-\(fingerprint(item: item, view: view))"
    }

    /// Chiave dello scontorno del risultato in CutoutCache (`realistic-…`).
    static func cutoutKey(item: AvatarItem, view: BodyView, bodyKey: String) -> String {
        "realistic-" + key(item: item, view: view, bodyKey: bodyKey)
    }

    /// Impronta breve della foto del capo usata per la vista (la parte stabile
    /// dell'indirizzo, come `CutoutCache.key`), della descrizione e della versione dei modelli.
    static func fingerprint(item: AvatarItem, view: BodyView) -> String {
        let photo = AvatarModel.garmentImageURL(item, view: view).map { url in
            url.host.map { $0 + url.path } ?? url.absoluteString
        } ?? ""
        let text = [photo, item.descriptor ?? "", modelVersion].joined(separator: "\n")
        let hash = text.unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1.value) }
        return String(hash, radix: 36)
    }

    /// Solo lettere, cifre, "-" e "_": gli id sono UUID, ma non ci si fida.
    static func safe(_ text: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let cleaned = String(text.map { allowed.contains($0) ? $0 : "_" }.prefix(80))
        return cleaned.isEmpty ? "_" : cleaned
    }
}
