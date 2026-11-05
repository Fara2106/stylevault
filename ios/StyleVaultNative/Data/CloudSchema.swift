#if DEBUG
import CoreData
import SwiftData

/// Crea nell'ambiente di sviluppo di iCloud lo schema di tutti i modelli, anche di quelli che non hanno
/// ancora salvato nulla. Va lanciato una volta con `-SVInitCloudSchema` su un dispositivo con iCloud, prima
/// di distribuire lo schema in produzione: TestFlight e App Store usano solo la produzione.
enum CloudSchema {
    static func initialize() {
        do {
            try autoreleasepool {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("schema-\(UUID().uuidString).store")
                let description = NSPersistentStoreDescription(url: url)
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: StoreFactory.containerID)
                description.shouldAddStoreAsynchronously = false
                guard let model = NSManagedObjectModel.makeManagedObjectModel(for: StoreFactory.models) else {
                    print("SCHEMA-ICLOUD: modello non creato")
                    return
                }
                let container = NSPersistentCloudKitContainer(name: "StyleVaultSchema", managedObjectModel: model)
                container.persistentStoreDescriptions = [description]
                container.loadPersistentStores { _, error in
                    if let error { print("SCHEMA-ICLOUD: archivio non aperto: \(error)") }
                }
                try container.initializeCloudKitSchema()
                if let store = container.persistentStoreCoordinator.persistentStores.first {
                    try container.persistentStoreCoordinator.remove(store)
                }
                print("SCHEMA-ICLOUD: fatto, \(model.entities.count) entità")
            }
        } catch {
            print("SCHEMA-ICLOUD: errore: \(error)")
        }
    }
}
#endif
