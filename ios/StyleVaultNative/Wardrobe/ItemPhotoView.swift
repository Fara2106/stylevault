import StyleVaultCore
import SwiftUI
import UIKit

/// Le immagini già decodificate, per lato: la griglia non rilegge i JPEG a ogni scorrimento.
@MainActor enum PhotoCache {
    /// Per cache: una foto del dettaglio decodificata pesa 13 MB, una miniatura meno di uno.
    private static let byteLimit = 100 * 1024 * 1024
    private static var caches: [Int: NSCache<NSData, UIImage>] = [:]

    static func image(for data: Data, maxSide: Int) -> UIImage? {
        cache(maxSide: maxSide).object(forKey: data as NSData)
    }

    @discardableResult
    static func store(_ image: CGImage, for data: Data, maxSide: Int) -> UIImage {
        let result = UIImage(cgImage: image)
        cache(maxSide: maxSide).setObject(result, forKey: data as NSData, cost: image.bytesPerRow * image.height)
        return result
    }

    private static func cache(maxSide: Int) -> NSCache<NSData, UIImage> {
        if let cache = caches[maxSide] { return cache }
        let cache = NSCache<NSData, UIImage>()
        cache.totalCostLimit = byteLimit
        caches[maxSide] = cache
        return cache
    }
}

/// La foto di un capo, o l'iniziale del nome se non ce l'ha.
struct ItemPhotoView: View {
    let data: Data?
    let name: String
    var maxSide = GarmentImage.thumbnailMaxSide
    var contentMode = ContentMode.fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            isCutout ? Palette.studio : Palette.surface
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if data == nil {
                Text(verbatim: ItemText.placeholderInitial(name))
                    .font(.display(44))
                    .foregroundStyle(Palette.muted)
                    // Decorativa: il nome sta scritto accanto, VoiceOver non deve leggere anche la lettera.
                    .accessibilityHidden(true)
            }
        }
        .clipped()
        .task(id: data) { await load() }
    }

    /// Lo scontorno è l'unica immagine con la trasparenza: le foto sono JPEG.
    private var isCutout: Bool {
        switch image?.cgImage?.alphaInfo {
        case nil, .none?, .noneSkipLast?, .noneSkipFirst?: false
        default: true
        }
    }

    private func load() async {
        guard let data else {
            image = nil
            return
        }
        if let cached = PhotoCache.image(for: data, maxSide: maxSide) {
            image = cached
            return
        }
        let side = maxSide
        let decoded = await Task.detached(priority: .userInitiated) { GarmentImage.thumbnail(data, maxSide: side) }.value
        guard !Task.isCancelled else { return }
        guard let decoded else {
            image = nil
            return
        }
        image = PhotoCache.store(decoded, for: data, maxSide: side)
    }
}
