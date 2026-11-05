import StyleVaultCore
import SwiftUI
import UIKit

/// Le miniature già decodificate, per lato: la griglia non rilegge i JPEG a ogni scorrimento.
@MainActor private enum PhotoCache {
    private static var caches: [Int: NSCache<NSData, UIImage>] = [:]

    static func cache(maxSide: Int) -> NSCache<NSData, UIImage> {
        if let cache = caches[maxSide] { return cache }
        let cache = NSCache<NSData, UIImage>()
        cache.countLimit = 200
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
            Palette.surface
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if data == nil {
                Text(verbatim: ItemText.placeholderInitial(name))
                    .font(.display(44))
                    .foregroundStyle(Palette.muted)
            }
        }
        .clipped()
        .task(id: data) { await load() }
    }

    private func load() async {
        guard let data else {
            image = nil
            return
        }
        let cache = PhotoCache.cache(maxSide: maxSide)
        if let cached = cache.object(forKey: data as NSData) {
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
        let result = UIImage(cgImage: decoded)
        cache.setObject(result, forKey: data as NSData)
        image = result
    }
}
