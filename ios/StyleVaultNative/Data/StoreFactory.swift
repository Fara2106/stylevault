import Foundation
import SwiftData

enum StoreMode { case cloud, local, memory }

enum StoreHealth: Equatable { case cloud, localOnly, temporary }

struct OpenedStore {
    let container: ModelContainer
    let health: StoreHealth
}

enum StoreFactory {
    static let containerID = "iCloud.it.faraoni.stylevault"

    static let schema = Schema([
        Item.self, Outfit.self, CalendarEntry.self,
        WishlistItem.self, Profile.self, BodyPhoto.self,
        CustomCategory.self,
    ])

    static func build(_ mode: StoreMode, url: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        switch mode {
        case .cloud:
            configuration = try makeConfiguration(url: url, cloud: .private(containerID))
        case .local:
            // Stesso nome e stesso file del cloud: i dati già salvati restano.
            configuration = try makeConfiguration(url: url, cloud: .none)
        case .memory:
            configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private static func makeConfiguration(url: URL?, cloud: ModelConfiguration.CloudKitDatabase) throws -> ModelConfiguration {
        if let url {
            return ModelConfiguration("StyleVault", schema: schema, url: url, cloudKitDatabase: cloud)
        }
        return ModelConfiguration("StyleVault", schema: schema, cloudKitDatabase: cloud)
    }

    /// Prova il cloud, poi il disco locale, poi la memoria: l'app parte sempre.
    static func open(
        preferred: StoreMode = .cloud,
        build: (StoreMode) throws -> ModelContainer = { try StoreFactory.build($0) }
    ) -> OpenedStore {
        let order: [StoreMode] = [preferred, .local, .memory]
        var tried: [StoreMode] = []
        for mode in order where !tried.contains(mode) {
            tried.append(mode)
            if let container = try? build(mode) {
                switch mode {
                case .cloud: return OpenedStore(container: container, health: .cloud)
                case .local: return OpenedStore(container: container, health: .localOnly)
                case .memory: return OpenedStore(container: container, health: .temporary)
                }
            }
        }
        fatalError("Impossibile aprire anche l'archivio in memoria")
    }
}
