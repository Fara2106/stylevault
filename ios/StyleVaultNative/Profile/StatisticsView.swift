import StyleVaultCore
import SwiftData
import SwiftUI

/// Le statistiche del guardaroba.
struct StatisticsView: View {
    @Query(sort: \Item.createdAt) private var items: [Item]
    @Query private var entries: [CalendarEntry]
    @Query private var customCategories: [CustomCategory]

    private var pieces: [OutfitPiece] { items.map(\.piece) }
    private var history: [WearLog] { entries.map(\.wearLog) }
    private var hasWearData: Bool { entries.contains(where: \.worn) }

    private func item(_ piece: OutfitPiece) -> Item? { items.first { $0.id.uuidString == piece.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if items.isEmpty, !hasWearData {
                    noData
                } else {
                    categories
                    colors
                    if hasWearData {
                        wearList("profile.statsMostWorn", WardrobeStatistics.mostWorn(pieces, history).map { ($0.item, wears($0.count)) })
                        wearList("profile.statsLeastWorn", WardrobeStatistics.leastWorn(pieces, history).map {
                            ($0.item, $0.count == 0 ? Text("profile.statsNever") : wears($0.count))
                        })
                        wearList("profile.statsCostPerWear", WardrobeStatistics.costPerWear(pieces, history).map {
                            ($0.item, Text($0.costPerWear, format: .currency(code: "EUR")) + Text(verbatim: " · ") + wears($0.count))
                        })
                    } else {
                        noData
                    }
                }
                Text("profile.totalOutfits").font(.footnote).foregroundStyle(Palette.muted)
                    + Text(verbatim: ": \(entries.filter(\.worn).count)").font(.footnote).foregroundStyle(Palette.ink)
            }
            .padding(16)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg)
        .navigationTitle(Text("profile.stats"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var noData: some View {
        Text("profile.statsNoData").font(.footnote).foregroundStyle(Palette.muted)
            .accessibilityIdentifier("stats-no-data")
    }

    private func wears(_ count: Int) -> Text { Text("profile.statsWears \(count)") }

    private func heading(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
    }

    @ViewBuilder private var categories: some View {
        let rows = WardrobeStatistics.categoryBreakdown(pieces)
        if let largest = rows.map(\.count).max() {
            VStack(alignment: .leading, spacing: 8) {
                heading("profile.statsByCategory")
                ForEach(rows) { row in
                    HStack(spacing: 8) {
                        (CategoryChoice.find(row.key, custom: customCategories)?.text ?? Text(verbatim: row.key))
                            .font(.footnote)
                            .foregroundStyle(Palette.ink)
                            .frame(width: 110, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geometry in
                            Capsule().fill(Palette.ink)
                                .frame(width: geometry.size.width * CGFloat(row.count) / CGFloat(largest))
                        }
                        .frame(height: 6)
                        Text(verbatim: "\(row.count)").font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
            }
            .accessibilityIdentifier("stats-categories")
        }
    }

    @ViewBuilder private var colors: some View {
        let rows = WardrobeStatistics.colorBreakdown(pieces)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                heading("profile.statsByColor")
                FlowLayout(spacing: 10) {
                    ForEach(rows) { row in
                        if let color = Catalog.color(id: row.key) {
                            HStack(spacing: 6) {
                                ColorDot(color: color.color, size: 12)
                                Text(LocalizedStringKey(color.labelKey)) + Text(verbatim: " · \(row.count)")
                            }
                            .font(.footnote)
                            .foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func wearList(_ title: LocalizedStringKey, _ rows: [(OutfitPiece, Text)]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                heading(title)
                ForEach(rows, id: \.0.id) { piece, detail in
                    if let item = item(piece) {
                        NavigationLink {
                            ItemDetailView(itemID: item.id)
                        } label: {
                            HStack(spacing: 10) {
                                ItemPhotoView(data: item.photoFront, name: item.name)
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(verbatim: item.name).font(.subheadline).foregroundStyle(Palette.ink).lineLimit(1)
                                Spacer()
                                detail.font(.footnote).foregroundStyle(Palette.muted)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("stats-item")
                    }
                }
            }
        }
    }
}
