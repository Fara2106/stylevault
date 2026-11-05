import Foundation
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

    /// Il più recente per `updatedAt`; a parità il maggiore per `id.uuidString`,
    /// così ogni dispositivo sceglie lo stesso record.
    static func survivor(of profiles: [Profile]) -> Profile? {
        profiles.max(by: isOlder)
    }

    private static func isOlder(_ a: Profile, than b: Profile) -> Bool {
        a.updatedAt != b.updatedAt ? a.updatedAt < b.updatedAt : a.id.uuidString < b.id.uuidString
    }
}
