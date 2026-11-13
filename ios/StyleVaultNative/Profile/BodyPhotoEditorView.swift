import OSLog
import PhotosUI
import StyleVaultCore
import SwiftData
import SwiftUI

/// Una foto del corpo: si sceglie, si controlla sul dispositivo e si salva. La foto resta nel tuo iCloud.
struct BodyPhotoEditorView: View {
    let view: BodyView

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bodyPhotoAnalyzer) private var analyzer
    @Query private var photos: [BodyPhoto]

    @State private var pick: PhotosPickerItem?
    @State private var isCameraOpen = false
    @State private var result: BodyPhotoResult?
    @State private var errorKey: String?
    @State private var isBusy = false
    @State private var isDeleteAsked = false

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "body")

    private var saved: BodyPhoto? { BodyPhotoStore.byView(photos)[view] }
    private var isApproved: Bool { result?.check == .ok }
    private var messageKey: String? { errorKey ?? result?.check.messageKey }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(LocalizedStringKey(view.guideKey))
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("body-guide")
                    // Le foto servono a vestire chi usa l'app: niente foto di altri senza consenso.
                    Text("profile.ownPhotoNotice")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("body-notice")
                    preview
                    if let messageKey {
                        Text(LocalizedStringKey(messageKey))
                            .font(.footnote)
                            .foregroundStyle(Palette.danger)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("body-message")
                    }
                    actions
                }
                .padding(16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.bg)
            .navigationTitle(Text(LocalizedStringKey(view.labelKey)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetCloseButton(id: "body-close") { dismiss() } }
            .disabled(isBusy)
        }
        .tint(Palette.ink)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                pick = nil
                await analyze(data)
            }
        }
        .fullScreenCover(isPresented: $isCameraOpen) {
            CameraPicker { data in Task { await analyze(data) } }
                .ignoresSafeArea()
        }
        .alert("native.body.delete", isPresented: $isDeleteAsked) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive) { delete() }
        } message: {
            Text("native.body.deleteConfirm")
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Palette.surface)
            if let image = result?.preview {
                Image(decorative: image, scale: 1).resizable().scaledToFit().padding(8)
            } else if isBusy {
                ProgressView().tint(Palette.ink)
            } else if let saved {
                ItemPhotoView(data: saved.photo, name: "", maxSide: 800, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Image(systemName: view == .side ? "figure.walk" : "figure.stand")
                    .font(.system(size: 90, weight: .ultraLight))
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(height: 340)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border))
    }

    @ViewBuilder private var actions: some View {
        if isApproved {
            Button("native.body.use", action: save)
                .buttonStyle(FilledButtonStyle())
                .accessibilityIdentifier("body-use")
            Button("native.body.retake") { reset() }
                .buttonStyle(OutlineButtonStyle())
                .accessibilityIdentifier("body-retake")
        } else {
            HStack(spacing: 8) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("addItem.takePhoto") { isCameraOpen = true }
                        .buttonStyle(OutlineButtonStyle())
                        .accessibilityIdentifier("body-camera")
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    Text("addItem.uploadPhoto")
                }
                .buttonStyle(FilledButtonStyle())
                .accessibilityIdentifier("body-library")
            }
            if saved != nil {
                Button("native.body.delete") { isDeleteAsked = true }
                    .font(.subheadline)
                    .foregroundStyle(Palette.danger)
                    .padding(.top, 4)
                    .accessibilityIdentifier("body-delete")
            }
        }
    }

    private func analyze(_ data: Data?) async {
        reset()
        guard let data else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            result = try await analyzer.analyze(data, view: view)
        } catch {
            logger.error("Analisi della foto non riuscita: \(error)")
            errorKey = "native.body.analyzeError"
        }
    }

    private func save() {
        guard let jpeg = result?.jpeg else { return }
        do {
            try BodyPhotoStore.save(jpeg, view: view, in: context)
            forgetCutouts()
            dismiss()
        } catch {
            logger.error("Foto del corpo non salvata: \(error)")
            errorKey = "native.body.saveError"
        }
    }

    private func delete() {
        do {
            try BodyPhotoStore.delete(view, in: context)
            forgetCutouts()
            reset()
        } catch {
            logger.error("Foto del corpo non cancellata: \(error)")
            errorKey = "native.body.saveError"
        }
    }

    private func forgetCutouts() {
        let prefix = "body-\(view.rawValue)-"
        Task { await CutoutCache.shared.removeAll(prefix: prefix) }
        // Con una foto del corpo nuova le immagini generate con la vecchia non valgono più
        RealisticCache.removeAll()
        // Il file esportato prima e le foto preparate per la prova contengono ancora quella vecchia
        TemporaryFiles.forgetPhotos()
    }

    private func reset() {
        result = nil
        errorKey = nil
    }
}
