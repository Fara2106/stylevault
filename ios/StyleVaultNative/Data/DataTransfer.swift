import CryptoKit
import Foundation
import StyleVaultCore
import SwiftData

/// Tutti i dati dell'utente in un file: serve per cambiare telefono, per passare ad Android e per la
/// portabilità del GDPR. Il file resta sul dispositivo finché l'utente non decide dove mandarlo.
/// Le copie temporanee contengono foto, anche del corpo: non devono sopravvivere a chi le ha cancellate.
enum TemporaryFiles {
    /// Parte quando le copie con le foto sono state tolte: chi mostra un file esportato smette di offrirlo.
    static let photosForgotten = Notification.Name("it.faraoni.stylevault.nativa.photosForgotten")

    static func sweep(_ folder: URL = FileManager.default.temporaryDirectory) {
        remove(from: folder) { $0.hasPrefix("importa-") || isPhotoCopy($0) }
    }

    /// Dopo aver cancellato o cambiato una foto del corpo: il file esportato prima e le foto preparate per la
    /// prova la contengono ancora. Un'importazione in corso non si tocca.
    static func forgetPhotos(in folder: URL = FileManager.default.temporaryDirectory) {
        remove(from: folder, where: isPhotoCopy)
        NotificationCenter.default.post(name: photosForgotten, object: nil)
    }

    private static func isPhotoCopy(_ name: String) -> Bool {
        name == "prova" || (name.hasPrefix("StyleVault-") && name.hasSuffix(".zip"))
    }

    private static func remove(from folder: URL, where matches: (String) -> Bool) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where matches(name) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}

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
                                itemIDs: $0.itemIDs.map(\.uuidString), createdAt: $0.createdAt,
                                snapshot: $0.wornItems.isEmpty ? nil : $0.wornItems)
        }
        // Solo le viste che l'app conosce: il tipo finisce nel nome del file.
        bundle.bodyPhotos = try context.fetch(FetchDescriptor<BodyPhoto>()).compactMap { photo in
            guard BodyView(rawValue: photo.kind) != nil else { return nil }
            return try file(photo.photo, "body-\(photo.kind)").map { ExportBodyPhoto(kind: photo.kind, file: $0) }
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
    var missingPhotos = 0
    /// Foto arrivate a capi che c'erano già ma erano rimasti senza.
    var recoveredPhotos = 0

    var added: Int { items + wishlist + outfits + calendar }
}

/// Aggiunge ai dati che ci sono già e non cancella nulla: ciò che esiste resta com'è, così importare due
/// volte lo stesso file sullo stesso dispositivo non crea doppioni. Salva a blocchi: se si interrompe,
/// riprovare aggiunge ciò che manca. Su un altro dispositivo con lo stesso iCloud il confronto non vede ciò
/// che non è ancora arrivato: lì i doppioni restano possibili.
@MainActor enum DataImporter {
    struct TooManyRecords: Error {}

    /// Molto più di qualsiasi guardaroba vero: fermano un file costruito per riempire il telefono e iCloud.
    static let recordLimit = 50_000
    static let photoBudget = 4 * 1024 * 1024 * 1024
    /// Il tetto sui record non dice quanto è grande ciascuno: un outfit vero ha pochi capi, un giorno poche
    /// voci, un nome poche parole. Il resto si taglia, così le schede non devono mai contare milioni di voci.
    static let piecesLimit = 24
    static let entriesPerDayLimit = 20
    static let textLimit = 500
    static let linkLimit = 2048
    static let colorsLimit = 24

    static func clipped(_ text: String, to limit: Int = textLimit) -> String {
        text.count > limit ? String(text.prefix(limit)) : text
    }

    static func clipped(_ text: String?, to limit: Int = textLimit) -> String? {
        text.map { clipped($0, to: limit) }
    }

    /// I capi di un outfit o di un giorno: i primi, senza ripetizioni.
    static func pieces(_ keys: [String]) -> [UUID] {
        var seen = Set<UUID>()
        return keys.prefix(piecesLimit).map(stableID).filter { seen.insert($0).inserted }
    }

    static func apply(_ contents: ExportArchive.Contents, to context: ModelContext) async throws -> ImportSummary {
        do {
            return try await add(contents, to: context)
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Le chiavi di altri sistemi possono non essere UUID: la stessa chiave dà sempre lo stesso id, così
    /// capi e outfit restano collegati e un secondo import riconosce ciò che c'è già.
    static func stableID(_ text: String) -> UUID {
        if let id = UUID(uuidString: text) { return id }
        var bytes = Array(SHA256.hash(data: Data(text.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return bytes.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
    }

    private static func add(_ contents: ExportArchive.Contents, to context: ModelContext) async throws -> ImportSummary {
        let bundle = contents.bundle
        var summary = ImportSummary()
        func uuid(_ text: String) -> UUID { stableID(text) }
        guard bundle.items.count + bundle.wishlist.count + bundle.outfits.count + bundle.calendar.count
            + bundle.customCategories.count <= recordLimit else { throw TooManyRecords() }
        var stored = 0
        // In un file vero ogni foto appartiene a un record solo: la stessa voce citata due volte non si salva
        // due volte, altrimenti un file piccolo riempirebbe il telefono.
        var usedPhotos = Set<String>()
        // Una foto mancante, rovinata o che non è una foto non ferma tutto il resto: si conta e si dice.
        // Il file può venire da chiunque: entra solo ciò che `GarmentImage.imported` riconosce come foto.
        func photo(_ name: String?) -> Data? {
            guard let name else { return nil }
            // Finito lo spazio concesso non si apre più nulla: nemmeno il lavoro di leggere e decodificare.
            guard stored < photoBudget, usedPhotos.insert(name).inserted,
                  let raw = try? contents.photo(name), let data = GarmentImage.imported(raw),
                  stored + data.count <= photoBudget else {
                summary.missingPhotos += 1
                return nil
            }
            stored += data.count
            return data
        }
        // Lo scontorno che non convince si lascia perdere senza dirlo: l'app lo rifà.
        func cutout(_ name: String?) -> Data? {
            guard let name, stored < photoBudget, usedPhotos.insert(name).inserted,
                  let raw = try? contents.photo(name), let data = GarmentImage.importedCutout(raw),
                  stored + data.count <= photoBudget else { return nil }
            stored += data.count
            return data
        }
        func warmth(_ level: Int) -> Int { min(5, max(1, level)) }

        var knownCategories = Set(try context.fetch(FetchDescriptor<CustomCategory>()).map(\.id))
        for category in bundle.customCategories where knownCategories.insert(category.id).inserted {
            let value = CustomCategory()
            value.id = category.id
            value.name = clipped(category.name)
            value.createdAt = category.createdAt
            context.insert(value)
        }
        try context.save()

        // Gli id già visti si aggiornano strada facendo: lo stesso id ripetuto nel file non crea due record.
        var knownItems = Set(try context.fetch(FetchDescriptor<Item>()).map(\.id))
        for chunk in TransferBatch.split(bundle.items) {
            try autoreleasepool {
                let batch = ModelContext(context.container)
                for garment in chunk {
                    let id = uuid(garment.id)
                    guard knownItems.insert(id).inserted else {
                        summary.skipped += 1
                        // Se la prima volta una foto è mancata, ripetere l'import la recupera. Solo per un capo
                        // rimasto senza foto: chi ne ha già una resta com'è, come promette la conferma.
                        if let existing = try batch.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })).first,
                           existing.photoFront == nil, let front = photo(garment.photoFront) {
                            existing.photoFront = front
                            existing.photoBack = existing.photoBack ?? photo(garment.photoBack)
                            summary.recoveredPhotos += 1
                        }
                        continue
                    }
                    let item = Item()
                    item.id = id
                    item.name = clipped(garment.name)
                    item.category = clipped(garment.category)
                    item.subcategory = clipped(garment.subcategory)
                    item.brand = clipped(garment.brand)
                    item.size = clipped(garment.size)
                    item.colors = garment.colors.prefix(colorsLimit).map { clipped($0) }
                    item.season = clipped(garment.season)
                    item.occasion = clipped(garment.occasion)
                    item.warmthLevel = warmth(garment.warmthLevel)
                    item.sourceURL = clipped(garment.sourceURL, to: linkLimit)
                    item.price = garment.price
                    item.favorite = garment.favorite ?? false
                    item.createdAt = garment.createdAt
                    item.photoFront = photo(garment.photoFront)
                    item.photoBack = photo(garment.photoBack)
                    item.cutout = cutout(garment.cutout)
                    batch.insert(item)
                    summary.items += 1
                }
                try batch.save()
            }
            await Task.yield()
        }

        var knownWishes = Set(try context.fetch(FetchDescriptor<WishlistItem>()).map(\.id))
        for chunk in TransferBatch.split(bundle.wishlist) {
            try autoreleasepool {
                let batch = ModelContext(context.container)
                for garment in chunk {
                    let id = uuid(garment.id)
                    guard knownWishes.insert(id).inserted else {
                        summary.skipped += 1
                        if let existing = try batch.fetch(FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.id == id })).first,
                           existing.photoFront == nil, let front = photo(garment.photoFront) {
                            existing.photoFront = front
                            existing.photoBack = existing.photoBack ?? photo(garment.photoBack)
                            summary.recoveredPhotos += 1
                        }
                        continue
                    }
                    let item = WishlistItem()
                    item.id = id
                    item.name = clipped(garment.name)
                    item.category = clipped(garment.category)
                    item.subcategory = clipped(garment.subcategory)
                    item.brand = clipped(garment.brand)
                    item.size = clipped(garment.size)
                    item.colors = garment.colors.prefix(colorsLimit).map { clipped($0) }
                    item.season = clipped(garment.season)
                    item.occasion = clipped(garment.occasion)
                    item.warmthLevel = warmth(garment.warmthLevel)
                    item.sourceURL = clipped(garment.sourceURL, to: linkLimit)
                    item.price = garment.price
                    item.createdAt = garment.createdAt
                    item.photoFront = photo(garment.photoFront)
                    item.photoBack = photo(garment.photoBack)
                    batch.insert(item)
                    summary.wishlist += 1
                }
                try batch.save()
            }
            await Task.yield()
        }

        var knownOutfits = Set(try context.fetch(FetchDescriptor<Outfit>()).map(\.id))
        for outfit in bundle.outfits {
            let id = uuid(outfit.id)
            guard knownOutfits.insert(id).inserted else {
                summary.skipped += 1
                continue
            }
            let value = Outfit()
            value.id = id
            value.occasion = clipped(outfit.occasion)
            value.score = outfit.score
            value.itemIDs = pieces(outfit.itemIDs)
            value.createdAt = outfit.createdAt
            context.insert(value)
            summary.outfits += 1
        }

        let entries = try context.fetch(FetchDescriptor<CalendarEntry>())
        var knownEntries = Set(entries.map(\.id))
        var entriesPerDay = Dictionary(entries.map { ($0.day, 1) }, uniquingKeysWith: +)
        for entry in bundle.calendar {
            let id = uuid(entry.id)
            // Un giorno con più voci di quante se ne possano scrivere a mano non viene da un calendario vero.
            guard CalendarMath.isValid(entry.day), entriesPerDay[entry.day, default: 0] < entriesPerDayLimit,
                  knownEntries.insert(id).inserted else {
                summary.skipped += 1
                continue
            }
            entriesPerDay[entry.day, default: 0] += 1
            let value = CalendarEntry()
            value.id = id
            value.day = entry.day
            value.worn = entry.worn
            value.outfitID = entry.outfitID.map(uuid)
            value.itemIDs = pieces(entry.itemIDs)
            value.createdAt = entry.createdAt
            value.snapshot = entry.snapshot.flatMap { worn in
                try? JSONEncoder().encode(worn.prefix(piecesLimit).map {
                    WornItem(id: clipped($0.id), name: clipped($0.name), category: clipped($0.category))
                })
            }
            context.insert(value)
            summary.calendar += 1
        }

        // Una foto per vista, e solo le viste che l'app conosce: le altre resterebbero nascoste e incancellabili.
        var knownPhotos = Set(try context.fetch(FetchDescriptor<BodyPhoto>()).map(\.kind))
        for file in bundle.bodyPhotos where BodyView(rawValue: file.kind) != nil && !knownPhotos.contains(file.kind) {
            guard let bodyPhoto = photo(file.file) else { continue }
            knownPhotos.insert(file.kind)
            let value = BodyPhoto()
            value.kind = file.kind
            value.photo = bodyPhoto
            context.insert(value)
        }

        if let incoming = bundle.profile {
            let profile = try ProfileStore.current(in: context)
            // Il Profilo di chi importa vince: arriva solo ciò che manca.
            if profile.armocromia == nil, let text = incoming.armocromia {
                // Si salva il verdetto riscritto dall'app, non il testo ricevuto: ciò che non conosce si perde.
                if let verdict = ArmocromiaVerdict.decode(Data(text.utf8)), ArmocromiaSeasons.season(id: verdict.season) != nil {
                    profile.armocromia = try? verdict.encoded()
                }
            }
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
