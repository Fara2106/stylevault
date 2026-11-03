import Foundation

/// Capo da mostrare sull'avatar, come lo manda il sito (nativeBridge.js).
struct AvatarItem: Decodable, Equatable {
    let id: String
    let category: String
    let slot: String
    let photo: String
    let name: String
    let photoBack: String?
}

struct AvatarRequest: Decodable, Equatable {
    let items: [AvatarItem]
}

/// Messaggi dal sito al nativo: { type, payload } sull'handler "svNative".
enum BridgeMessage: Equatable {
    case openAvatar(AvatarRequest)
    case openBodyPhotos
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
