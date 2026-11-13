import OSLog
import StyleVaultCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Esporta e importa dal Profilo. Importare aggiunge soltanto: non cancella nulla di ciò che c'è.
struct DataTransferSection: View {
    @Environment(\.modelContext) private var context
    @Environment(CutoutWorker.self) private var cutoutWorker
    @State private var exported: URL?
    @State private var isBusy = false
    @State private var isImporting = false
    @State private var isPickingFile = false
    @State private var pending: ExportArchive.Contents?
    @State private var importCopy: URL?
    @State private var summary: ImportSummary?
    @State private var errorKey: String?

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "export")

    var body: some View {
        Section {
            Button(action: export) {
                HStack {
                    Text("native.data.export").foregroundStyle(Palette.ink)
                    if isBusy, !isImporting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isBusy)
            .accessibilityIdentifier("data-export")
            if let exported {
                ShareLink(item: exported) {
                    Label { Text("native.data.share") } icon: { Image(systemName: "square.and.arrow.up") }
                        .foregroundStyle(Palette.link)
                }
                .accessibilityIdentifier("data-share")
            }
            Button { isPickingFile = true } label: {
                HStack {
                    Text("native.data.import").foregroundStyle(Palette.ink)
                    if isImporting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
                .disabled(isBusy)
                .accessibilityIdentifier("data-import")
            if let summary {
                Text("native.data.imported \(summary.added)")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("data-result")
                if summary.recoveredPhotos > 0 {
                    Text("native.data.recoveredPhotos \(summary.recoveredPhotos)")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("data-recovered-photos")
                }
                if summary.missingPhotos > 0 {
                    Text("native.data.missingPhotos \(summary.missingPhotos)")
                        .font(.footnote)
                        .foregroundStyle(Palette.danger)
                        .accessibilityIdentifier("data-missing-photos")
                }
            }
            if let errorKey {
                Text(LocalizedStringKey(errorKey))
                    .font(.footnote)
                    .foregroundStyle(Palette.danger)
                    .accessibilityIdentifier("data-error")
            }
        } header: {
            Text("native.data.title").foregroundStyle(Palette.muted)
        } footer: {
            Text("native.data.footer").foregroundStyle(Palette.muted)
        }
        // Cancellata o cambiata una foto del corpo, il file esportato prima non c'è più: non si offre.
        .onReceive(NotificationCenter.default.publisher(for: TemporaryFiles.photosForgotten)) { _ in exported = nil }
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.zip]) { result in
            if case let .success(url) = result { open(url) }
        }
        .alert("native.data.confirmTitle", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("common.cancel", role: .cancel) {
                pending = nil
                dropImportCopy()
            }
            Button("native.data.confirm", action: applyPending)
        } message: {
            if let bundle = pending?.bundle {
                // Tutto ciò che il file porta, comprese le foto del corpo: chi conferma deve saperlo prima.
                Text("native.data.confirmMessage \(bundle.items.count) \(bundle.wishlist.count) \(bundle.outfits.count) \(bundle.calendar.count) \(Set(bundle.bodyPhotos.map(\.kind).filter { BodyView(rawValue: $0) != nil }).count)")
            }
        }
    }

    private func export() {
        isBusy = true
        errorKey = nil
        Task {
            // Lascia disegnare la rotellina prima del lavoro sulle foto.
            await Task.yield()
            defer { isBusy = false }
            do {
                let url = try await DataExporter.export(from: context)
                // Se nel frattempo le copie temporanee sono state tolte, il file non c'è: meglio dirlo che offrirlo.
                guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
                exported = url
            } catch {
                logger.error("Esportazione non riuscita: \(error.localizedDescription, privacy: .public)")
                errorKey = "native.data.exportFailed"
            }
        }
    }

    private func open(_ url: URL) {
        errorKey = nil
        summary = nil
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            // Copia locale: l'accesso al file scelto finisce qui, la conferma arriva dopo.
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("importa-\(UUID().uuidString).zip")
            try FileManager.default.copyItem(at: url, to: copy)
            importCopy = copy
            pending = try ExportArchive.read(copy)
        } catch ExportError.newerVersion {
            dropImportCopy()
            errorKey = "native.data.newerVersion"
        } catch {
            dropImportCopy()
            logger.error("File non letto: \(error.localizedDescription, privacy: .public)")
            errorKey = "native.data.notAnExport"
        }
    }

    private func applyPending() {
        guard let contents = pending else { return }
        pending = nil
        isBusy = true
        isImporting = true
        Task {
            defer {
                isBusy = false
                isImporting = false
                dropImportCopy()
            }
            do {
                summary = try await DataImporter.apply(contents, to: context)
                // I capi arrivati dal sito non hanno lo scontorno.
                cutoutWorker.enqueueMissing()
            } catch {
                logger.error("Importazione non riuscita: \(error.localizedDescription, privacy: .public)")
                errorKey = "native.data.importFailed"
            }
        }
    }

    /// La copia contiene le foto: finita l'importazione non serve più.
    private func dropImportCopy() {
        if let importCopy { try? FileManager.default.removeItem(at: importCopy) }
        importCopy = nil
    }
}
