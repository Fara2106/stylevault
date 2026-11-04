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

/// Luogo di cui il sito chiede la previsione (Meteo di Apple).
struct ForecastRequest: Decodable, Equatable {
    let latitude: Double
    let longitude: Double
    let name: String?
}

/// Messaggi dal sito al nativo: { type, payload } sull'handler "svNative".
enum BridgeMessage: Equatable {
    case openAvatar(AvatarRequest)
    /// Rifare le foto del corpo: una vista sola o, con nil, tutte e tre
    case openBodyPhotos(BodyView?)
    case ready
    case signOut
    case themeChanged(String)
    /// Il sito vuole la posizione del telefono (risposta: svNative.setLocation)
    case requestLocation
    /// Il sito vuole la previsione del luogo (risposta: svNative.setForecast, se acceso)
    case requestForecast(ForecastRequest)

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
            return .openBodyPhotos((payload["view"] as? String).flatMap(BodyView.init(rawValue:)))
        case "ready":
            return .ready
        case "signOut":
            return .signOut
        case "requestLocation":
            return .requestLocation
        case "requestForecast":
            guard let latitude = (payload["latitude"] as? NSNumber)?.doubleValue,
                  let longitude = (payload["longitude"] as? NSNumber)?.doubleValue else { return nil }
            return .requestForecast(ForecastRequest(latitude: latitude, longitude: longitude,
                                                    name: payload["name"] as? String))
        case "themeChanged":
            guard let setting = payload["setting"] as? String else { return nil }
            return .themeChanged(setting)
        default:
            return nil
        }
    }
}
