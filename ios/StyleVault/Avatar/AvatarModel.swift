import Foundation

enum AvatarModel {
    /// Foto del capo per la vista: di spalle il retro se c'è, altrimenti il davanti.
    static func garmentImageURL(_ item: AvatarItem, view: BodyView) -> URL? {
        let back = item.photoBack?.isEmpty == false ? item.photoBack : nil
        let raw = view == .back ? (back ?? item.photo) : item.photo
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
              ["https", "http", "data"].contains(scheme) else { return nil }
        return url
    }
}
