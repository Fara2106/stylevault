import Foundation
import StyleVaultCore
import SwiftData

/// Tutti i dati dell'utente in un file: serve per cambiare telefono, per passare ad Android e per la
/// portabilità del GDPR. Il file resta sul dispositivo finché l'utente non decide dove mandarlo.
/// Le foto si spostano a blocchi, ognuno col suo contesto: così la memoria si libera fra un blocco e l'altro
/// e l'interfaccia respira. Con un contesto solo resterebbero tutte in memoria fino alla fine.
enum TransferBatch {
    static let size = 20

    static func split<Element>(_ values: [Element]) -> [[Element]] {
        stride(from: 0, to: values.count, by: size).map { Array(values[$0..<min($0 + size, values.count)]) }
    }
}

@MainActor enum DataExporter {
    static func export(from context: ModelContext, to folder: URL = FileManager.default.temporaryDirectory) async throws -> URL {
        try context.save()
        let url = folder.appendingPathComponent(ExportArchive.fileName())
        try? FileManager.default.removeItem(at: url)
        let writer = try ZipWriter(url: url)
        var bundle = ExportBundle()

        // Ogni foto finisce subito nel file: tenerle tutte in memoria chiude l'app con guardaroba grandi.
        func file(_ data: Data?, _ name: String) throws -> String? {
            guard let data else { return nil }
            let path = "photos/\(name).jpg"
            try writer.add(name: path, data: data)
            return path
        }

        for ids in TransferBatch.split(try context.fetchIdentifiers(FetchDescriptor<Item>())) {
            try autoreleasepool {
                let batch = ModelContext(context.container)
                for modelID in ids {
                    guard let item = batch.model(for: modelID) as? Item else { continue }
                    let id = item.id.uuidString
                    bundle.items.append(ExportGarment(
                        id: id, name: item.name, category: item.category, subcategory: item.subcategory,
                        brand: item.brand, size: item.size, colors: item.colors, season: item.season,
                        occasion: item.occasion, warmthLevel: item.warmthLevel, sourceURL: item.sourceURL,
                        price: item.price, favorite: item.favorite, createdAt: item.createdAt,
                        photoFront: try file(item.photoFront, "\(id)-front"), photoBack: try file(item.photoBack, "\(id)-back"),
                        cutout: try file(item.cutout, "\(id)-cutout")))
                }
            }
            await Task.yield()
        }
        for ids in TransferBatch.split(try context.fetchIdentifiers(FetchDescriptor<WishlistItem>())) {
            try autoreleasepool {
                let batch = ModelContext(context.container)
                for modelID in ids {
                    guard let item = batch.model(for: modelID) as? WishlistItem else { continue }
                    let id = item.id.uuidString
                    bundle.wishlist.append(ExportGarment(
                        id: id, name: item.name, category: item.category, subcategory: item.subcategory,
                        brand: item.brand, size: item.size, colors: item.colors, season: item.season,
                        occasion: item.occasion, warmthLevel: item.warmthLevel, sourceURL: item.sourceURL,
                        price: item.price, favorite: nil, createdAt: item.createdAt,
                        photoFront: try file(item.photoFront, "\(id)-front"), photoBack: try file(item.photoBack, "\(id)-back"),
                        cutout: nil))
                }
            }
            await Task.yield()
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
            try file(photo.photo, "body-\(photo.kind)").map { ExportBodyPhoto(kind: photo.kind, file: $0) }
        }
        let profile = try ProfileStore.current(in: context)
        bundle.profile = ExportProfile(theme: profile.theme, cityName: profile.cityName, cityLatitude: profile.cityLatitude,
                                       cityLongitude: profile.cityLongitude, cityCountry: profile.cityCountry,
                                       armocromia: profile.armocromia.map { String(decoding: $0, as: UTF8.self) })

        try writer.add(name: ExportArchive.documentName, data: bundle.encoded())
        try writer.close()
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
/// volte lo stesso file sullo stesso dispositivo non crea doppioni. Salva a blocchi: se si interrompe,
/// riprovare aggiunge ciò che manca. Su un altro dispositivo con lo stesso iCloud il confronto non vede ciò
/// che non è ancora arrivato: lì i doppioni restano possibili.
@MainActor enum DataImporter {
    static func apply(_ contents: ExportArchive.Contents, to context: ModelContext) async throws -> ImportSummary {
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
        try context.save()

        let knownItems = Set(try context.fetch(FetchDescriptor<Item>()).map(\.id))
        for chunk in TransferBatch.split(bundle.items) {
            try autoreleasepool {
                let batch = ModelContext(context.container)
                for garment in chunk {
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
                    batch.insert(item)
                    summary.items += 1
                }
                try batch.save()
            }
            await Task.yield()
        }

        let knownWishes = Set(try context.fetch(FetchDescriptor<WishlistItem>()).map(\.id))
        for chunk in TransferBatch.split(bundle.wishlist) {
            try autoreleasepool {
                let batch = ModelContext(context.container)
                for garment in chunk {
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
                    batch.insert(item)
                    summary.wishlist += 1
                }
                try batch.save()
            }
            await Task.yield()
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
