import FashnKit
import PhotosUI
import SwiftUI
import UIKit

struct TryOnView: View {
    @State private var model = TryOnModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        photoTile(title: "Persona", hint: "In piedi, intera, di fronte", image: model.person, selection: $model.personItem)
                        photoTile(title: "Capo", hint: "Da solo o indossato", image: model.garment, selection: $model.garmentItem)
                    }
                    Picker("Tipo di capo", selection: $model.category) {
                        Text("Sopra").tag(GarmentCategory.tops)
                        Text("Sotto").tag(GarmentCategory.bottoms)
                        Text("Intero").tag(GarmentCategory.onePieces)
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Se nella foto il capo è addosso a qualcuno, l'app lo isola da sola.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Toggle("Usa la foto del capo intera", isOn: $model.useWholeGarmentPhoto).font(.footnote)
                        if model.useWholeGarmentPhoto {
                            Text("Solo per confronto: nel risultato può finire anche la pelle di chi indossa il capo.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                    }
                    Picker("Passi", selection: $model.steps) {
                        Text("12 · veloce").tag(12)
                        Text("20").tag(20)
                        Text("30 · qualità").tag(30)
                    }
                    .pickerStyle(.segmented)

                    if model.isBusy {
                        progress
                    } else {
                        Button { model.generate() } label: { Text("Genera").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!model.canGenerate)
                    }
                    if case .failed(let message) = model.phase {
                        Text("Non riuscito: \(message)").font(.footnote).foregroundStyle(.red)
                    }
                    if let result = model.result { resultSection(result) }
                }
                .padding()
                
            }
            #if targetEnvironment(simulator)
            .onAppear { if CommandLine.arguments.contains("--finta") { model.fakeProgress() } }
            #endif
            .navigationTitle("Prova FASHN")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// La barra di avanzamento con la percentuale accanto.
    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ProgressView(value: model.progress?.fraction ?? 0)
                    .accessibilityIdentifier("generation-progress")
                Text("\(model.progress?.percent ?? 0)%")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 52, alignment: .trailing)
                    .accessibilityIdentifier("generation-percent")
            }
            HStack {
                Text(phaseText).font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(model.elapsed)) s").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text("Tieni l'app aperta in primo piano finché non finisce.").font(.footnote).foregroundStyle(.secondary)
            Button("Annulla", role: .cancel) { model.cancel() }.buttonStyle(.bordered)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var phaseText: String {
        switch model.phase {
        case .preparing: return "Preparo le foto e cerco la posa…"
        case .loadingModel: return "Carico il modello…"
        case .generating:
            if model.coolingDown { return "In pausa: il telefono è caldo, aspetto che si raffreddi" }
            guard let progress = model.progress, progress.step > 0 else { return "Avvio la generazione…" }
            return "Passo \(progress.step) di \(progress.steps)"
        default: return ""
        }
    }

    private func resultSection(_ result: CGImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(uiImage: UIImage(cgImage: result)).resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Risultato")
            Text(model.summary).font(.footnote).foregroundStyle(.secondary)
            if model.bodyPoints < 10 {
                Text("Posa incerta: la persona si vede poco o non è intera.").font(.footnote).foregroundStyle(.orange)
            }
            ShareLink(item: Image(uiImage: UIImage(cgImage: result)), preview: SharePreview("Prova FASHN", image: Image(uiImage: UIImage(cgImage: result)))) {
                Label("Salva o condividi", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button { model.useResultAsPerson() } label: {
                Label("Aggiungi un altro capo a questo risultato", systemImage: "plus.square.on.square").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            if let garment = model.isolatedGarment {
                DisclosureGroup("Capo isolato dato al modello") {
                    Image(uiImage: UIImage(cgImage: garment)).resizable().scaledToFit().frame(maxHeight: 280)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                }
                .font(.footnote)
            }
            if let sketch = model.poseSketch {
                DisclosureGroup("Posa vista dal telefono") {
                    Image(uiImage: UIImage(cgImage: sketch)).resizable().scaledToFit().frame(maxHeight: 280)
                }
                .font(.footnote)
            }
        }
    }

    private func photoTile(title: String, hint: String, image: CGImage?, selection: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: selection, matching: .images) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5))
                    if let image {
                        Image(uiImage: UIImage(cgImage: image)).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus").font(.title2)
                            Text(hint).font(.caption).multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.secondary)
                        .padding(8)
                    }
                }
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            }
        }
        .disabled(model.isBusy)
    }
}
