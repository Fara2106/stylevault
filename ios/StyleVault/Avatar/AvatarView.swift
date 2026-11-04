import SwiftUI

/// L'avatar: tu, scontornato da iOS, coi capi scelti addosso. Si scorre col
/// dito tra davanti, lato e spalle. Sui telefoni che reggono il calcolo, la
/// vista davanti diventa da sola la versione realistica (Mobile-VTON); lato e
/// spalle si generano a richiesta. Pantaloni e scarpe restano del collage.
/// Se l'ultima generazione si è interrotta (iOS ha chiuso l'app) la vista
/// davanti aspetta "Riprova" invece di partire da sola.
struct AvatarView: View {
    let request: AvatarRequest
    let onClose: () -> Void
    /// "Segnala risultato": chiude l'avatar e apre il Feedback del sito.
    var onReport: () -> Void = {}

    @Environment(\.scenePhase) private var scenePhase

    @State private var images = [BodyView: CGImage]()
    @State private var missingBodyViews = [BodyView]()
    @State private var unavailable = 0
    @State private var loading = true
    @State private var failure: String?
    @State private var selection: BodyView = .front

    // Versione realistica
    @State private var realistic = RealisticAvatarModel.live()
    @State private var photos = [BodyView: URL]()
    @State private var garments = [BodyView: [AvatarComposer.Garment]]()
    /// La foto del corpo data al modello: serve anche per la maschera della composizione.
    @State private var originals = [BodyView: CGImage]()
    /// Vista di cui si stanno scaricando le foto per il modello (i pulsanti restano spenti).
    @State private var loadingInputs: BodyView?
    @State private var notices = [BodyView: String]()
    /// Vista fermata dall'app in background: si riprende al ritorno.
    @State private var interrupted: BodyView?
    /// Schermata chiusa o app non attiva: nessun calcolo nuovo parte.
    @State private var closed = false
    @State private var inBackground = false
    @State private var showCredits = false

    private var realisticItem: AvatarItem? { RealisticAvatarModel.realisticItem(in: request.items) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Vedilo addosso").font(.display(24)).foregroundStyle(Palette.ink)
                Spacer()
                Button { showCredits = true } label: {
                    Image(systemName: "info.circle").font(.body.weight(.medium)).foregroundStyle(Palette.ink)
                        .padding(10)
                }
                .accessibilityLabel("Crediti")
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.body.weight(.medium)).foregroundStyle(Palette.ink)
                        .padding(10)
                }
                .accessibilityLabel("Chiudi")
            }

            if loading {
                Spacer()
                ProgressView("Preparo l'avatar…").tint(Palette.ink).foregroundStyle(Palette.muted)
                Spacer()
            } else if let failure {
                Spacer()
                Text(failure).multilineTextAlignment(.center).foregroundStyle(Palette.muted)
                Spacer()
            } else {
                TabView(selection: $selection) {
                    ForEach(BodyView.allCases) { view in
                        page(view).tag(view)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Text(selection.title.uppercased())
                    .font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Palette.muted)
                if unavailable > 0 {
                    Text(unavailable == 1 ? "1 capo non disponibile" : "\(unavailable) capi non disponibili")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                realisticPanel
            }
        }
        .padding(20)
        .background(Palette.bg.ignoresSafeArea())
        .task {
            await build()
            await restoreSaved()
            // La prima volta si chiede prima di scaricare 1,3 GB (anche in Wi-Fi)
            if realistic.autoStartAllowed, realistic.downloadConsented { await startRealistic(.front) }
        }
        .onDisappear {
            closed = true
            realistic.cancelAll()
        }
        .onChange(of: scenePhase) { _, phase in
            // Solo il background ferma il calcolo: .inactive (Centro di Controllo, notifiche) no
            if phase == .background {
                inBackground = true
                // Niente calcolo in background: si ferma, il download dei modelli invece continua
                if let busy = realistic.busyView ?? loadingInputs { interrupted = busy }
                realistic.cancelAll()
            } else if phase == .active {
                inBackground = false
            }
            if phase == .active, let view = interrupted, !loading {
                interrupted = nil
                Task { await startRealistic(view) }
            }
        }
        .sheet(isPresented: $showCredits) {
            CreditsSheet(realistic: realistic, inputsLoading: loadingInputs != nil) { await removeModels() }
        }
    }

    @ViewBuilder private func page(_ view: BodyView) -> some View {
        if let image = images[view] {
            Image(decorative: image, scale: 1).resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                // AI Act art. 50: la versione realistica è un'immagine generata
                .overlay(alignment: .bottomLeading) {
                    if realistic.state[view] == .ready {
                        Text("Generato con IA")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(10)
                    }
                }
        } else {
            VStack(spacing: 10) {
                Image(systemName: view == .side ? "figure.walk" : "figure.stand")
                    .font(.system(size: 60, weight: .ultraLight))
                Text(missingBodyViews.contains(view)
                     ? "Manca la foto \(view.title.lowercased()): aggiungila dal Profilo."
                     : "Non riesco a preparare questa vista.")
                    .font(.subheadline).multilineTextAlignment(.center)
            }
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Versione realistica

    /// Sotto l'immagine: barra con percentuale, errori, pulsanti per lato e spalle.
    @ViewBuilder private var realisticPanel: some View {
        if realisticItem != nil {
            VStack(spacing: 10) {
                if !realistic.supported {
                    Text(RealisticSupport.requirement)
                        .font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                } else if let busy = realistic.busyView, let state = realistic.state[busy],
                          let text = RealisticAvatarModel.text(for: state) {
                    progressBar(text, fraction: RealisticAvatarModel.fraction(for: state))
                } else if loadingInputs != nil {
                    progressBar("Versione realistica…", fraction: nil)
                }

                // L'errore della vista davanti si vede anche dalle altre pagine
                if selection != .front, case let .failed(message)? = realistic.state[.front] {
                    Text("Davanti: \(message)").font(.footnote).foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                }
                // Prima volta: 1,3 GB solo dopo un sì, anche in Wi-Fi (Apple 4.2.3(ii))
                if realistic.supported, !realistic.downloadConsented, !isBusy,
                   realistic.state[.front] == .collage, photos[.front] != nil {
                    Text(RealisticAvatarModel.downloadConsentText)
                        .font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                    Button("Scarica (1,3 GB)") {
                        realistic.consentToDownload()
                        selection = .front
                        Task { await startRealistic(.front) }
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
                }
                // Rete a consumo o Risparmio dati: si scarica solo col permesso
                if let view = BodyView.allCases.first(where: { realistic.state[$0] == .needsNetworkConsent }) {
                    Text(RealisticAvatarModel.networkConsentText)
                        .font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                    Button("Scarica comunque") {
                        selection = view
                        Task { await startRealistic(view, allowsExpensiveNetwork: true) }
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
                    .disabled(isBusy)
                }
                // L'ultima volta iOS ha chiuso l'app durante il calcolo: si riparte solo a mano
                if !realistic.autoStartAllowed, realistic.state[.front] == .collage, photos[.front] != nil,
                   !isBusy, interrupted == nil {
                    Text(RealisticAvatarModel.interruptedText)
                        .font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                    Button("Riprova") {
                        selection = .front
                        Task { await startRealistic(.front) }
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
                }
                if case let .failed(message)? = realistic.state[selection] {
                    Text(message).font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                    Button("Riprova") { Task { await startRealistic(selection) } }
                        .font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
                        .disabled(isBusy)
                } else if let notice = notices[selection] {
                    Text(notice).font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                }

                if realistic.state[.front] == .ready {
                    HStack(spacing: 10) {
                        generateButton("Genera di profilo", view: .side)
                        generateButton("Genera di spalle", view: .back)
                    }
                }
                // Risultato sbagliato o inappropriato: si segnala dal Feedback del sito
                if realistic.state[selection] == .ready {
                    Button("Segnala risultato", action: onReport)
                        .font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private var isBusy: Bool { realistic.isBusy || loadingInputs != nil }

    @ViewBuilder private func generateButton(_ title: String, view: BodyView) -> some View {
        if photos[view] != nil, realistic.state[view] == .collage {
            Button {
                selection = view
                Task { await startRealistic(view) }
            } label: {
                Text(title).font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
            }
            .foregroundStyle(Palette.ink)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border))
            .disabled(isBusy)
            .opacity(isBusy ? 0.4 : 1)
        }
    }

    private func progressBar(_ text: String, fraction: Double?) -> some View {
        VStack(spacing: 6) {
            if let fraction {
                ProgressView(value: fraction).tint(Palette.accent)
            } else {
                ProgressView().tint(Palette.accent)
            }
            Text(text).font(.footnote).foregroundStyle(Palette.muted).monospacedDigit()
        }
    }

    /// Prende la vista salvata o la genera, poi la compone col collage al posto di quella di prima.
    private func startRealistic(_ view: BodyView, allowsExpensiveNetwork: Bool = false) async {
        guard realistic.supported, failure == nil, !closed, let item = realisticItem, let url = photos[view],
              !isBusy, realistic.state[view] != .ready else { return }
        let bodyKey = CutoutCache.key("body-\(view.rawValue)", url)
        notices[view] = nil
        loadingInputs = view
        let inputs = await Self.loadInputs(body: url, garment: AvatarModel.garmentImageURL(item, view: view))
        loadingInputs = nil
        guard !Task.isCancelled, !closed else { return }
        guard !inBackground else { interrupted = view; return }
        guard let inputs else {
            notices[view] = "Non riesco a scaricare le foto per la versione realistica."
            return
        }
        originals[view] = inputs.person
        await realistic.start(view, person: inputs.person, garment: inputs.garment, item: item, bodyKey: bodyKey,
                              allowsExpensiveNetwork: allowsExpensiveNetwork)
        await showRealistic(view, item: item, bodyKey: bodyKey)
    }

    /// "Elimina i modelli": tolti i modelli si torna al collage in tutte le viste.
    private func removeModels() async {
        guard !isBusy else { return }
        interrupted = nil
        await realistic.removeModels()
        notices.removeAll()
        originals.removeAll()
        await build()
    }

    /// Le viste già generate (riaprendo lo stesso outfit) compaiono subito, senza calcolo.
    private func restoreSaved() async {
        guard realistic.supported, failure == nil, let item = realisticItem else { return }
        for view in BodyView.allCases {
            guard let url = photos[view] else { continue }
            let bodyKey = CutoutCache.key("body-\(view.rawValue)", url)
            guard await realistic.restore(view, item: item, bodyKey: bodyKey) else { continue }
            if originals[view] == nil, let person = await Self.loadImage(url) { originals[view] = person }
            await showRealistic(view, item: item, bodyKey: bodyKey)
        }
    }

    private func showRealistic(_ view: BodyView, item: AvatarItem, bodyKey: String) async {
        guard let raw = realistic.images[view] else { return }
        // Composta (o no) la vista, risultato grezzo e foto non servono più: riaprendo si rileggono dal disco
        defer {
            realistic.releaseImage(view)
            originals[view] = nil
        }
        guard let original = originals[view],
              let composed = try? await RealisticComposer.compose(
                  original: original, realistic: raw, garments: garments[view] ?? [], view: view,
                  key: RealisticCache.cutoutKey(item: item, view: view, bodyKey: bodyKey))
        else {
            notices[view] = "Non riesco a mostrare la versione realistica: resta il collage."
            return
        }
        images[view] = composed
    }

    /// Foto del corpo e del capo come le vuole il modello: orientamento EXIF
    /// applicato, al massimo 2048 px (come lo scontorno, così tutto combacia).
    /// Il capo è la foto prodotto vera, non lo scontorno.
    private static func loadInputs(body: URL, garment: URL?) async -> (person: CGImage, garment: CGImage)? {
        guard let garment else { return nil }
        async let person = loadImage(body)
        async let cloth = loadImage(garment)
        guard let p = await person, let g = await cloth else { return nil }
        return (p, g)
    }

    private static func loadImage(_ url: URL) async -> CGImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            TryOnInputs.image(from: data).map { ImagePrep.downscaled($0) }
        }.value
    }

    // MARK: - Collage

    private func build() async {
        defer { loading = false }
        guard let photos = try? await ProfileService().loadBodyPhotos(), !photos.isEmpty else {
            failure = "Non trovo le tue foto: falle dal Profilo con \"Rifai le foto del corpo\"."
            return
        }
        self.photos = photos
        missingBodyViews = BodyView.allCases.filter { photos[$0] == nil }
        var failedItems = Set<String>()
        for view in BodyView.allCases {
            guard let url = photos[view],
                  let person = try? await CutoutCache.shared.cutout(
                      for: url, key: CutoutCache.key("body-\(view.rawValue)", url), allInstances: false),
                  let pose = try? await BodyPose.detect(person.image) else { continue }
            var viewGarments = [AvatarComposer.Garment]()
            for item in request.items {
                guard let garmentURL = AvatarModel.garmentImageURL(item, view: view),
                      let cutout = try? await CutoutCache.shared.cutout(
                          for: garmentURL, key: CutoutCache.key("item-\(item.id)", garmentURL), allInstances: true)
                else { failedItems.insert(item.id); continue }
                viewGarments.append(.init(slot: item.slot, cutout: cutout))
            }
            garments[view] = viewGarments
            images[view] = AvatarComposer.render(person: person, pose: pose, garments: viewGarments, view: view)
        }
        unavailable = failedItems.count
        if images.isEmpty, failure == nil {
            failure = "Non riesco a preparare l'avatar su questo dispositivo."
        }
    }
}

/// Autori e licenza di Mobile-VTON: la licenza CC BY-NC-SA 4.0 chiede di mostrarli.
/// In fondo si possono togliere i modelli scaricati (1,3 GB).
private struct CreditsSheet: View {
    let realistic: RealisticAvatarModel
    let inputsLoading: Bool
    let onRemove: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Crediti").font(.display(24)).foregroundStyle(Palette.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.body.weight(.medium)).foregroundStyle(Palette.ink).padding(10)
                }
                .accessibilityLabel("Chiudi")
            }
            Text("Versione realistica: Mobile-VTON di Zhenchen Wan, Ce Chen, Runqi Lin, Jiaxin Huang, Tianxi Chen, Yanwu Xu, Tongliang Liu, Mingming Gong (2026).")
                .foregroundStyle(Palette.ink)
            Text("Licenza CC BY-NC-SA 4.0, solo uso non commerciale. Modelli convertiti in Core ML e compressi a 6 bit.")
                .foregroundStyle(Palette.muted)
            Text("Powered by Stability AI")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            Text("This Stability AI Model is licensed under the Stability AI Community License, Copyright © Stability AI Ltd. All Rights Reserved. Componenti anche da OpenAI CLIP, OpenCLIP (MIT) e DINOv2 (Apache 2.0).")
                .font(.footnote).foregroundStyle(Palette.muted)
            VStack(alignment: .leading, spacing: 10) {
                Link("Mobile-VTON su GitHub", destination: URL(string: "https://github.com/tmllab/2026_CVPR_Mobile-VTON")!)
                Link("Licenza CC BY-NC-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-nc-sa/4.0/")!)
                Link("Stability AI Community License", destination: URL(string: "https://stability.ai/community-license-agreement")!)
                Link("Licenze dei componenti",
                     destination: URL(string: "https://github.com/Fara2106/stylevault/releases/tag/avatar-models-v1")!)
            }
            .font(.subheadline.weight(.semibold)).tint(Palette.accent)
            Spacer()
            if realistic.supported {
                // Spento mentre si scarica o si calcola (e mentre si tolgono)
                Button("Elimina i modelli (1,3 GB)", role: .destructive) { confirmRemove = true }
                    .font(.subheadline.weight(.semibold))
                    .disabled(realistic.isBusy || inputsLoading)
                    .confirmationDialog("Eliminare i modelli della versione realistica?",
                                        isPresented: $confirmRemove, titleVisibility: .visible) {
                        Button("Elimina", role: .destructive) {
                            Task {
                                await onRemove()
                                dismiss()
                            }
                        }
                    } message: {
                        Text("Si libera 1,3 GB. La prossima volta si riscaricano.")
                    }
            }
        }
        .font(.subheadline)
        .padding(20)
        .background(Palette.bg.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
