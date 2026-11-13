import CoreGraphics
import Foundation
import StyleVaultCore
import SwiftUI

protocol BodyPhotoAnalyzing: Sendable {
    func analyze(_ data: Data, view: BodyView) async throws -> BodyPhotoResult
}

protocol AvatarRendering: Sendable {
    func render(body: Data, bodyKey: String, garments: [AvatarGarment], view: BodyView) async throws -> AvatarResult
}

struct SystemBodyPhotoAnalyzer: BodyPhotoAnalyzing {
    func analyze(_ data: Data, view: BodyView) async throws -> BodyPhotoResult {
        try await BodyPhotoAnalyzer.analyze(data, view: view)
    }
}

struct SystemAvatarRenderer: AvatarRendering {
    func render(body: Data, bodyKey: String, garments: [AvatarGarment], view: BodyView) async throws -> AvatarResult {
        try await AvatarRenderer.render(body: body, bodyKey: bodyKey, garments: garments, view: view)
    }
}

#if DEBUG
/// Vision non gira nel simulatore iOS 27: per i test UI, solo con `-SVFakeBody`.
struct FakeBodyAnalyzer: BodyPhotoAnalyzing {
    func analyze(_ data: Data, view: BodyView) async throws -> BodyPhotoResult {
        BodyPhotoResult(check: .ok, preview: ImagePrep.decodedForAnalysis(data), jpeg: GarmentImage.prepared(data))
    }
}

struct FakeAvatarRenderer: AvatarRendering {
    private struct NotAPhoto: Error {}

    func render(body: Data, bodyKey: String, garments: [AvatarGarment], view: BodyView) async throws -> AvatarResult {
        guard let image = ImagePrep.decodedForAnalysis(body) else { throw NotAPhoto() }
        return AvatarResult(image: image, unavailable: 0)
    }
}
#endif

private struct BodyPhotoAnalyzerKey: EnvironmentKey {
    static let defaultValue: any BodyPhotoAnalyzing = SystemBodyPhotoAnalyzer()
}

private struct AvatarRendererKey: EnvironmentKey {
    static let defaultValue: any AvatarRendering = SystemAvatarRenderer()
}

extension EnvironmentValues {
    var bodyPhotoAnalyzer: any BodyPhotoAnalyzing {
        get { self[BodyPhotoAnalyzerKey.self] }
        set { self[BodyPhotoAnalyzerKey.self] = newValue }
    }

    var avatarRenderer: any AvatarRendering {
        get { self[AvatarRendererKey.self] }
        set { self[AvatarRendererKey.self] = newValue }
    }
}
