import Foundation
import LinkPresentation
import StyleVaultCore
import SwiftUI
import UniformTypeIdentifiers

struct LinkPreview: Equatable, Sendable {
    var title: String
    var site: String
    var imageData: Data?
}

enum LinkReadError: Error { case unreadable }

protocol LinkReading: Sendable {
    @MainActor func read(_ url: URL) async throws -> LinkPreview
}

/// Legge la pagina del negozio sul telefono: nessun server di mezzo.
struct SystemLinkReader: LinkReading {
    @MainActor func read(_ url: URL) async throws -> LinkPreview {
        let provider = LPMetadataProvider()
        provider.timeout = 15
        let metadata: LPLinkMetadata
        do {
            metadata = try await provider.startFetchingMetadata(for: url)
        } catch {
            throw LinkReadError.unreadable
        }
        // Mai `iconProvider`: un logo come foto del capo è peggio di nessuna foto.
        let imageData = await Self.data(from: metadata.imageProvider)
        return try Self.preview(title: metadata.title, host: url.host ?? "", imageData: imageData)
    }

    static func preview(title: String?, host: String, imageData: Data?) throws -> LinkPreview {
        let raw = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !LinkText.isBlockedTitle(raw), !raw.isEmpty || imageData != nil else { throw LinkReadError.unreadable }
        let site = LinkText.siteName(host: host)
        return LinkPreview(title: LinkText.stripShopSuffix(raw, site: site), site: site, imageData: imageData)
    }

    @MainActor private static func data(from provider: NSItemProvider?) async -> Data? {
        guard let provider else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: .image) { data, _ in continuation.resume(returning: data) }
        }
    }
}

#if DEBUG
/// Per i test UI: nessuna rete.
struct FakeLinkReader: LinkReading {
    @MainActor func read(_ url: URL) async throws -> LinkPreview {
        LinkPreview(title: "Camicia in lino", site: "Zara", imageData: nil)
    }
}
#endif

private struct LinkReaderKey: EnvironmentKey {
    static let defaultValue: any LinkReading = SystemLinkReader()
}

extension EnvironmentValues {
    var linkReader: any LinkReading {
        get { self[LinkReaderKey.self] }
        set { self[LinkReaderKey.self] = newValue }
    }
}
