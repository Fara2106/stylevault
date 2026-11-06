import OSLog
import PhotosUI
import StyleVaultCore
import SwiftData
import SwiftUI

/// Foto, colori personali correggibili, stagione, palette, outfit con i negozi, capi in palette e make-up.
/// L'analisi resta sul dispositivo; la stagione si può anche scegliere a mano.
struct ArmocromiaView: View {
    private enum Phase { case idle, analyzing, detected, result }

    @Environment(\.modelContext) private var context
    @Environment(\.faceAnalyzer) private var analyzer
    @Query private var profiles: [Profile]
    @Query private var photos: [BodyPhoto]
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]

    @State private var phase: Phase = .idle
    @State private var detected = FaceColors()
    @State private var failed = false
    @State private var verdict: ArmocromiaVerdict?
    @State private var isSaved = false
    @State private var pick: PhotosPickerItem?
    @State private var didLoad = false

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "armocromia")

    private var saved: ArmocromiaVerdict? { ArmocromiaVerdict.decode(ProfileStore.survivor(of: profiles)?.armocromia) }
    private var frontPhoto: Data? { BodyPhotoStore.byView(photos)[.front]?.photo }
    private var season: ArmocromiaSeason? { ArmocromiaSeasons.season(id: verdict?.season) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch phase {
                case .idle: intro
                case .analyzing: analyzing
                case .detected: colorsToCheck
                case .result: if let season { result(season) }
                }
            }
            .padding(16)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg)
        .navigationTitle(Text("armocromia.ui.title"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.ink)
        .onAppear(perform: loadSaved)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                pick = nil
                await analyze(data)
            }
        }
    }

    private func loadSaved() {
        guard !didLoad else { return }
        didLoad = true
        guard let saved else { return }
        verdict = saved
        detected = saved.detected
        isSaved = true
        phase = .result
    }

    // MARK: Inizio

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("armocromia.ui.intro").foregroundStyle(Palette.ink)
            Text("armocromia.ui.photoHint").font(.footnote).foregroundStyle(Palette.muted)
            if let frontPhoto {
                Button { Task { await analyze(frontPhoto) } } label: { PrimaryLabel("armocromia.ui.usePhoto") }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("armocromia-use-photo")
            } else {
                Text("armocromia.ui.noPhotoHint").font(.footnote).foregroundStyle(Palette.muted)
            }
            PhotosPicker(selection: $pick, matching: .images) { SecondaryLabel("armocromia.ui.uploadPhoto") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("armocromia-upload")
            Menu {
                ForEach(ArmocromiaSeasons.all) { season in
                    Button(LocalizedStringKey(season.nameKey)) { choose(season) }
                }
            } label: {
                SecondaryLabel("armocromia.ui.chooseByHand")
            }
            .accessibilityIdentifier("armocromia-by-hand")
        }
    }

    private var analyzing: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("armocromia.ui.analyzing").foregroundStyle(Palette.muted)
        }
        .accessibilityIdentifier("armocromia-analyzing")
    }

    private func analyze(_ data: Data?) async {
        phase = .analyzing
        failed = false
        var found = FaceColors()
        if let data {
            do {
                found = try await analyzer.analyze(data)
            } catch {
                logger.error("Analisi non riuscita: \(error.localizedDescription, privacy: .public)")
            }
        }
        failed = found == FaceColors()
        // Ciò che l'analisi non trova riparte dall'ultima correzione salvata.
        let previous = saved?.detected ?? FaceColors()
        detected = FaceColors(skin: found.skin ?? previous.skin, hair: found.hair ?? previous.hair,
                              eyes: found.eyes ?? previous.eyes)
        phase = .detected
    }

    // MARK: Colori da controllare

    private var colorsToCheck: some View {
        VStack(alignment: .leading, spacing: 12) {
            if failed {
                Text("armocromia.ui.analysisFailed")
                    .font(.footnote)
                    .foregroundStyle(Palette.danger)
                    .accessibilityIdentifier("armocromia-failed")
            }
            Text("armocromia.ui.detectedTitle").font(.headline).foregroundStyle(Palette.ink)
            colorRow("armocromia.ui.skin", \.skin, id: "skin")
            colorRow("armocromia.ui.hair", \.hair, id: "hair")
            colorRow("armocromia.ui.eyes", \.eyes, id: "eyes")
            Button(action: compute) { PrimaryLabel("armocromia.ui.compute") }
                .buttonStyle(.plain)
                .disabled(detected.skin == nil && detected.hair == nil)
                .accessibilityIdentifier("armocromia-compute")
            if detected.skin == nil && detected.hair == nil {
                Text("armocromia.ui.needTwo").font(.footnote).foregroundStyle(Palette.muted)
            }
        }
    }

    private func colorRow(_ title: LocalizedStringKey, _ path: WritableKeyPath<FaceColors, String?>, id: String) -> some View {
        ColorPicker(selection: Binding(
            get: { Color(hex: detected[keyPath: path] ?? "") },
            set: { detected[keyPath: path] = $0.hexString }
        ), supportsOpacity: false) {
            HStack {
                Text(title).foregroundStyle(Palette.ink)
                if detected[keyPath: path] == nil {
                    Text("armocromia.ui.missingColor").font(.footnote).foregroundStyle(Palette.muted)
                }
            }
        }
        .accessibilityIdentifier("armocromia-color-\(id)")
    }

    private func compute() {
        guard let result = ArmocromiaClassifier.classify(detected) else { return }
        verdict = ArmocromiaVerdict(season: result.season, detected: detected, confidence: result.confidence)
        isSaved = false
        phase = .result
    }

    /// La stagione scelta a mano vale subito: non c'è un verdetto da confermare.
    private func choose(_ season: ArmocromiaSeason) {
        let choice = ArmocromiaVerdict(season: season.id, detected: saved?.detected ?? FaceColors(), chosenByHand: true)
        verdict = choice
        detected = choice.detected
        save(choice)
        phase = .result
    }

    private func save(_ value: ArmocromiaVerdict) {
        guard let data = try? value.encoded() else { return }
        ProfileStore.update(profiles, in: context) {
            $0.armocromia = data
            $0.updatedAt = .now
        }
        isSaved = true
    }

    // MARK: Risultato

    private func result(_ season: ArmocromiaSeason) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            verdictCard(season)
            section("armocromia.ui.paletteTitle") {
                Text("armocromia.ui.paletteHint").font(.footnote).foregroundStyle(Palette.muted)
                SwatchGrid(colors: season.palette, linked: true)
            }
            section("armocromia.ui.neutralsTitle") { SwatchGrid(colors: season.neutrals, linked: true) }
            section("armocromia.ui.avoidTitle") { SwatchGrid(colors: season.avoid, linked: false) }
            HStack(spacing: 4) {
                Text("armocromia.ui.metalTitle")
                Text(":")
                Text(LocalizedStringKey(season.metalKey)).bold()
            }
            .font(.subheadline)
            .foregroundStyle(Palette.ink)
            section("armocromia.ui.outfitsTitle") { outfits(season) }
            section("armocromia.ui.wardrobeTitle") { wardrobe(season) }
            section("armocromia.ui.makeupTitle") { makeup(season) }
            actions
        }
    }

    private func verdictCard(_ season: ArmocromiaSeason) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(season.nameKey))
                .font(.display(26))
                .foregroundStyle(Palette.ink)
                .accessibilityIdentifier("armocromia-season-name")
            Text(LocalizedStringKey(season.descKey)).foregroundStyle(Palette.ink)
            if verdict?.chosenByHand == true {
                Text("armocromia.ui.byHandNote").font(.footnote).foregroundStyle(Palette.muted)
            } else {
                let percent = Int(((verdict?.confidence ?? 0) * 100).rounded())
                HStack(spacing: 4) {
                    Text("armocromia.ui.confidence")
                    Text(verbatim: ": \(percent)% —")
                    Text(LocalizedStringKey(season.undertoneKey))
                }
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                if (verdict?.confidence ?? 0) < 0.25 {
                    Text("armocromia.ui.confidenceLow").font(.footnote).foregroundStyle(Palette.danger)
                }
            }
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(Palette.ink)
            content()
        }
    }

    private func outfits(_ season: ArmocromiaSeason) -> some View {
        let parts = [localized("armocromia.ui.outfitTop"), localized("armocromia.ui.outfitBottom"),
                     localized("armocromia.ui.outfitShoes")]
        // Un capo, un negozio, a rotazione: l'outfit si compone fra negozi diversi.
        let shops = ["zara", "hm", "zalando"]
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(season.outfits.enumerated()), id: \.offset) { index, combo in
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(combo.enumerated()), id: \.offset) { part, color in
                        let text = "\(parts[part]) \(localized(color.nameKey))"
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: color.hex)).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(Palette.border))
                            Text(verbatim: text).font(.subheadline).foregroundStyle(Palette.ink)
                            Spacer()
                            if let link = ShopLinks.one(shop: shops[(index + part) % shops.count], query: text,
                                                        language: ShopLanguage.current) {
                                ShopLinkView(link: link)
                            }
                        }
                    }
                }
                .padding(10)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
            }
            homeShops(.clothing)
        }
    }

    private func homeShops(_ kind: ShopKind) -> some View {
        HStack(spacing: 10) {
            Text("armocromia.ui.alsoOn").font(.footnote).foregroundStyle(Palette.muted)
            ForEach(ShopLinks.home(kind: kind, language: ShopLanguage.current)) { ShopLinkView(link: $0) }
        }
    }

    private func wardrobe(_ season: ArmocromiaSeason) -> some View {
        let matches = ArmocromiaWardrobe.match(items.map { ($0.id.uuidString, $0.colors) }, season: season.id).prefix(8)
        return VStack(alignment: .leading, spacing: 8) {
            if matches.isEmpty {
                Text("armocromia.ui.wardrobeEmpty").font(.footnote).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("armocromia-wardrobe-empty")
            }
            ForEach(matches, id: \.id) { match in
                if let item = items.first(where: { $0.id.uuidString == match.id }) {
                    HStack(spacing: 10) {
                        ItemPhotoView(data: item.cutout ?? item.photoFront, name: item.name)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text(verbatim: item.name).font(.subheadline).foregroundStyle(Palette.ink)
                        Spacer()
                        Circle().fill(Color(hex: match.paletteHex)).frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Palette.border))
                    }
                    .accessibilityIdentifier("armocromia-wardrobe-item")
                }
            }
        }
    }

    private func makeup(_ season: ArmocromiaSeason) -> some View {
        let rows: [(String, [SeasonColor], String)] = [
            ("armocromia.ui.lips", season.makeup.lips, "armocromia.ui.lipstick"),
            ("armocromia.ui.blush", season.makeup.blush, "armocromia.ui.blushQuery"),
            ("armocromia.ui.eyeshadow", season.makeup.eyes, "armocromia.ui.eyeshadowQuery"),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(rows, id: \.0) { title, colors, query in
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(title)).font(.subheadline).foregroundStyle(Palette.muted)
                    SwatchGrid(colors: colors, linked: false)
                    HStack(spacing: 12) {
                        ForEach(ShopLinks.search(kind: .makeup, query: "\(localized(query)) \(localized(colors[0].nameKey))",
                                                 language: ShopLanguage.current)) { ShopLinkView(link: $0) }
                    }
                }
            }
            HStack(spacing: 4) {
                Text("armocromia.ui.foundation")
                Text(":")
                Text(LocalizedStringKey(season.undertoneKey))
            }
            .font(.subheadline)
            .foregroundStyle(Palette.muted)
            homeShops(.makeup)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                if let verdict { save(verdict) }
            } label: {
                PrimaryLabel(isSaved ? "armocromia.ui.saved" : "armocromia.ui.save")
            }
            .buttonStyle(.plain)
            .disabled(isSaved)
            .opacity(isSaved ? 0.6 : 1)
            .accessibilityIdentifier("armocromia-save")
            Button {
                phase = .idle
                verdict = nil
            } label: {
                SecondaryLabel("armocromia.ui.redo")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("armocromia-redo")
        }
    }
}

/// Campioni di colore. Quelli collegati cercano il colore su Zalando.
private struct SwatchGrid: View {
    let colors: [SeasonColor]
    let linked: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), alignment: .top)], alignment: .leading, spacing: 10) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                if linked, let link = ShopLinks.one(shop: "zalando", query: localized(color.nameKey),
                                                    language: ShopLanguage.current) {
                    Link(destination: link.url) { swatch(color) }
                } else {
                    swatch(color)
                }
            }
        }
    }

    private func swatch(_ color: SeasonColor) -> some View {
        VStack(spacing: 4) {
            Circle().fill(Color(hex: color.hex)).frame(width: 40, height: 40)
                .overlay(Circle().stroke(Palette.border))
            Text(LocalizedStringKey(color.nameKey))
                .font(.caption)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShopLinkView: View {
    let link: ShopLink

    var body: some View {
        Link(destination: link.url) {
            Label { Text(verbatim: link.label) } icon: { Image(systemName: "arrow.up.right.square") }
                .font(.footnote)
                .foregroundStyle(Palette.link)
                .frame(minHeight: 44)
        }
    }
}

/// Tasto pieno delle schermate a piena pagina.
struct PrimaryLabel: View {
    private let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Palette.bg)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Tasto secondario, solo bordo.
struct SecondaryLabel: View {
    private let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Palette.ink)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border))
    }
}
