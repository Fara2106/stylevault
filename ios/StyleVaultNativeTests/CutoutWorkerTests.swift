import XCTest
import SwiftData
@testable import StyleVaultNative

/// Scontorno finto: conta le chiamate e, se serve, resta sospeso finché il test non lo sblocca.
private actor FakeCut {
    private(set) var calls = 0
    private(set) var maxRunning = 0
    private var running = 0
    private var held: [CheckedContinuation<Void, Never>] = []
    private var isHolding: Bool
    private let result: Data?

    init(result: Data?, holding: Bool = false) {
        self.result = result
        isHolding = holding
    }

    func run() async -> Data? {
        calls += 1
        running += 1
        maxRunning = max(maxRunning, running)
        if isHolding { await withCheckedContinuation { held.append($0) } }
        await Task.yield()
        running -= 1
        return result
    }

    func release() {
        isHolding = false
        held.forEach { $0.resume() }
        held = []
    }

    var waiting: Int { held.count }
}

@MainActor final class CutoutWorkerTests: XCTestCase {
    private var container: ModelContainer?

    private func context() throws -> ModelContext {
        let built = try StoreFactory.build(.memory)
        container = built
        return built.mainContext
    }

    private func addItem(_ c: ModelContext, photo: Data? = Data([1])) throws -> Item {
        var v = ItemValues()
        v.name = "Capo"; v.category = "tops"; v.photoFront = photo
        return try WardrobeStore.addItem(v, in: c)
    }

    private func worker(_ c: ModelContext, _ fake: FakeCut) -> CutoutWorker {
        CutoutWorker(context: c, cut: { _ in await fake.run() })
    }

    private func waitUntilHeld(_ fake: FakeCut) async {
        while await fake.waiting == 0 { await Task.yield() }
    }

    func testScriveLoScontornoSulCapo() async throws {
        let c = try context()
        let item = try addItem(c)
        let w = worker(c, FakeCut(result: Data([7])))
        w.enqueue(item.id)
        await w.waitUntilIdle()
        XCTAssertEqual(item.cutout, Data([7]))
        XCTAssertFalse(c.hasChanges, "deve aver salvato")
    }

    func testRisultatoInRitardoNonFiniscePiuSullaFotoNuova() async throws {
        let c = try context()
        let item = try addItem(c)
        let fake = FakeCut(result: Data([7]), holding: true)
        let w = worker(c, fake)
        w.enqueue(item.id)
        await waitUntilHeld(fake)
        item.photoFront = Data([2])
        try c.save()
        await fake.release()
        await w.waitUntilIdle()
        XCTAssertNil(item.cutout)
    }

    func testCapoCancellatoMentreSiScontorna() async throws {
        let c = try context()
        let item = try addItem(c)
        let fake = FakeCut(result: Data([7]), holding: true)
        let w = worker(c, fake)
        w.enqueue(item.id)
        await waitUntilHeld(fake)
        try WardrobeStore.delete(item, in: c)
        await fake.release()
        await w.waitUntilIdle()
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<Item>()), 0)
    }

    func testCapoSenzaFotoNonChiamaCut() async throws {
        let c = try context()
        let item = try addItem(c, photo: nil)
        let fake = FakeCut(result: Data([7]))
        let w = worker(c, fake)
        w.enqueue(item.id)
        await w.waitUntilIdle()
        let calls = await fake.calls
        XCTAssertEqual(calls, 0)
    }

    func testUnoAllaVolta() async throws {
        let c = try context()
        let fake = FakeCut(result: Data([7]))
        let w = worker(c, fake)
        for _ in 0..<3 { w.enqueue(try addItem(c).id) }
        await w.waitUntilIdle()
        let (calls, maxRunning) = (await fake.calls, await fake.maxRunning)
        XCTAssertEqual(calls, 3)
        XCTAssertEqual(maxRunning, 1)
    }

    func testScontornoFallitoLasciaIlCapoIntatto() async throws {
        let c = try context()
        let item = try addItem(c)
        let w = worker(c, FakeCut(result: nil))
        w.enqueue(item.id)
        await w.waitUntilIdle()
        XCTAssertNil(item.cutout)
        XCTAssertEqual(item.photoFront, Data([1]))
    }

    func testStessoCapoAccodatoDueVolteUnaSolaVolta() async throws {
        let c = try context()
        let item = try addItem(c)
        let fake = FakeCut(result: Data([7]))
        let w = worker(c, fake)
        w.enqueue(item.id)
        w.enqueue(item.id)
        await w.waitUntilIdle()
        let calls = await fake.calls
        XCTAssertEqual(calls, 1)
    }

    // MARK: Capi rimasti senza scontorno

    func testRecuperaICapiSenzaScontorno() async throws {
        let c = try context()
        let missing = try addItem(c)
        let done = try addItem(c)
        done.cutout = Data([9])
        _ = try addItem(c, photo: nil)
        try c.save()
        let fake = FakeCut(result: Data([7]))
        let w = worker(c, fake)
        w.enqueueMissing()
        await w.waitUntilIdle()
        let calls = await fake.calls
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(missing.cutout, Data([7]))
        XCTAssertEqual(done.cutout, Data([9]))
    }

    func testNonRiprovaNellaStessaSessioneUnoScontornoFallito() async throws {
        let c = try context()
        _ = try addItem(c)
        let fake = FakeCut(result: nil)
        let w = worker(c, fake)
        w.enqueueMissing()
        await w.waitUntilIdle()
        w.enqueueMissing()
        await w.waitUntilIdle()
        let calls = await fake.calls
        XCTAssertEqual(calls, 1)
    }

    func testFotoCambiataRiprovaAncheDopoUnFallimento() async throws {
        let c = try context()
        let item = try addItem(c)
        let fake = FakeCut(result: nil)
        let w = worker(c, fake)
        w.enqueueMissing()
        await w.waitUntilIdle()
        w.enqueue(item.id)
        await w.waitUntilIdle()
        let calls = await fake.calls
        XCTAssertEqual(calls, 2)
    }

    // MARK: Foto mostrata

    func testSiVedeLoScontornoQuandoCe() throws {
        let c = try context()
        let item = try addItem(c)
        XCTAssertEqual(item.shownPhoto, Data([1]))
        item.cutout = Data([7])
        XCTAssertEqual(item.shownPhoto, Data([7]))
    }
}
