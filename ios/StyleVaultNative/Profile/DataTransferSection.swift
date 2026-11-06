import OSLog
import StyleVaultCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Esporta e importa dal Profilo. Importare aggiunge soltanto: non cancella nulla di ciò che c'è.
struct DataTransferSection: View {
    @Environment(\.modelContext) private var context
    @State private var exported: URL?
    @State private var isBusy = false
    @State private var isPickingFile = false
    @State private var pending: ExportArchive.Contents?
    @State private var summary: ImportSummary?
    @State private var errorKey: String?

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "export")

    var body: some View {
        Section {
            Button(action: export) {
                HStack {
                    Text("native.data.export").foregroundStyle(Palette.ink)
                    if isBusy {
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
            Button { isPickingFile = true } label: { Text("native.data.import").foregroundStyle(Palette.ink) }
                .disabled(isBusy)
                .accessibilityIdentifier("data-import")
            if let summary {
                Text("native.data.imported \(summary.added)")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("data-result")
            }
            if let errorKey {
                Text(LocalizedStringKey(errorKey))
                    .font(.footnote)
                    .foregroundStyle(Palette.danger)
                    .accessibilityIdentifier("data-error")
            }
        } header: {
            Text("native.data.title")
        } footer: {
            Text("native.data.footer")
        }
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.zip]) { result in
            if case let .success(url) = result { open(url) }
        }
        .alert("native.data.confirmTitle", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("common.cancel", role: .cancel) { pending = nil }
            Button("native.data.confirm", action: applyPending)
        } message: {
            if let bundle = pending?.bundle {
                Text("native.data.confirmMessage \(bundle.items.count) \(bundle.outfits.count) \(bundle.calendar.count)")
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
                exported = try DataExporter.export(from: context)
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
            pending = try ExportArchive.read(copy)
        } catch ExportError.newerVersion {
            errorKey = "native.data.newerVersion"
        } catch {
            logger.error("File non letto: \(error.localizedDescription, privacy: .public)")
            errorKey = "native.data.notAnExport"
        }
    }

    private func applyPending() {
        guard let contents = pending else { return }
        pending = nil
        do {
            summary = try DataImporter.apply(contents, to: context)
        } catch {
            logger.error("Importazione non riuscita: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            errorKey = "native.data.importFailed"
        }
    }
}
