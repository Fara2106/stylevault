import XCTest
@testable import StyleVaultNative

@MainActor
final class LockWindowPlacementTests: XCTestCase {
    private final class FakeScene {}

    private var made: [ObjectIdentifier] = []
    private var dismissed = 0

    private func makePlacement() -> LockWindowPlacement<FakeScene, Int> {
        LockWindowPlacement(
            make: { [unowned self] scene in made.append(ObjectIdentifier(scene)); return made.count },
            dismiss: { [unowned self] _ in dismissed += 1 }
        )
    }

    func testStessaScenaNonRicrea() {
        let placement = makePlacement()
        let scene = FakeScene()
        placement.attach(to: scene)
        placement.setVisible(true)
        placement.attach(to: scene)
        placement.setVisible(true)
        XCTAssertEqual(made.count, 1)
        XCTAssertEqual(dismissed, 0)
    }

    func testScenaNuovaChiudeLaVecchiaENeCreaUna() {
        let placement = makePlacement()
        let old = FakeScene(), new = FakeScene()
        placement.attach(to: old)
        placement.setVisible(true)
        placement.attach(to: new)
        XCTAssertEqual(dismissed, 1)
        XCTAssertEqual(made, [ObjectIdentifier(old), ObjectIdentifier(new)])
        XCTAssertNotNil(placement.window)
    }

    func testNonVisibileChiude() {
        let placement = makePlacement()
        let scene = FakeScene()
        placement.attach(to: scene)
        placement.setVisible(true)
        placement.setVisible(false)
        XCTAssertEqual(dismissed, 1)
        XCTAssertNil(placement.window)
    }

    func testSenzaScenaNonCreaECreaQuandoArriva() {
        let placement = makePlacement()
        placement.setVisible(true)
        XCTAssertEqual(made.count, 0)
        let scene = FakeScene()
        placement.attach(to: scene)
        XCTAssertEqual(made, [ObjectIdentifier(scene)])
    }
}
