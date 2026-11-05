import StyleVaultCore
import SwiftUI

struct CitySearchView: View {
    let onPick: (City) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var model = CitySearchModel(search: { query in
        try await CitySearch.search(query, language: Bundle.main.preferredLocalizations.first ?? "it")
    })

    var body: some View {
        List {
            switch model.phase {
            case .idle:
                EmptyView()
            case .searching:
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            case .empty:
                Text("native.city.none").foregroundStyle(Palette.muted)
            case .results(let cities):
                ForEach(cities) { city in
                    Button {
                        onPick(city)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.name).foregroundStyle(Palette.ink)
                            if let detail = detail(of: city) {
                                Text(detail).font(.footnote).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(Text("profile.defaultCity"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text("native.city.search"))
        .task(id: query) {
            // Aspetta che si smetta di scrivere: `.task(id:)` annulla quella precedente.
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            await model.run(query: query)
        }
    }

    private func detail(of city: City) -> String? {
        let parts = [city.region, city.country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
