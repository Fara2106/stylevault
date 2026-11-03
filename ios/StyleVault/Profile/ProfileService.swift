import Foundation
import Supabase

/// Foto del corpo nel profilo Supabase. La davanti è reference_photo_path
/// (la usano anche sito, prompt e armocromia); lato e spalle stanno in
/// body_photos. Percorsi univoci <uid>/<uuid>.jpg: lo storage non permette
/// di sovrascrivere un file, la foto vecchia viene cancellata.
@MainActor
final class ProfileService {
    private let client: SupabaseClient
    private let bucket = "profile-photos"

    init(client: SupabaseClient = Supa.client) {
        self.client = client
    }

    private struct Row: Decodable {
        let reference_photo_path: String?
        let body_photos: [String: String]?
    }

    private struct FrontUpdate: Encodable { let reference_photo_path: String }
    private struct BodyUpdate: Encodable { let body_photos: [String: String] }

    private func userId() throws -> UUID {
        guard let id = client.auth.currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        return id
    }

    private func row(_ uid: UUID) async throws -> Row {
        try await client.from("profiles")
            .select("reference_photo_path, body_photos")
            .eq("id", value: uid)
            .single()
            .execute()
            .value
    }

    private func paths(of row: Row) -> [BodyView: String] {
        var paths = [BodyView: String]()
        paths[.front] = row.reference_photo_path
        paths[.side] = row.body_photos?["side"]
        paths[.back] = row.body_photos?["back"]
        return paths
    }

    /// URL firmate (6 giorni, come il sito) delle foto già salvate.
    func loadBodyPhotos() async throws -> [BodyView: URL] {
        let current = try await row(try userId())
        var urls = [BodyView: URL]()
        for (view, path) in paths(of: current) {
            urls[view] = try? await client.storage.from(bucket)
                .createSignedURL(path: path, expiresIn: 60 * 60 * 24 * 6)
        }
        return urls
    }

    func saveBodyPhoto(_ jpeg: Data, view: BodyView) async throws {
        let uid = try userId()
        let path = "\(uid.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        _ = try await client.storage.from(bucket)
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))

        let current = try await row(uid)
        let old = paths(of: current)[view]
        if view == .front {
            try await client.from("profiles").update(FrontUpdate(reference_photo_path: path))
                .eq("id", value: uid).execute()
        } else {
            var body = current.body_photos ?? [:]
            body[view.rawValue] = path
            try await client.from("profiles").update(BodyUpdate(body_photos: body))
                .eq("id", value: uid).execute()
        }
        if let old, old != path {
            _ = try? await client.storage.from(bucket).remove(paths: [old])
        }
    }
}
