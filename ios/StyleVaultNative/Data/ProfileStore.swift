import Foundation
import OSLog
import SwiftData

/// CloudKit non ha vincoli `unique`: due dispositivi possono creare ognuno un `Profile`.
/// Questo tiene il Profilo a un record solo.
@MainActor enum ProfileStore {
    /// Il Profilo da usare. Lo crea al primo avvio; se ne trova più di uno, tiene il
    /// sopravvissuto (conservando l'armocromia) e cancella gli altri.
    @discardableResult
    static func current(in context: ModelContext) throws -> Profile {
        let all = try context.fetch(FetchDescriptor<Profile>())
        guard let keeper = survivor(of: all) else {
            let profile = Profile()
            // Mai modificato: perde sempre contro un Profilo vero che iCloud consegna dopo.
            // Epoca e non `.distantPast`, per restare in un intervallo di date sicuro per CloudKit.
            profile.updatedAt = Date(timeIntervalSince1970: 0)
            context.insert(profile)
            try context.save()
            return profile
        }
        let others = all.filter { $0 !== keeper }
        guard !others.isEmpty else { return keeper }
        if keeper.armocromia == nil {
            keeper.armocromia = others
                .filter { $0.armocromia != nil }
                .max(by: { isOlder($0, than: $1) })?.armocromia
        }
        others.forEach(context.delete)
        try context.save()
        return keeper
    }

    private static let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "profile")

    /// Applica `change` al Profilo che sopravvive all'unione e salva. Le viste passano da qui,
    /// così scrivono sempre sul record che resta e non su uno che l'unione cancellerà.
    static func update(_ profiles: [Profile], in context: ModelContext, _ change: (Profile) -> Void) {
        guard let keeper = survivor(of: profiles) else { return }
        change(keeper)
        do { try context.save() } catch { logger.error("Salvataggio del Profilo non riuscito: \(error)") }
    }

    /// Il più recente per `updatedAt`; a parità il maggiore per `id.uuidString`,
    /// così ogni dispositivo sceglie lo stesso record.
    static func survivor(of profiles: [Profile]) -> Profile? {
        profiles.max(by: isOlder)
    }

    private static func isOlder(_ a: Profile, than b: Profile) -> Bool {
        a.updatedAt != b.updatedAt ? a.updatedAt < b.updatedAt : a.id.uuidString < b.id.uuidString
    }
}
