import StyleVaultCore
import SwiftData
import SwiftUI

/// Due passi al primo avvio: la tua foto e la tua città. Si può saltare tutto.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @Query private var photos: [BodyPhoto]
    @State private var step = 0
    @State private var editing: BodyView?
    @State private var isCityOpen = false

    private var frontPhoto: Data? { BodyPhotoStore.byView(photos)[.front]?.photo }
    private var city: String { ProfileStore.survivor(of: profiles)?.cityName ?? "" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(verbatim: "\(step + 1) / 2 — \(localized(step == 0 ? "onboarding.stepPhoto" : "onboarding.stepCity"))")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("onboarding-step")
                    Text("onboarding.welcomeNeutral").font(.display(30)).foregroundStyle(Palette.ink)
                    if step == 0 { photoStep } else { cityStep }
                }
                .padding(24)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.bg)
            .safeAreaInset(edge: .bottom) { actions }
            .navigationDestination(isPresented: $isCityOpen) {
                CitySearchView { picked in
                    ProfileStore.update(profiles, in: context) { $0.apply(city: picked) }
                }
            }
        }
        .tint(Palette.ink)
        .sheet(item: $editing) { view in BodyPhotoEditorView(view: view) }
    }

    private var photoStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("native.onboarding.photoHint").foregroundStyle(Palette.ink)
            Text("profile.ownPhotoNotice").font(.footnote).foregroundStyle(Palette.muted)
                .accessibilityIdentifier("onboarding-notice")
            if let frontPhoto {
                ItemPhotoView(data: frontPhoto, name: "", contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .accessibilityIdentifier("onboarding-preview")
            }
            Button { editing = .front } label: {
                SecondaryLabel(frontPhoto == nil ? "native.onboarding.addPhoto" : "native.onboarding.changePhoto")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding-photo")
        }
    }

    private var cityStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("onboarding.stepCityHint").foregroundStyle(Palette.ink)
            Button { isCityOpen = true } label: {
                HStack {
                    Text(verbatim: city).foregroundStyle(Palette.ink)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding-city")
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                if step == 0 { step = 1 } else { onFinish() }
            } label: {
                PrimaryLabel(step == 0 ? "native.onboarding.next" : "onboarding.finish")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding-next")
            Button("onboarding.later", action: onFinish)
                .font(.subheadline)
                .tint(Palette.link)
                .frame(minHeight: 44)
                .accessibilityIdentifier("onboarding-later")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Palette.bg)
    }
}
