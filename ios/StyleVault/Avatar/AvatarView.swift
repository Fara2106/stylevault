import SwiftUI

/// L'avatar: tu, scontornato da iOS, coi capi scelti addosso. Si scorre col
/// dito tra davanti, lato e spalle.
struct AvatarView: View {
    let request: AvatarRequest
    let onClose: () -> Void

    @State private var images = [BodyView: CGImage]()
    @State private var missingBodyViews = [BodyView]()
    @State private var unavailable = 0
    @State private var loading = true
    @State private var failure: String?
    @State private var selection: BodyView = .front

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Vedilo addosso").font(.display(24)).foregroundStyle(Palette.ink)
                Spacer()
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
            }
        }
        .padding(20)
        .background(Palette.bg.ignoresSafeArea())
        .task { await build() }
    }

    @ViewBuilder private func page(_ view: BodyView) -> some View {
        if let image = images[view] {
            Image(decorative: image, scale: 1).resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14))
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

    private func build() async {
        defer { loading = false }
        guard let photos = try? await ProfileService().loadBodyPhotos(), !photos.isEmpty else {
            failure = "Non trovo le tue foto: falle dal Profilo con \"Rifai le foto del corpo\"."
            return
        }
        missingBodyViews = BodyView.allCases.filter { photos[$0] == nil }
        var failedItems = Set<String>()
        for view in BodyView.allCases {
            guard let url = photos[view],
                  let person = try? await CutoutCache.shared.cutout(
                      for: url, key: CutoutCache.key("body-\(view.rawValue)", url), allInstances: false),
                  let pose = try? await BodyPose.detect(person.image) else { continue }
            var garments = [AvatarComposer.Garment]()
            for item in request.items {
                guard let garmentURL = AvatarModel.garmentImageURL(item, view: view),
                      let cutout = try? await CutoutCache.shared.cutout(
                          for: garmentURL, key: CutoutCache.key("item-\(item.id)", garmentURL), allInstances: true)
                else { failedItems.insert(item.id); continue }
                garments.append(.init(slot: item.slot, cutout: cutout))
            }
            images[view] = AvatarComposer.render(person: person, pose: pose, garments: garments, view: view)
        }
        unavailable = failedItems.count
        if images.isEmpty, failure == nil {
            failure = "Non riesco a preparare l'avatar su questo dispositivo."
        }
    }
}
