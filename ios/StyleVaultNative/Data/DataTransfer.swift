import Foundation
import StyleVaultCore
import SwiftData

/// Tutti i dati dell'utente in un file: serve per cambiare telefono, per passare ad Android e per la
/// portabilità del GDPR. Il file resta sul dispositivo finché l'utente non decide dove mandarlo.
@MainActor enum DataExporter {
    static func export(from context: ModelContext, to folder: URL = FileManager.default.temporaryDirectory) throws -> URL {
        var bundle = ExportBundle()
        var photos: [String: Data] = [:]

        func file(_ data: Data?, _ name: String) -> String? {
            guard let data else { return nil }
            let path = "photos/\(name).jpg"
            photos[path] = data
            return path
        }

        bundle.items = try context.fetch(FetchDescriptor<Item>()).map { item in
            let id = item.id.uuidString
            return ExportGarment(id: id, name: item.name, category: item.category, subcategory: item.subcategory,
                                 brand: item.brand, size: item.size, colors: item.colors, season: item.season,
                                 occasion: item.occasion, warmthLevel: item.warmthLevel, sourceURL: item.sourceURL,
                                 price: item.price, favorite: item.favorite, createdAt: item.createdAt,
                                 photoFront: file(item.photoFront, "\(id)-front"), photoBack: file(item.photoBack, "\(id)-back"),
                                 cutout: file(item.cutout, "\(id)-cutout"))
        }
        bundle.wishlist = try context.fetch(FetchDescriptor<WishlistItem>()).map { item in
            let id = item.id.uuidString
            return ExportGarment(id: id, name: item.name, category: item.category, subcategory: item.subcategory,
                                 brand: item.brand, size: item.size, colors: item.colors, season: item.season,
                                 occasion: item.occasion, warmthLevel: item.warmthLevel, sourceURL: item.sourceURL,
                                 price: item.price, favorite: nil, createdAt: item.createdAt,
                                 photoFront: file(item.photoFront, "\(id)-front"), photoBack: file(item.photoBack, "\(id)-back"),
                                 cutout: nil)
        }
        bundle.customCategories = try context.fetch(FetchDescriptor<CustomCategory>()).map {
            ExportCategory(id: $0.id, name: $0.name, createdAt: $0.createdAt)
        }
        bundle.outfits = try context.fetch(FetchDescriptor<Outfit>()).map {
            ExportOutfit(id: $0.id.uuidString, occasion: $0.occasion, score: $0.score,
                         itemIDs: $0.itemIDs.map(\.uuidString), createdAt: $0.createdAt)
        }
        bundle.calendar = try context.fetch(FetchDescriptor<CalendarEntry>()).map {
            ExportCalendarEntry(id: $0.id.uuidString, day: $0.day, worn: $0.worn, outfitID: $0.outfitID?.uuidString,
                                itemIDs: $0.itemIDs.map(\.uuidString), createdAt: $0.createdAt)
        }
        bundle.bodyPhotos = try context.fetch(FetchDescriptor<BodyPhoto>()).compactMap { photo in
            file(photo.photo, "body-\(photo.kind)").map { ExportBodyPhoto(kind: photo.kind, file: $0) }
        }
        let profile = try ProfileStore.current(in: context)
        bundle.profile = ExportProfile(theme: profile.theme, cityName: profile.cityName, cityLatitude: profile.cityLatitude,
                                       cityLongitude: profile.cityLongitude, cityCountry: profile.cityCountry,
                                       armocromia: profile.armocromia.map { String(decoding: $0, as: UTF8.self) })

        let url = folder.appendingPathComponent(ExportArchive.fileName())
        try? FileManager.default.removeItem(at: url)
        try ExportArchive.write(bundle, photos: photos, to: url)
        return url
    }
}

struct ImportSummary: Equatable {
    var items = 0
    var wishlist = 0
    var outfits = 0
    var calendar = 0
    var skipped = 0

    var added: Int { items + wishlist + outfits + calendar }
}

/// Aggiunge ai dati che ci sono già e non cancella nulla: ciò che esiste resta com'è, così importare due
/// volte lo stesso file non crea doppioni.
@MainActor enum DataImporter {
    static func apply(_ contents: ExportArchive.Contents, to context: ModelContext) throws -> ImportSummary {
        let bundle = contents.bundle
        var summary = ImportSummary()
        // Le chiavi di altri sistemi possono non essere UUID: capi e outfit restano collegati fra loro.
        var ids: [String: UUID] = [:]
        func uuid(_ text: String) -> UUID {
            if let known = ids[text] { return known }
            let value = UUID(uuidString: text) ?? UUID()
            ids[text] = value
            return value
        }

        let knownCategories = Set(try context.fetch(FetchDescriptor<CustomCategory>()).map(\.id))
        for category in bundle.customCategories where !knownCategories.contains(category.id) {
            let value = CustomCategory()
            value.id = category.id
            value.name = category.name
            value.createdAt = category.createdAt
            context.insert(value)
        }

        let knownItems = Set(try context.fetch(FetchDescriptor<Item>()).map(\.id))
        for garment in bundle.items {
            let id = uuid(garment.id)
            guard !knownItems.contains(id) else {
                summary.skipped += 1
                continue
            }
            let item = Item()
            item.id = id
            item.name = garment.name
            item.category = garment.category
            item.subcategory = garment.subcategory
            item.brand = garment.brand
            item.size = garment.size
            item.colors = garment.colors
            item.season = garment.season
            item.occasion = garment.occasion
            item.warmthLevel = garment.warmthLevel
            item.sourceURL = garment.sourceURL
            item.price = garment.price
            item.favorite = garment.favorite ?? false
            item.createdAt = garment.createdAt
            item.photoFront = try contents.photo(garment.photoFront)
            item.photoBack = try contents.photo(garment.photoBack)
            item.cutout = try contents.photo(garment.cutout)
            context.insert(item)
            summary.items += 1
        }

        let knownWishes = Set(try context.fetch(FetchDescriptor<WishlistItem>()).map(\.id))
        for garment in bundle.wishlist {
            let id = uuid(garment.id)
            guard !knownWishes.contains(id) else {
                summary.skipped += 1
                continue
            }
            let item = WishlistItem()
            item.id = id
            item.name = garment.name
            item.category = garment.category
            item.subcategory = garment.subcategory
            item.brand = garment.brand
            item.size = garment.size
            item.colors = garment.colors
            item.season = garment.season
            item.occasion = garment.occasion
            item.warmthLevel = garment.warmthLevel
            item.sourceURL = garment.sourceURL
            item.price = garment.price
            item.createdAt = garment.createdAt
            item.photoFront = try contents.photo(garment.photoFront)
            item.photoBack = try contents.photo(garment.photoBack)
            context.insert(item)
            summary.wishlist += 1
        }

        let knownOutfits = Set(try context.fetch(FetchDescriptor<Outfit>()).map(\.id))
        for outfit in bundle.outfits {
            let id = uuid(outfit.id)
            guard !knownOutfits.contains(id) else {
                summary.skipped += 1
                continue
            }
            let value = Outfit()
            value.id = id
            value.occasion = outfit.occasion
            value.score = outfit.score
            value.itemIDs = outfit.itemIDs.map(uuid)
            value.createdAt = outfit.createdAt
            context.insert(value)
            summary.outfits += 1
        }

        let knownEntries = Set(try context.fetch(FetchDescriptor<CalendarEntry>()).map(\.id))
        for entry in bundle.calendar {
            let id = uuid(entry.id)
            guard !knownEntries.contains(id) else {
                summary.skipped += 1
                continue
            }
            let value = CalendarEntry()
            value.id = id
            value.day = entry.day
            value.worn = entry.worn
            value.outfitID = entry.outfitID.map(uuid)
            value.itemIDs = entry.itemIDs.map(uuid)
            value.createdAt = entry.createdAt
            context.insert(value)
            summary.calendar += 1
        }

        let knownPhotos = Set(try context.fetch(FetchDescriptor<BodyPhoto>()).map(\.kind))
        for photo in bundle.bodyPhotos where !knownPhotos.contains(photo.kind) {
            let value = BodyPhoto()
            value.kind = photo.kind
            value.photo = try contents.photo(photo.file)
            context.insert(value)
        }

        if let incoming = bundle.profile {
            let profile = try ProfileStore.current(in: context)
            // Il Profilo di chi importa vince: arriva solo ciò che manca.
            if profile.armocromia == nil { profile.armocromia = incoming.armocromia.map { Data($0.utf8) } }
            if profile.updatedAt == Date(timeIntervalSince1970: 0) {
                profile.theme = incoming.theme
                profile.cityName = incoming.cityName
                profile.cityLatitude = incoming.cityLatitude
                profile.cityLongitude = incoming.cityLongitude
                profile.cityCountry = incoming.cityCountry
                profile.updatedAt = .now
            }
        }
        try context.save()
        return summary
    }
}
