import StyleVaultCore
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppLock.self) private var lock
    @Query private var profiles: [Profile]
    @State private var editingPhoto: BodyView?
    @AppStorage(TemperatureText.storageKey) private var temperatureUnit = "auto"

    private static var version: String {
        let info = Bundle.main
        let short = info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = info.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = ProfileStore.survivor(of: profiles) {
                    settings(for: profile)
                } else {
                    Palette.bg
                }
            }
            .background(Palette.bg)
            .navigationTitle(Text("nav.profile"))
            // Sul Form e non sulla sezione: lì il foglio si richiude da solo quando il Form ricrea le righe.
            .sheet(item: $editingPhoto) { view in BodyPhotoEditorView(view: view) }
        }
        .task { _ = try? ProfileStore.current(in: context) }
    }

    /// La stagione del menu vale come quella dell'analisi; "Non scelta" la toglie.
    private func chooseSeason(_ id: String) {
        ProfileStore.update(profiles, in: context) { profile in
            profile.updatedAt = .now
            guard !id.isEmpty else {
                profile.armocromia = nil
                return
            }
            let detected = ArmocromiaVerdict.decode(profile.armocromia)?.detected ?? FaceColors()
            profile.armocromia = try? ArmocromiaVerdict(season: id, detected: detected, chosenByHand: true).encoded()
        }
    }

    private func settings(for profile: Profile) -> some View {
        Form {
            BodyPhotosSection(editing: $editingPhoto)
            // Subito qui: l'uscita deve vedersi appena si apre il Profilo, senza scorrere.
            AccountSection()
            Section {
                NavigationLink {
                    CitySearchView { city in
                        ProfileStore.update(profiles, in: context) { $0.apply(city: city) }
                    }
                } label: {
                    LabeledContent("profile.defaultCity") { Text(verbatim: profile.cityName).foregroundStyle(Palette.muted) }
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    LabeledContent("profile.language") { Text("native.language.system") }
                        .foregroundStyle(Palette.ink)
                }
                Picker("profile.theme", selection: Binding(
                    get: { profile.theme },
                    set: { value in ProfileStore.update(profiles, in: context) { $0.setTheme(value) } }
                )) {
                    Text("profile.themeLight").tag("light")
                    Text("profile.themeDark").tag("dark")
                    Text("profile.themeSystem").tag("system")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("theme-picker")
                Toggle("native.lock.toggle", isOn: Binding(
                    get: { lock.isEnabled },
                    set: { value in
                        Task { await lock.setEnabled(value, reason: String(localized: "native.lock.reason")) }
                    }
                ))
                .disabled(!lock.canEnable && !lock.isEnabled)
                .accessibilityIdentifier("lock-toggle")
                Picker("native.units.temperature", selection: $temperatureUnit) {
                    Text("native.units.auto").tag("auto")
                    Text(verbatim: "°C").tag("celsius")
                    Text(verbatim: "°F").tag("fahrenheit")
                }
                .tint(Palette.link)
                .accessibilityIdentifier("profile-temperature")
            } header: {
                Text("profile.settings").foregroundStyle(Palette.muted)
            } footer: {
                Text(lock.canEnable || lock.isEnabled ? "native.lock.footer" : "native.lock.unavailable")
                    .foregroundStyle(Palette.muted)
            }
            Section {
                NavigationLink {
                    ArmocromiaView()
                } label: {
                    Text("armocromia.ui.profileCard")
                }
                .accessibilityIdentifier("profile-armocromia")
                Picker("armocromia.ui.seasonPicker", selection: Binding(
                    get: { ArmocromiaVerdict.decode(profile.armocromia)?.season ?? "" },
                    set: { chooseSeason($0) }
                )) {
                    Text("armocromia.ui.seasonNone").tag("")
                    ForEach(ArmocromiaSeasons.all) { Text(LocalizedStringKey($0.nameKey)).tag($0.id) }
                }
                .tint(Palette.link)
                .accessibilityIdentifier("profile-season")
            }
            Section {
                NavigationLink {
                    StatisticsView()
                } label: {
                    Text("profile.stats")
                }
                .accessibilityIdentifier("profile-stats")
            }
            DataTransferSection()
            Section {
                NavigationLink {
                    FeedbackView()
                } label: {
                    Text("feedback.title")
                }
                .accessibilityIdentifier("profile-feedback")
                NavigationLink { LegalView(kind: .privacy) } label: { Text("native.help.privacy") }
                    .accessibilityIdentifier("profile-privacy")
                NavigationLink { LegalView(kind: .support) } label: { Text("native.help.support") }
                    .accessibilityIdentifier("profile-support")
                NavigationLink { LegalView(kind: .deleteAccount) } label: { Text("native.help.deleteAccount") }
                    .accessibilityIdentifier("profile-delete-help")
                LabeledContent("native.help.version") { Text(verbatim: Self.version).foregroundStyle(Palette.muted) }
                    .accessibilityIdentifier("profile-version")
            } header: {
                Text("native.help.title").foregroundStyle(Palette.muted)
            }
        }
        .scrollContentBackground(.hidden)
        // Su iPad il contenuto resta centrato e non si allarga su tutto lo schermo.
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }
}
