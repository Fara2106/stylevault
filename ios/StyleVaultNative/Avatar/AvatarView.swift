import OSLog
import StyleVaultCore
import SwiftData
import SwiftUI

/// "Vedilo addosso": la persona scontornata con i capi veri sopra, davanti, di lato e di spalle.
/// Non è un'immagine generata: è un collage fatto sul dispositivo con le foto di chi usa l'app.
/// Da qui si apre anche la versione realistica, generata sul dispositivo, dove il dispositivo la regge.
struct AvatarView: View {
    let garments: TryOnSelection

    private enum Page {
        case missing, preparing, failed
        case ready(CGImage, unavailable: Int)
    }

    @Environment(\.avatarRenderer) private var renderer
    @Environment(\.realisticGenerator) private var realistic
    @Environment(\.dismiss) private var dismiss
    @Query private var photos: [BodyPhoto]

    @State private var pages: [BodyView: Page] = [:]
    @State private var selection = BodyView.front
    @State private var editing: BodyView?
    @State private var isPromptOpen = false
    @State private var isRealisticOpen = false

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "avatar")

    private var byView: [BodyView: BodyPhoto] { BodyPhotoStore.byView(photos) }
    private var photoKeys: String { BodyView.allCases.map { byView[$0].map(BodyPhotoStore.key(of:)) ?? "-" }.joined() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TabView(selection: $selection) {
                    ForEach(BodyView.allCases) { view in
                        page(view).tag(view).padding(.bottom, 44)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                Text(LocalizedStringKey(selection.labelKey)).font(.caption).foregroundStyle(Palette.muted)
                if case let .ready(_, unavailable)? = pages[selection], unavailable > 0 {
                    Text("native.avatar.unavailable \(unavailable)").font(.footnote).foregroundStyle(Palette.muted)
                }
                if canShowRealistic {
                    Button { isRealisticOpen = true } label: { SecondaryLabel("native.avatar.realistic") }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("avatar-realistic")
                }
                Button("native.avatar.withAI") { isPromptOpen = true }
                    .font(.subheadline)
                    .tint(Palette.link)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("avatar-prompt")
            }
            .padding(16)
            .background(Palette.bg)
            .navigationTitle(Text("native.avatar.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetCloseButton(id: "avatar-close") { dismiss() } }
        }
        .tint(Palette.ink)
        .task(id: photoKeys) { await build() }
        .sheet(item: $editing) { view in BodyPhotoEditorView(view: view) }
        .sheet(isPresented: $isPromptOpen) { TryOnPromptView(selection: garments) }
        .sheet(isPresented: $isRealisticOpen) { RealisticTryOnView(selection: garments) }
    }

    /// Serve la foto di fronte, almeno un capo che il modello sa mettere e nessun costume.
    private var canShowRealistic: Bool {
        realistic.isAvailable && byView[.front]?.photo != nil && RealisticPlan.make(garments).canGenerate
    }

    @ViewBuilder private func page(_ view: BodyView) -> some View {
        switch pages[view] ?? .preparing {
        case let .ready(image, _):
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityElement()
                .accessibilityLabel(Text("native.avatar.title"))
                .accessibilityIdentifier("avatar-image-\(view.rawValue)")
        case .preparing:
            ProgressView { Text("native.avatar.preparing") }
                .tint(Palette.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .missing:
            notice(view, text: LocalizedStringKey(view.missingKey), action: "native.avatar.addPhoto")
        case .failed:
            notice(view, text: "native.avatar.failed", action: "native.avatar.changePhoto")
        }
    }

    private func notice(_ view: BodyView, text: LocalizedStringKey, action: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Image(systemName: view == .side ? "figure.walk" : "figure.stand")
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundStyle(Palette.muted)
            Text(text).font(.subheadline).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            Button(action) { editing = view }
                .buttonStyle(InkButtonStyle())
                .accessibilityIdentifier("avatar-add-photo")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func build() async {
        let found = byView
        for view in BodyView.allCases { pages[view] = found[view] == nil ? .missing : .preparing }
        if found[selection] == nil, let first = BodyView.allCases.first(where: { found[$0] != nil }) { selection = first }
        for view in BodyView.allCases {
            guard let photo = found[view], let body = photo.photo else { continue }
            let request = AvatarRequest.make(garments, view: view)
            do {
                let result = try await renderer.render(body: body, bodyKey: BodyPhotoStore.key(of: photo),
                                                       garments: request.garments, view: view)
                guard !Task.isCancelled else { return }
                pages[view] = .ready(result.image, unavailable: result.unavailable + request.withoutPhoto)
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Avatar non preparato: \(error)")
                pages[view] = .failed
            }
        }
    }
}
