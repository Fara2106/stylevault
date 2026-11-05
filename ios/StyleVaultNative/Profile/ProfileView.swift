import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]

    var body: some View {
        NavigationStack {
            Group {
                if let profile = profiles.first {
                    settings(for: profile)
                } else {
                    Palette.bg
                }
            }
            .background(Palette.bg)
            .navigationTitle(Text("nav.profile"))
        }
        .task { _ = try? ProfileStore.current(in: context) }
    }

    private func settings(for profile: Profile) -> some View {
        Form {
            Section("profile.settings") {
                NavigationLink {
                    CitySearchView(profile: profile)
                } label: {
                    LabeledContent("profile.defaultCity", value: profile.cityName)
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
                    get: { profile.theme }, set: { profile.setTheme($0) }
                )) {
                    Text("profile.themeLight").tag("light")
                    Text("profile.themeDark").tag("dark")
                    Text("profile.themeSystem").tag("system")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("theme-picker")
            }
        }
        .scrollContentBackground(.hidden)
        // Su iPad il contenuto resta centrato e non si allarga su tutto lo schermo.
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }
}
