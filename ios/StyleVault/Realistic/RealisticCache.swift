import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Viste realistiche già calcolate (Caches/realistic/<capo>-<vista>-<corpo>-v1.png):
/// riaprendo lo stesso outfit compaiono subito. La chiave è il capo usato, la
/// vista e la foto del corpo (`bodyKey`, la stessa chiave dello scontorno):
/// se si rifanno le foto o si cambia capo, si rigenera.
actor RealisticCache {
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
        folder.appending(path: "\(Self.safe(item.id))-\(view.rawValue)-\(Self.safe(bodyKey))-v1.png")
    }

    /// Chiave dello scontorno del risultato in CutoutCache (`realistic-…`).
    static func cutoutKey(item: AvatarItem, view: BodyView, bodyKey: String) -> String {
        "realistic-\(safe(item.id))-\(view.rawValue)-\(safe(bodyKey))-v1"
    }

    /// Solo lettere, cifre, "-" e "_": gli id sono UUID, ma non ci si fida.
    static func safe(_ text: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let cleaned = String(text.map { allowed.contains($0) ? $0 : "_" }.prefix(80))
        return cleaned.isEmpty ? "_" : cleaned
    }
}
