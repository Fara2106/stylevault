import Foundation
import StyleVaultCore
import SwiftData

/// Una foto per vista. Da iCloud possono arrivare doppioni: si mostra la più recente, al salvataggio restano una sola.
@MainActor enum BodyPhotoStore {
    private static func all(_ view: BodyView, in context: ModelContext) throws -> [BodyPhoto] {
        let kind = view.rawValue
        return try context.fetch(FetchDescriptor<BodyPhoto>(predicate: #Predicate { $0.kind == kind }))
    }

    static func save(_ jpeg: Data, view: BodyView, in context: ModelContext) throws {
        var existing = try all(view, in: context)
        let photo = existing.popLast() ?? BodyPhoto()
        if photo.modelContext == nil { context.insert(photo) }
        existing.forEach(context.delete)
        photo.kind = view.rawValue
        photo.photo = jpeg
        photo.updatedAt = .now
        try context.save()
    }

    static func delete(_ view: BodyView, in context: ModelContext) throws {
        try all(view, in: context).forEach(context.delete)
        try context.save()
    }

    static func byView(_ photos: [BodyPhoto]) -> [BodyView: BodyPhoto] {
        var found: [BodyView: BodyPhoto] = [:]
        for photo in photos {
            guard let view = BodyView(rawValue: photo.kind) else { continue }
            if let current = found[view], current.updatedAt >= photo.updatedAt { continue }
            found[view] = photo
        }
        return found
    }

    /// Per la cache degli scontorni: cambia quando cambia la foto.
    static func key(of photo: BodyPhoto) -> String {
        "body-\(photo.kind)-\(photo.id.uuidString)-\(Int(photo.updatedAt.timeIntervalSince1970))"
    }
}

/// Cosa serve per comporre una vista dell'avatar.
struct AvatarRequest {
    let garments: [AvatarGarment]
    let withoutPhoto: Int

    @MainActor static func make(_ selection: TryOnSelection, view: BodyView) -> AvatarRequest {
        var garments: [AvatarGarment] = []
        var withoutPhoto = 0
        for (slot, item) in selection.pieces {
            guard let photo = view == .back ? item.photoBack ?? item.photoFront : item.photoFront else {
                withoutPhoto += 1
                continue
            }
            // La chiave nomina la foto, non la vista: di lato e di spalle senza retro è sempre quella davanti.
            let side = view == .back && item.photoBack != nil ? "back" : "front"
            garments.append(AvatarGarment(slot: slot, photo: photo, key: "item-\(item.id.uuidString)-\(side)-\(photo.count)"))
        }
        return AvatarRequest(garments: garments, withoutPhoto: withoutPhoto)
    }
}
