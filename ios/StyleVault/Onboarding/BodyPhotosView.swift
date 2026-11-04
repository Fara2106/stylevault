import PhotosUI
import SwiftUI

/// Primo accesso (e "Rifai le foto del corpo"): una vista alla volta, foto da
/// fotocamera o libreria, scontorno di iOS come anteprima, controllo che ci
/// sia una persona sola e intera, poi upload nel profilo.
struct BodyPhotosView: View {
    /// Dichiarazione sulle foto (protezione delle immagini di persone).
    nonisolated static let ownPhotoNotice =
        "Usa solo foto di te: scattandole confermi che ritraggono te, oppure una persona che ti ha dato il consenso."

    let views: [BodyView]
    /// "Più tardi" al primo accesso, "Chiudi" quando si rifanno dal Profilo
    var leaveTitle = "Più tardi"
    let onDone: () -> Void

    @State private var index = 0
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var original: CGImage?
    @State private var preview: CGImage?
    @State private var check: PhotoCheck?
    @State private var error: String?
    @State private var busy = false

    private let profile = ProfileService()
    private var current: BodyView { views[index] }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(leaveTitle, action: onDone)
                Spacer()
                Button("Salta questa") { next() }
            }
            .font(.subheadline).foregroundStyle(Palette.muted)

            Text("\(index + 1) / \(views.count) — \(current.title.uppercased())")
                .font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Palette.muted)
            Text("Le tue foto").font(.display(32)).foregroundStyle(Palette.ink)
            Text(current.guide).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            // Le foto servono a vestire chi usa l'app: niente foto di altri senza consenso
            Text(Self.ownPhotoNotice).font(.caption).multilineTextAlignment(.center).foregroundStyle(Palette.muted)

            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border, style: StrokeStyle(dash: [5])))
                if let preview {
                    Image(decorative: preview, scale: 1).resizable().scaledToFit().padding(12)
                } else if busy {
                    ProgressView()
                } else {
                    Image(systemName: current == .side ? "figure.walk" : "figure.stand")
                        .font(.system(size: 90, weight: .ultraLight)).foregroundStyle(Palette.muted)
                }
            }
            .frame(maxHeight: .infinity)

            if let message = check?.message ?? error {
                Text(message).font(.footnote).foregroundStyle(Palette.danger).multilineTextAlignment(.center)
            }

            if check == .ok {
                primaryButton(busy ? "Salvo…" : "Usa questa foto", action: save)
                secondaryButton("Rifai") { reset() }
            } else {
                HStack(spacing: 12) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        secondaryButton("Scatta") { showCamera = true }
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("Scegli dalla libreria").frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .foregroundStyle(Palette.bg).background(Palette.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(24)
        .background(Palette.bg.ignoresSafeArea())
        .disabled(busy)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let photo = ImagePrep.decodedForAnalysis(data) {
                    await analyze(photo)
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                Task { if let photo = uprightCGImage(image) { await analyze(photo) } }
            }
            .ignoresSafeArea()
        }
    }

    /// photo: già ridotta a 2048 px e dritta (decodedForAnalysis / uprightCGImage).
    private func analyze(_ photo: CGImage) async {
        reset()
        busy = true
        defer { busy = false }
        original = photo
        do {
            let cutout = try await PersonCutout.cutout(photo)
            let pose = try? await BodyPose.detect(photo)
            let people = (try? await PersonCutout.peopleCount(photo)) ?? 1
            preview = cutout.image
            check = BodyPhotosModel.validate(cutout, pose: pose, view: current, people: people)
        } catch CutoutError.noSubject {
            check = .noPerson
        } catch {
            self.error = "Non riesco ad analizzare la foto su questo dispositivo."
        }
    }

    private func save() {
        guard let original, let jpeg = UIImage(cgImage: original).jpegData(compressionQuality: 0.85) else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await profile.saveBodyPhoto(jpeg, view: current)
                next()
            } catch {
                self.error = "Non riesco a salvare la foto: controlla la connessione e riprova."
            }
        }
    }

    private func next() {
        reset()
        if index + 1 < views.count { index += 1 } else { onDone() }
    }

    private func reset() {
        original = nil; preview = nil; check = nil; error = nil
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).frame(maxWidth: .infinity, minHeight: 52) }
            .foregroundStyle(Palette.bg).background(Palette.ink)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).frame(maxWidth: .infinity, minHeight: 52) }
            .foregroundStyle(Palette.ink)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border))
    }
}
