import StyleVaultCore
import SwiftData
import SwiftUI
import UIKit

/// Prompt da portare in ChatGPT o Gemini. L'app non manda nulla da sola: foto e testo li consegna chi
/// la usa, dopo aver letto a chi vanno.
struct TryOnPromptView: View {
    let selection: TryOnSelection

    @AppStorage("tryon.ai.accepted") private var accepted = false
    @Environment(\.dismiss) private var dismiss
    @Query private var photos: [BodyPhoto]
    @State private var copied = false
    @State private var files: [URL] = []

    private var frontPhoto: Data? { BodyPhotoStore.byView(photos)[.front]?.photo }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if accepted { steps } else { consent }
                }
                .padding(16)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.bg)
            .navigationTitle(Text("tryon.promptTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetCloseButton(id: "prompt-close") { dismiss() } }
        }
        .tint(Palette.ink)
        .task(id: accepted) { if accepted { prepareFiles() } }
        // Le copie sono state tolte perché una foto del corpo è cambiata o sparita: si rifanno con quelle di adesso.
        .onReceive(NotificationCenter.default.publisher(for: TemporaryFiles.photosForgotten)) { _ in
            if accepted { prepareFiles() }
        }
    }

    private var consent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("native.prompt.consentTitle").font(.headline).foregroundStyle(Palette.ink)
            Text("native.prompt.consentText").foregroundStyle(Palette.ink)
                .accessibilityIdentifier("prompt-consent")
            Button { accepted = true } label: { PrimaryLabel("native.prompt.accept") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("prompt-accept")
            Button { dismiss() } label: { SecondaryLabel("native.prompt.decline") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("prompt-decline")
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("tryon.promptIntro").foregroundStyle(Palette.ink)
            if TryOnPrompt.hasSwimwear(selection.promptGarments) {
                Text("tryon.swimwearPhoto")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                    .padding(10)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("prompt-swimwear")
            }
            if frontPhoto == nil {
                Text("native.prompt.needsPhoto").font(.footnote).foregroundStyle(Palette.danger)
                    .accessibilityIdentifier("prompt-needs-photo")
            }
            Button {
                UIPasteboard.general.string = TryOnPrompt.build(selection.promptGarments)
                copied = true
            } label: {
                PrimaryLabel(copied ? "tryon.promptCopied" : "tryon.promptCopy")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("prompt-copy")
            if !files.isEmpty {
                ShareLink(items: files) { SecondaryLabel("tryon.promptShare") }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("prompt-share")
                Text("native.prompt.shareHint").font(.footnote).foregroundStyle(Palette.muted)
            }
            AdaptiveRow {
                link("tryon.promptOpenChatgpt", "https://chatgpt.com/")
                link("tryon.promptOpenGemini", "https://gemini.google.com/")
            }
        }
    }

    private func link(_ title: LocalizedStringKey, _ address: String) -> some View {
        Link(destination: URL(string: address)!) {
            Label { Text(title) } icon: { Image(systemName: "arrow.up.right.square") }
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Palette.link)
        }
    }

    /// Foto numerate come nel prompt: la persona è la 1, poi i capi nello stesso ordine.
    private func prepareFiles() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("prova", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var found: [URL] = []
        func add(_ data: Data?, _ number: Int) {
            guard let data else { return }
            let url = folder.appendingPathComponent("\(number).jpg")
            if (try? data.write(to: url)) != nil { found.append(url) }
        }
        add(frontPhoto, 1)
        for (index, item) in selection.all.enumerated() { add(item.photoFront, index + 2) }
        files = found
    }
}
