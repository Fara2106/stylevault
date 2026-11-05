import Foundation
import Observation
import StyleVaultCore

enum ItemFormMode {
    case add(AddDestination)
    case edit(Item)
}

enum FormField: Hashable { case name, category, price }

enum LinkState: Equatable { case idle, loading, success, failure }

/// Lo stato del modulo di aggiunta e modifica, come src/pages/AddItemPage/AddItemPage.jsx.
@MainActor @Observable final class ItemFormModel {
    var name = ""
    private(set) var category = ""
    var subcategory: String?
    var brand = ""
    var size = ""
    private(set) var colors: [String] = []
    var season = "all"
    var occasion = "casual"
    var warmthLevel = 2
    var priceText = ""
    var linkText = ""
    var destination: AddDestination = .wardrobe
    var showsLink = false

    private(set) var photoFront: Data?
    private(set) var photoBack: Data?
    private(set) var photoFailed = false
    private(set) var errors: Set<FormField> = []
    private(set) var linkState = LinkState.idle

    let isEditing: Bool

    @ObservationIgnored private let prepare: @Sendable (Data) async -> Data?
    @ObservationIgnored private var frontRun = 0
    @ObservationIgnored private var backRun = 0
    @ObservationIgnored private var linkRun = 0
    private var isFrontBusy = false
    private var isBackBusy = false
    @ObservationIgnored private var initial: Snapshot?

    var isProcessingPhoto: Bool { isFrontBusy || isBackBusy }
    var canSave: Bool { !isProcessingPhoto }
    var isDirty: Bool { snapshot != initial }
    /// Il primo errore dall'alto: Salva sta in fondo al modulo e la persona va portata lì.
    var firstError: FormField? { [FormField.name, .category, .price].first(where: errors.contains) }

    init(mode: ItemFormMode,
         prepare: @escaping @Sendable (Data) async -> Data? = { data in
             await Task.detached(priority: .userInitiated) { GarmentImage.prepared(data) }.value
         }) {
        self.prepare = prepare
        switch mode {
        case .add(let destination):
            isEditing = false
            self.destination = destination
        case .edit(let item):
            isEditing = true
            load(item.values)
        }
        initial = snapshot
    }

    func selectCategory(_ id: String) {
        category = id
        subcategory = nil
    }

    func toggleColor(_ id: String) {
        if let index = colors.firstIndex(of: id) {
            colors.remove(at: index)
        } else {
            colors.append(id)
        }
    }

    func setFront(_ raw: Data) async {
        await setFront(loading: { raw })
    }

    func setBack(_ raw: Data) async {
        await setBack(loading: { raw })
    }

    /// `load` può durare secondi: la foto può dover scendere da iCloud. Salva resta fermo anche lì.
    func setFront(loading load: @escaping @Sendable () async -> Data?) async {
        frontRun += 1
        let run = frontRun
        isFrontBusy = true
        let result = await process(load)
        guard run == frontRun else { return }   // Nel frattempo ne è stata scelta un'altra.
        isFrontBusy = false
        apply(result) { photoFront = $0 }
    }

    func setBack(loading load: @escaping @Sendable () async -> Data?) async {
        backRun += 1
        let run = backRun
        isBackBusy = true
        let result = await process(load)
        guard run == backRun else { return }
        isBackBusy = false
        apply(result) { photoBack = $0 }
    }

    func removeBack() {
        backRun += 1
        isBackBusy = false
        photoBack = nil
    }

    /// Riempie solo ciò che è ancora vuoto. Il link resta nel campo anche se la lettura non riesce.
    func analyzeLink(with reader: any LinkReading) async {
        guard let url = LinkText.httpURL(from: linkText) else { return }
        linkRun += 1
        let run = linkRun
        let requested = linkText
        linkState = .loading
        do {
            let preview = try await reader.read(url)
            guard run == linkRun else { return }
            guard linkText == requested else {
                linkState = .idle
                return
            }
            if trimmed(name).isEmpty { name = preview.title }
            if trimmed(brand).isEmpty { brand = preview.site }
            if photoFront == nil, let image = preview.imageData { await setFront(image) }
            linkState = .success
        } catch {
            guard run == linkRun else { return }
            linkState = linkText == requested ? .failure : .idle
        }
    }

    /// I valori da salvare, oppure `nil` con `errors` aggiornato.
    func validatedValues() -> ItemValues? {
        var found: Set<FormField> = []
        let cleanName = trimmed(name)
        if cleanName.isEmpty { found.insert(.name) }
        if category.isEmpty { found.insert(.category) }
        var price: Double?
        switch ItemText.parsePrice(priceText) {
        case .empty: break
        case .value(let value): price = value
        case .invalid: found.insert(.price)
        }
        errors = found
        guard found.isEmpty else { return nil }
        return ItemValues(name: cleanName, category: category, subcategory: subcategory,
                          brand: optional(brand), size: optional(size), colors: colors,
                          season: season, occasion: occasion, warmthLevel: warmthLevel,
                          sourceURL: LinkText.httpURL(from: linkText)?.absoluteString, price: price,
                          photoFront: photoFront, photoBack: photoBack)
    }

    private func process(_ load: @Sendable () async -> Data?) async -> Data? {
        guard let raw = await load() else { return nil }
        return await prepare(raw)
    }

    private func apply(_ result: Data?, to set: (Data) -> Void) {
        photoFailed = result == nil
        if let result { set(result) }
    }

    private func load(_ values: ItemValues) {
        name = values.name
        category = values.category
        subcategory = values.subcategory
        brand = values.brand ?? ""
        size = values.size ?? ""
        colors = values.colors
        season = values.season
        occasion = values.occasion
        warmthLevel = values.warmthLevel
        priceText = values.price.map { $0.formatted(.number.grouping(.never)) } ?? ""
        linkText = values.sourceURL ?? ""
        showsLink = values.sourceURL != nil
        photoFront = values.photoFront
        photoBack = values.photoBack
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func optional(_ text: String) -> String? {
        let clean = trimmed(text)
        return clean.isEmpty ? nil : clean
    }

    private var snapshot: Snapshot {
        Snapshot(name: name, category: category, subcategory: subcategory, brand: brand, size: size, colors: colors,
                 season: season, occasion: occasion, warmthLevel: warmthLevel, priceText: priceText, linkText: linkText,
                 destination: destination, photoFront: photoFront, photoBack: photoBack)
    }

    private struct Snapshot: Equatable {
        let name, category: String
        let subcategory: String?
        let brand, size: String
        let colors: [String]
        let season, occasion: String
        let warmthLevel: Int
        let priceText, linkText: String
        let destination: AddDestination
        let photoFront, photoBack: Data?
    }
}
