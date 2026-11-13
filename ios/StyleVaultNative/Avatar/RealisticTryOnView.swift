import OSLog
import StyleVaultCore
import SwiftData
import SwiftUI
import UIKit

/// Lo stato della versione realistica: cosa si può generare, a che punto è, cosa è uscito.
@MainActor @Observable final class RealisticTryOnModel {
    enum Phase: Equatable { case idle, generating, done, failed }

    let plan: RealisticPlan
    private(set) var phase = Phase.idle
    private(set) var progress: RealisticProgress?
    private(set) var result: CGImage?
    /// L'immagine mostrata viene da una generazione precedente.
    private(set) var isFromCache = false

    @ObservationIgnored private var task: Task<Void, Never>?
    /// Quale generazione è quella in corso: i risultati di una annullata non contano più.
    @ObservationIgnored private var run = 0
    @ObservationIgnored private let cacheFolder: URL
    @ObservationIgnored private let keepAwake: (Bool) -> Void
    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "realistic")

    init(plan: RealisticPlan, cacheFolder: URL = RealisticCache.folder,
         keepAwake: @escaping (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 }) {
        self.plan = plan
        self.cacheFolder = cacheFolder
        self.keepAwake = keepAwake
    }

    var isGenerating: Bool { phase == .generating }

    /// All'apertura: se questo outfit è già stato generato con questa foto, si mostra subito.
    func restore(bodyKey: String) {
        guard phase == .idle, let image = RealisticCache.load(RealisticCache.key(bodyKey: bodyKey, pieces: plan.pieces), in: cacheFolder) else { return }
        result = image
        isFromCache = true
        phase = .done
    }

    func generate(body: Data, bodyKey: String, with generator: any RealisticGenerating) {
        guard !isGenerating, plan.canGenerate else { return }
        phase = .generating
        progress = RealisticProgress(fraction: 0, garment: 1, garments: plan.pieces.count)
        let pieces = plan.pieces
        let key = RealisticCache.key(bodyKey: bodyKey, pieces: pieces)
        run += 1
        let current = run
        // Una generazione annullata può metterci secondi a fermarsi (il modello si sta caricando): la nuova aspetta,
        // così il modello non è mai in memoria due volte
        let previous = task
        task = Task {
            await previous?.value
            guard current == run else { return }
            // La generazione dura minuti: lo schermo non deve spegnersi
            keepAwake(true)
            defer { keepAwake(false) }
            do {
                let image = try await generator.generate(body: body, bodyKey: bodyKey, pieces: pieces) { value in
                    Task { @MainActor [weak self] in
                        guard let self, self.run == current, self.phase == .generating else { return }
                        // I passaggi arrivano da un altro filo: la barra non deve mai tornare indietro
                        if value.fraction >= (self.progress?.fraction ?? 0) { self.progress = value }
                    }
                }
                // Annullata nel frattempo: l'immagine arrivata tardi non si mostra e non si salva
                guard current == run else { return }
                RealisticCache.save(image, key: key, in: cacheFolder)
                result = image
                isFromCache = false
                phase = .done
            } catch {
                guard current == run else { return }
                logger.error("Versione realistica non generata: \(error)")
                phase = .failed
            }
        }
    }

    /// Chi tocca «Annulla» lo vede subito, anche se il modello impiega qualche secondo a fermarsi davvero.
    func cancel() {
        guard isGenerating else { return }
        task?.cancel()
        run += 1
        progress = nil
        phase = result == nil ? .idle : .done
    }

    /// La foto del corpo è cambiata o sparita, anche da un altro dispositivo: ciò che si sta generando o
    /// mostrando è fatto con quella di prima. Non si mostra più e, se arriva tardi, non si salva.
    func forget() {
        task?.cancel()
        run += 1
        progress = nil
        result = nil
        isFromCache = false
        phase = .idle
    }

    /// Per i test: aspetta la fine della generazione in corso.
    func waitUntilFinished() async {
        await task?.value
    }
}

/// "Versione realistica": un'immagine generata sul dispositivo con i capi addosso. La barra con la percentuale dice a che
/// punto è; il risultato è sempre etichettato come generato con IA e si può segnalare.
struct RealisticTryOnView: View {
    let selection: TryOnSelection

    @Environment(\.realisticGenerator) private var generator
    @Environment(\.dismiss) private var dismiss
    @Query private var photos: [BodyPhoto]
    @State private var model: RealisticTryOnModel
    @State private var isReporting = false
    @State private var isAskingToStop = false

    init(selection: TryOnSelection) {
        self.selection = selection
        _model = State(initialValue: RealisticTryOnModel(plan: RealisticPlan.make(selection)))
    }

    private var front: BodyPhoto? { BodyPhotoStore.byView(photos)[.front] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let image = model.result { result(image) }
                    switch model.phase {
                    case .generating: progress
                    case .failed:
                        Text("native.realistic.failed").font(.subheadline).foregroundStyle(Palette.danger)
                            .accessibilityIdentifier("realistic-failed")
                        start("native.realistic.again")
                    case .done: start("native.realistic.again")
                    case .idle:
                        intro
                        start("native.realistic.generate")
                    }
                }
                .padding(16)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.bg)
            .navigationTitle(Text("native.realistic.title"))
            .navigationBarTitleDisplayMode(.inline)
            // Chiudere a metà butta via minuti di lavoro: si chiede prima
            .toolbar { SheetCloseButton(id: "realistic-close") { if model.isGenerating { isAskingToStop = true } else { dismiss() } } }
            // Un avviso, come quando si scarta la bozza di un capo: nei menu di conferma il tasto per restare non si vede
            .alert("native.realistic.stopTitle", isPresented: $isAskingToStop) {
                Button("native.realistic.stopKeep", role: .cancel) {}
                Button("native.realistic.stopConfirm", role: .destructive) { dismiss() }
            }
        }
        .tint(Palette.ink)
        .interactiveDismissDisabled(model.isGenerating)
        .onAppear { if let front { model.restore(bodyKey: BodyPhotoStore.key(of: front)) } }
        .onDisappear { model.cancel() }
        .onChange(of: front.map(BodyPhotoStore.key(of:))) { model.forget() }
        .sheet(isPresented: $isReporting) { NavigationStack { FeedbackView() }.tint(Palette.ink) }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("native.realistic.intro").foregroundStyle(Palette.ink)
            Text("native.realistic.pieces \(model.plan.pieces.map(\.name).formatted(.list(type: .and)))")
                .font(.subheadline).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("realistic-pieces")
            if !model.plan.leftOut.isEmpty {
                Text("native.realistic.leftOut \(model.plan.leftOut.formatted(.list(type: .and)))")
                    .font(.footnote).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("realistic-left-out")
            }
            Text("native.realistic.time").font(.footnote).foregroundStyle(Palette.muted)
        }
    }

    private func start(_ title: LocalizedStringKey) -> some View {
        Button {
            guard let front, let body = front.photo else { return }
            model.generate(body: body, bodyKey: BodyPhotoStore.key(of: front), with: generator)
        } label: {
            if model.phase == .idle { PrimaryLabel(title) } else { SecondaryLabel(title) }
        }
        .buttonStyle(.plain)
        .disabled(front?.photo == nil)
        .accessibilityIdentifier("realistic-generate")
    }

    /// La barra di avanzamento con la percentuale accanto.
    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ProgressView(value: model.progress?.fraction ?? 0)
                    .tint(Palette.ink)
                    .accessibilityIdentifier("realistic-progress")
                Text(verbatim: "\(model.progress?.percent ?? 0)%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 52, alignment: .trailing)
                    .accessibilityIdentifier("realistic-percent")
            }
            if let progress = model.progress {
                Text(status(progress)).font(.footnote).foregroundStyle(progress.pause == nil ? Palette.muted : Palette.ink)
                    .accessibilityIdentifier("realistic-status")
            }
            Text("native.realistic.keepOpen").font(.footnote).foregroundStyle(Palette.muted)
            Button { model.cancel() } label: { SecondaryLabel("common.cancel") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("realistic-cancel")
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border))
    }

    private func status(_ progress: RealisticProgress) -> LocalizedStringKey {
        switch progress.pause {
        case .heat: return "native.realistic.pausedHeat"
        case .background: return "native.realistic.pausedBackground"
        case nil:
            let name = model.plan.pieces.indices.contains(progress.garment - 1) ? model.plan.pieces[progress.garment - 1].name : ""
            return "native.realistic.working \(progress.garment) \(progress.garments) \(name)"
        }
    }

    private func result(_ image: CGImage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                // L'etichetta «generata con IA» deve vedersi subito sotto l'immagine, senza scorrere
                .frame(maxWidth: .infinity, maxHeight: 420)
                .accessibilityElement()
                .accessibilityLabel(Text("native.realistic.imageLabel"))
                .accessibilityIdentifier("realistic-image")
            Label("native.realistic.aiLabel", systemImage: "sparkles")
                .font(.footnote)
                .foregroundStyle(Palette.ink)
                .accessibilityIdentifier("realistic-ai-label")
            if !model.plan.leftOut.isEmpty {
                Text("native.realistic.leftOut \(model.plan.leftOut.formatted(.list(type: .and)))")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            if !model.isGenerating {
                let picture = Image(decorative: image, scale: 1)
                ShareLink(item: picture, preview: SharePreview(Text("native.realistic.title"), image: picture)) {
                    SecondaryLabel("native.realistic.share")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("realistic-share")
                Button("native.realistic.report") { isReporting = true }
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .tint(Palette.link)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("realistic-report")
            }
        }
    }
}
