import Foundation

/// Capo da mostrare sull'avatar, come lo manda il sito (nativeBridge.js).
struct AvatarItem: Decodable, Equatable {
    let id: String
    let category: String
    let slot: String
    let photo: String
    let name: String
    let photoBack: String?
    /// Descrizione inglese breve del capo (es. "cream sweater"), per la didascalia
    /// dell'avatar realistico. Assente nei payload più vecchi.
    let descriptor: String?

    init(id: String, category: String, slot: String, photo: String, name: String,
         photoBack: String? = nil, descriptor: String? = nil) {
        self.id = id; self.category = category; self.slot = slot
        self.photo = photo; self.name = name
        self.photoBack = photoBack; self.descriptor = descriptor
    }
}

struct AvatarRequest: Decodable, Equatable {
    let items: [AvatarItem]
}

/// Messaggi dal sito al nativo: { type, payload } sull'handler "svNative".
enum BridgeMessage: Equatable {
    case openAvatar(AvatarRequest)
    case openBodyPhotos
    case ready
    case signOut
    case themeChanged(String)

    static func parse(_ body: Any) -> BridgeMessage? {
        guard let dict = body as? [String: Any], let type = dict["type"] as? String else {
            return nil
        }
        let payload = dict["payload"] as? [String: Any] ?? [:]
        switch type {
        case "openAvatar":
            guard JSONSerialization.isValidJSONObject(payload),
                  let data = try? JSONSerialization.data(withJSONObject: payload),
                  let request = try? JSONDecoder().decode(AvatarRequest.self, from: data) else {
                return nil
            }
            return .openAvatar(request)
        case "openBodyPhotos":
            return .openBodyPhotos
        case "ready":
            return .ready
        case "signOut":
            return .signOut
        case "themeChanged":
            guard let setting = payload["setting"] as? String else { return nil }
            return .themeChanged(setting)
        default:
            return nil
        }
    }
}
