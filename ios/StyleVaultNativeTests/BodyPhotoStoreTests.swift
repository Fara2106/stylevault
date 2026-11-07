import StyleVaultCore
import SwiftData
import XCTest
@testable import StyleVaultNative

@MainActor final class BodyPhotoStoreTests: XCTestCase {
    private var container: ModelContainer?

    private func context() throws -> ModelContext {
        let built = try StoreFactory.build(.memory)
        container = built
        return built.mainContext
    }

    private func photos(_ c: ModelContext) throws -> [BodyPhoto] { try c.fetch(FetchDescriptor<BodyPhoto>()) }

    func testSalvaUnaFotoPerVista() throws {
        let c = try context()
        try BodyPhotoStore.save(Data([1]), view: .front, in: c)
        try BodyPhotoStore.save(Data([2]), view: .side, in: c)
        let found = BodyPhotoStore.byView(try photos(c))
        XCTAssertEqual(found[.front]?.photo, Data([1]))
        XCTAssertEqual(found[.side]?.photo, Data([2]))
        XCTAssertNil(found[.back])
    }

    func testRifareUnaFotoLaSostituisce() throws {
        let c = try context()
        try BodyPhotoStore.save(Data([1]), view: .front, in: c)
        try BodyPhotoStore.save(Data([2]), view: .front, in: c)
        XCTAssertEqual(try photos(c).count, 1)
        XCTAssertEqual(try photos(c).first?.photo, Data([2]))
    }

    /// Due dispositivi possono scattare la stessa vista prima di sincronizzarsi.
    func testIDoppioniDaiCloudSiRisolvonoAlSalvataggio() throws {
        let c = try context()
        for byte in [UInt8(1), 2] {
            let photo = BodyPhoto()
            photo.kind = "front"
            photo.photo = Data([byte])
            c.insert(photo)
        }
        try c.save()
        try BodyPhotoStore.save(Data([3]), view: .front, in: c)
        XCTAssertEqual(try photos(c).map(\.photo), [Data([3])])
    }

    func testTraIDoppioniVinceLaPiuRecente() throws {
        let old = BodyPhoto()
        old.updatedAt = .distantPast
        old.photo = Data([1])
        let new = BodyPhoto()
        new.updatedAt = .now
        new.photo = Data([2])
        XCTAssertEqual(BodyPhotoStore.byView([old, new])[.front]?.photo, Data([2]))
        XCTAssertEqual(BodyPhotoStore.byView([new, old])[.front]?.photo, Data([2]))
    }

    func testCancellaTuttiIDoppioniDellaVista() throws {
        let c = try context()
        try BodyPhotoStore.save(Data([1]), view: .front, in: c)
        try BodyPhotoStore.save(Data([2]), view: .back, in: c)
        try BodyPhotoStore.delete(.front, in: c)
        XCTAssertEqual(try photos(c).map(\.kind), ["back"])
    }

    func testLaChiaveCambiaSeCambiaLaFoto() throws {
        let c = try context()
        try BodyPhotoStore.save(Data([1]), view: .front, in: c)
        let photo = try XCTUnwrap(try photos(c).first)
        let before = BodyPhotoStore.key(of: photo)
        XCTAssertTrue(before.hasPrefix("body-front-"))
        photo.updatedAt = photo.updatedAt.addingTimeInterval(10)
        XCTAssertNotEqual(BodyPhotoStore.key(of: photo), before)
    }

    func testDiSpalleUsaIlRetroSeCe() {
        let item = Item()
        item.photoFront = Data([1])
        item.photoBack = Data([2])
        let outfit = GeneratedOutfit(top: OutfitPiece(id: item.id.uuidString, category: "tops"))
        let items = [item.id.uuidString: item]
        XCTAssertEqual(AvatarRequest.make(.from(outfit, items: items), view: .front).garments.first?.photo, Data([1]))
        XCTAssertEqual(AvatarRequest.make(.from(outfit, items: items), view: .back).garments.first?.photo, Data([2]))
    }

    func testDiSpalleSenzaRetroUsaIlDavanti() {
        let item = Item()
        item.photoFront = Data([1])
        let outfit = GeneratedOutfit(top: OutfitPiece(id: item.id.uuidString, category: "tops"))
        XCTAssertEqual(AvatarRequest.make(.from(outfit, items: [item.id.uuidString: item]), view: .back).garments.first?.photo, Data([1]))
    }

    func testLaStessaFotoSiScontornaUnaVoltaSola() {
        let item = Item()
        item.photoFront = Data([1])
        let outfit = GeneratedOutfit(top: OutfitPiece(id: item.id.uuidString, category: "tops"))
        let items = [item.id.uuidString: item]
        let keys = [BodyView.front, .side, .back].compactMap { AvatarRequest.make(.from(outfit, items: items), view: $0).garments.first?.key }
        XCTAssertEqual(Set(keys).count, 1)
        item.photoBack = Data([2])
        let front = AvatarRequest.make(.from(outfit, items: items), view: .front).garments.first?.key
        let back = AvatarRequest.make(.from(outfit, items: items), view: .back).garments.first?.key
        XCTAssertNotEqual(front, back)
    }

    func testCapoSenzaFotoVieneContato() {
        let item = Item()
        let outfit = GeneratedOutfit(top: OutfitPiece(id: item.id.uuidString, category: "tops"))
        let request = AvatarRequest.make(.from(outfit, items: [item.id.uuidString: item]), view: .front)
        XCTAssertTrue(request.garments.isEmpty)
        XCTAssertEqual(request.withoutPhoto, 1)
    }
}
