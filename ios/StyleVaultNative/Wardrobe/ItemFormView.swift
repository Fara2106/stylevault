import OSLog
import PhotosUI
import StyleVaultCore
import SwiftData
import SwiftUI

private enum PhotoSide: Identifiable {
    case front, back
    var id: Self { self }
}

/// Il modulo di aggiunta e modifica di un capo, nell'ordine di AddItemPage.jsx.
struct ItemFormView: View {
    private let mode: ItemFormMode
    @State private var model: ItemFormModel

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CutoutWorker.self) private var cutoutWorker
    @Environment(\.linkReader) private var linkReader
    @Query private var customCategories: [CustomCategory]

    @State private var libraryPick: PhotosPickerItem?
    @State private var isLibraryPresented = false
    @State private var librarySide = PhotoSide.front
    @State private var cameraSide: PhotoSide?
    @State private var isDiscardAsked = false
    @State private var isNewCategoryAsked = false
    @State private var newCategoryName = ""

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "wardrobe")

    @MainActor init(mode: ItemFormMode) {
        self.mode = mode
        _model = State(initialValue: ItemFormModel(mode: mode))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sourcePicker
                    if model.showsLink { linkSource } else { photoSource }
                    backPhoto
                    details
                    saveButton
                }
                .padding(16)
                // Su iPad il modulo resta centrato e non si allarga su tutto lo schermo.
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { Palette.bg.ignoresSafeArea().accessibilityIdentifier("add-sheet") }
            .navigationTitle(Text(LocalizedStringKey(model.isEditing ? "common.edit" : "addItem.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close", action: close).accessibilityIdentifier("item-close")
                }
            }
        }
        // Un trascinamento non perde la bozza: resta aperto, e Chiudi chiede.
        .interactiveDismissDisabled(model.isDirty)
        .alert("native.form.discard.title", isPresented: $isDiscardAsked) {
            Button("native.form.discard.keep", role: .cancel) {}
            Button("native.form.discard.confirm", role: .destructive) { dismiss() }
        }
        .alert("native.category.new", isPresented: $isNewCategoryAsked) {
            TextField("native.category.name", text: $newCategoryName)
            Button("common.cancel", role: .cancel) {}
            Button("common.save", action: createCategory)
        }
        .photosPicker(isPresented: $isLibraryPresented, selection: $libraryPick, matching: .images)
        .onChange(of: libraryPick) { _, pick in
            guard let pick else { return }
            libraryPick = nil
            loadFromLibrary(pick, side: librarySide)
        }
        .fullScreenCover(item: $cameraSide) { side in
            CameraPicker { data in
                Task {
                    if side == .front { await model.setFront(data) } else { await model.setBack(data) }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func loadFromLibrary(_ pick: PhotosPickerItem, side: PhotoSide) {
        let load: @Sendable () async -> Data? = { try? await pick.loadTransferable(type: Data.self) }
        Task {
            if side == .front {
                await model.setFront(loading: load)
            } else {
                await model.setBack(loading: load)
            }
        }
    }

    // MARK: Sorgente

    private var sourcePicker: some View {
        HStack(spacing: 8) {
            sourceButton("addItem.photo", icon: "camera", isSelected: !model.showsLink, id: "mode-photo") {
                model.showsLink = false
            }
            sourceButton("addItem.link", icon: "link", isSelected: model.showsLink, id: "mode-link") {
                model.showsLink = true
            }
        }
    }

    private func sourceButton(_ key: LocalizedStringKey, icon: String, isSelected: Bool, id: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(key, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(isSelected ? Palette.bg : Palette.ink)
                .background(isSelected ? Palette.ink : Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private var photoSource: some View {
        VStack(spacing: 12) {
            if let photo = model.photoFront {
                ItemPhotoView(data: photo, name: model.name, maxSide: 800, contentMode: .fit)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                photoMenu(.front) { Text("addItem.changePhoto").foregroundStyle(Palette.accent) }
            } else {
                photoMenu(.front) {
                    VStack(spacing: 6) {
                        Image(systemName: "camera").font(.title)
                        Text("addItem.uploadPhoto").font(.headline)
                        Text("addItem.photoHint").font(.footnote).foregroundStyle(Palette.muted)
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [6])))
                }
            }
            photoStatus
        }
    }

    @ViewBuilder private var photoStatus: some View {
        if model.isProcessingPhoto {
            ProgressView()
        } else if model.photoFailed {
            Text("native.form.photoError").font(.footnote).foregroundStyle(Palette.danger)
        }
    }

    private var linkSource: some View {
        VStack(spacing: 12) {
            TextField("addItem.pasteLink", text: $model.linkText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("item-link")
            Button("addItem.analyzeLink") {
                Task { await model.analyzeLink(with: linkReader) }
            }
            .buttonStyle(.bordered)
            .tint(Palette.ink)
            .disabled(LinkText.httpURL(from: model.linkText) == nil || model.linkState == .loading)
            .accessibilityIdentifier("link-analyze")
            linkStatus
            if let photo = model.photoFront {
                ItemPhotoView(data: photo, name: model.name, maxSide: 800, contentMode: .fit)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            // Con un link illeggibile la foto si mette a mano.
            photoMenu(.front) {
                Text(LocalizedStringKey(model.photoFront == nil ? "addItem.uploadPhoto" : "addItem.changePhoto"))
                    .foregroundStyle(Palette.accent)
            }
            photoStatus
        }
    }

    @ViewBuilder private var linkStatus: some View {
        switch model.linkState {
        case .idle:
            EmptyView()
        case .loading:
            Text("addItem.linkLoading").font(.footnote).foregroundStyle(Palette.muted)
        case .success:
            Text("addItem.linkSuccess").font(.footnote).foregroundStyle(Palette.ink)
        case .failure:
            Text("addItem.linkError").font(.footnote).foregroundStyle(Palette.danger)
        }
    }

    private func photoMenu<Label: View>(_ side: PhotoSide, @ViewBuilder label: () -> Label) -> some View {
        Menu {
            Button {
                librarySide = side
                isLibraryPresented = true
            } label: {
                SwiftUI.Label("addItem.uploadPhoto", systemImage: "photo.on.rectangle")
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { cameraSide = side } label: {
                    SwiftUI.Label("addItem.takePhoto", systemImage: "camera")
                }
            }
        } label: {
            label()
        }
    }

    private var backPhoto: some View {
        HStack(spacing: 12) {
            if let back = model.photoBack {
                ItemPhotoView(data: back, name: model.name)
                    .frame(width: 44, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 2) {
                fieldLabel("addItem.photoBack")
                Text("addItem.photoBackHint").font(.footnote).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            photoMenu(.back) {
                Text(LocalizedStringKey(model.photoBack == nil ? "addItem.photoBackAdd" : "addItem.changePhoto"))
                    .foregroundStyle(Palette.accent)
            }
            if model.photoBack != nil {
                Button { model.removeBack() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel(Text("addItem.photoBackRemove"))
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    // MARK: Dati

    private var details: some View {
        VStack(alignment: .leading, spacing: 24) {
            nameField
            categoryPicker
            subcategoryPicker
            colorPicker
            choiceGroup("addItem.season", options: Catalog.seasons, selection: $model.season)
            choiceGroup("addItem.occasion", options: Catalog.occasions, selection: $model.occasion)
            warmthPicker
            brandAndSize
            priceField
            if !model.isEditing { destinationPicker }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("addItem.itemName")
            TextField("", text: $model.name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("item-name")
            if model.errors.contains(.name) { errorText("addItem.nameRequired") }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("addItem.category")
            if model.errors.contains(.category) { errorText("addItem.categoryRequired") }
            FlowLayout {
                ForEach(CategoryChoice.all(custom: customCategories)) { choice in
                    Chip(text: choice.text, isSelected: model.category == choice.id) {
                        model.selectCategory(choice.id)
                    }
                    .accessibilityIdentifier("category-\(choice.id)")
                }
                Chip(text: Text("native.category.new"), isSelected: false) {
                    newCategoryName = ""
                    isNewCategoryAsked = true
                }
                .accessibilityIdentifier("category-new")
            }
        }
    }

    private func createCategory() {
        do {
            if let category = try CustomCategoryStore.add(name: newCategoryName, in: context) {
                model.selectCategory(category.id)
            }
        } catch {
            logger.error("Categoria non salvata: \(error)")
        }
    }

    @ViewBuilder private var subcategoryPicker: some View {
        if let subcategories = Catalog.category(id: model.category)?.subcategories {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("addItem.subcategory")
                FlowLayout {
                    ForEach(subcategories, id: \.id) { sub in
                        Chip(text: Text(LocalizedStringKey(sub.labelKey)), isSelected: model.subcategory == sub.id) {
                            model.subcategory = sub.id
                        }
                    }
                }
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("addItem.colors")
            FlowLayout(spacing: 10) {
                ForEach(Catalog.colors) { color in
                    let isSelected = model.colors.contains(color.id)
                    Button { model.toggleColor(color.id) } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Palette.border))
                            .overlay(Circle().inset(by: -3).stroke(isSelected ? Palette.ink : .clear, lineWidth: 2))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey(color.labelKey)))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func choiceGroup(_ key: LocalizedStringKey, options: [ChoiceOption], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(key)
            FlowLayout {
                ForEach(options) { option in
                    Chip(text: Text(LocalizedStringKey(option.labelKey)), isSelected: selection.wrappedValue == option.id) {
                        selection.wrappedValue = option.id
                    }
                }
            }
        }
    }

    private var warmthPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                fieldLabel("addItem.warmth")
                Text.warmth(model.warmthLevel)
                    .font(.caption)
                    .foregroundStyle(Palette.ink)
            }
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { level in
                    Button { model.warmthLevel = level } label: {
                        Circle()
                            .fill(model.warmthLevel >= level ? Palette.accent : Palette.surface)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Palette.border))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text.warmth(level))
                    .accessibilityAddTraits(model.warmthLevel == level ? .isSelected : [])
                }
            }
        }
    }

    private var brandAndSize: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("addItem.brand")
                TextField("", text: $model.brand).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("addItem.size")
                TextField("", text: $model.size).textFieldStyle(.roundedBorder)
            }
        }
    }

    private var priceField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("addItem.price")
            TextField("common.optional", text: $model.priceText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("item-price")
            if model.errors.contains(.price) { errorText("native.form.priceInvalid") }
        }
    }

    private var destinationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("addItem.destination")
            HStack(spacing: 8) {
                Chip(text: Text("addItem.toWardrobe"), isSelected: model.destination == .wardrobe) {
                    model.destination = .wardrobe
                }
                .accessibilityIdentifier("destination-wardrobe")
                Chip(text: Text("addItem.toWishlist"), isSelected: model.destination == .wishlist) {
                    model.destination = .wishlist
                }
                .accessibilityIdentifier("destination-wishlist")
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("common.save")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Palette.bg)
                .background(model.canSave ? Palette.ink : Palette.muted, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(!model.canSave)
        .accessibilityIdentifier("item-save")
    }

    private func fieldLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(Palette.muted)
    }

    private func errorText(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.footnote).foregroundStyle(Palette.danger)
    }

    // MARK: Azioni

    private func close() {
        if model.isDirty {
            isDiscardAsked = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard let values = model.validatedValues() else { return }
        do {
            switch mode {
            case .edit(let item):
                let photoChanged = try WardrobeStore.update(item, with: values, in: context)
                if photoChanged, values.photoFront != nil { cutoutWorker.enqueue(item.id) }
            case .add:
                if model.destination == .wishlist {
                    try WardrobeStore.addWish(values, in: context)
                } else {
                    let item = try WardrobeStore.addItem(values, in: context)
                    if values.photoFront != nil { cutoutWorker.enqueue(item.id) }
                }
            }
            dismiss()
        } catch {
            logger.error("Salvataggio del capo non riuscito: \(error)")
        }
    }
}
