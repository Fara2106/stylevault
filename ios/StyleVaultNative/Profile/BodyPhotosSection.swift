import StyleVaultCore
import SwiftData
import SwiftUI

/// "Le tue foto" nel Profilo: tre miniature, ognuna si rifà o si cancella. Servono a vedersi addosso gli outfit.
struct BodyPhotosSection: View {
    @Binding var editing: BodyView?
    @Query private var photos: [BodyPhoto]

    private var byView: [BodyView: BodyPhoto] { BodyPhotoStore.byView(photos) }

    var body: some View {
        Section {
            HStack(spacing: 12) {
                ForEach(BodyView.allCases) { view in tile(view) }
            }
            .padding(.vertical, 4)
        } header: {
            Text("profile.bodyPhotosTitle").foregroundStyle(Palette.muted)
        } footer: {
            Text("profile.bodyPhotosHintWeb").foregroundStyle(Palette.muted)
        }
    }

    private func tile(_ view: BodyView) -> some View {
        Button { editing = view } label: {
            VStack(spacing: 6) {
                // La misura la dà il fondo: una foto in `.fill` allargherebbe il riquadro.
                RoundedRectangle(cornerRadius: 10)
                    .fill(Palette.bg)
                    .aspectRatio(0.72, contentMode: .fit)
                    .overlay {
                        if let photo = byView[view] {
                            ItemPhotoView(data: photo.photo, name: "")
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "camera")
                                Text("profile.bodyPhotoMissing").font(.caption)
                            }
                            .foregroundStyle(Palette.muted)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border))
                Text(LocalizedStringKey(view.labelKey)).font(.caption).foregroundStyle(Palette.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("body-photo-\(view.rawValue)")
    }
}
