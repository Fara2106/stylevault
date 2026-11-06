import CoreGraphics
import Foundation

public enum BodyPhotoError: Error, Equatable {
    case unreadable
}

public struct BodyPhotoResult: @unchecked Sendable {
    public let check: PhotoCheck
    /// Lo scontorno da mostrare: si vede subito se la persona è stata presa bene.
    public let preview: CGImage?
    /// La foto da salvare, raddrizzata e ridotta. Mai lo scontorno: si rifà su ogni dispositivo.
    public let jpeg: Data?

    public init(check: PhotoCheck, preview: CGImage?, jpeg: Data?) {
        self.check = check
        self.preview = preview
        self.jpeg = jpeg
    }
}

/// Controlla una foto del corpo prima di salvarla. Tutto sul dispositivo.
public enum BodyPhotoAnalyzer {
    public static let photoMaxSide = 2048

    public static func analyze(_ data: Data, view: BodyView) async throws -> BodyPhotoResult {
        guard let jpeg = GarmentImage.prepared(data, maxSide: photoMaxSide),
              let photo = ImagePrep.decodedForAnalysis(jpeg, maxSide: photoMaxSide) else {
            throw BodyPhotoError.unreadable
        }
        do {
            let cutout = try await PersonCutout.cutout(photo)
            let pose = try? await BodyPose.detect(photo)
            let people = (try? await PersonCutout.peopleCount(photo)) ?? 1
            let check = BodyPhotosModel.validate(cutout, pose: pose, view: view, people: people)
            return BodyPhotoResult(check: check, preview: cutout.image, jpeg: check == .ok ? jpeg : nil)
        } catch CutoutError.noSubject {
            return BodyPhotoResult(check: .noPerson, preview: nil, jpeg: nil)
        }
    }
}

public struct AvatarGarment: Sendable {
    public let slot: String
    public let photo: Data
    /// Identifica la foto nella cache: cambia se la foto cambia.
    public let key: String

    public init(slot: String, photo: Data, key: String) {
        self.slot = slot
        self.photo = photo
        self.key = key
    }
}

public enum AvatarError: Error, Equatable {
    case unreadableBody, noPose
}

public struct AvatarResult: @unchecked Sendable {
    public let image: CGImage
    /// Capi che non si sono potuti scontornare: l'avatar esce lo stesso, senza di loro.
    public let unavailable: Int

    public init(image: CGImage, unavailable: Int) {
        self.image = image
        self.unavailable = unavailable
    }
}

/// Una vista dell'avatar a partire dai dati salvati.
public enum AvatarRenderer {
    /// La persona occupa spesso una parte piccola della foto: si ritaglia attorno a lei, tenendo un po' di fondo.
    static func cropped(_ image: CGImage, around body: CGRect) -> CGImage {
        let margin = body.height * 0.08
        let height = body.height + 2 * margin
        let width = max(body.width + 2 * margin, height * 0.62)
        let frame = CGRect(x: body.midX - width / 2, y: body.minY - margin, width: width, height: height)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return image.cropping(to: frame.integral) ?? image
    }

    public static func render(body: Data, bodyKey: String, garments: [AvatarGarment], view: BodyView,
                              cache: CutoutCache = .shared) async throws -> AvatarResult {
        guard let photo = ImagePrep.decodedForAnalysis(body) else { throw AvatarError.unreadableBody }
        let person = try await cache.cutout(image: photo, key: bodyKey, allInstances: false)
        guard let pose = try await BodyPose.detect(person.image) else { throw AvatarError.noPose }
        var pieces: [AvatarComposer.Garment] = []
        var unavailable = 0
        for garment in garments {
            guard let image = ImagePrep.decodedForAnalysis(garment.photo),
                  let cutout = try? await cache.cutout(image: image, key: garment.key, allInstances: true) else {
                unavailable += 1
                continue
            }
            pieces.append(AvatarComposer.Garment(slot: garment.slot, cutout: cutout))
        }
        guard let image = AvatarComposer.render(person: person, pose: pose, garments: pieces, view: view) else {
            throw AvatarError.noPose
        }
        return AvatarResult(image: cropped(image, around: person.bounds), unavailable: unavailable)
    }
}
