import SwiftUI
import XCTest
@testable import StyleVaultNative

@MainActor
fileprivate final class FakeAuthenticator: DeviceAuthenticating {
    var isAvailable = true
    var outcome: AuthOutcome = .success
    /// Se vero, `authenticate` resta sospesa finché il test non chiama `release()`.
    var holds = false
    private(set) var calls = 0
    private var pending: CheckedContinuation<Void, Never>?

    func authenticate(reason: String) async -> AuthOutcome {
        calls += 1
        if holds { await withCheckedContinuation { pending = $0 } }
        return outcome
    }

    func release() { pending?.resume(); pending = nil }
}

@MainActor
final class AppLockTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!
    private var auth: FakeAuthenticator!

    override func setUp() {
        suite = "AppLockTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        auth = FakeAuthenticator()
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    private func makeLock() -> AppLock { AppLock(defaults: defaults, authenticator: auth) }

    private func enabledLock() async -> AppLock {
        let lock = makeLock()
        await lock.setEnabled(true, reason: "r")
        return lock
    }

    func testSpentoNonBlocca() {
        let lock = makeLock()
        XCTAssertFalse(lock.isEnabled)
        XCTAssertFalse(lock.isLocked)
        lock.sceneDidChange(to: .background)
        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(lock.isObscured)
    }

    func testAttivoBloccaAllAvvio() {
        defaults.set(true, forKey: "native.lock.enabled")
        let lock = makeLock()
        XCTAssertTrue(lock.isEnabled)
        XCTAssertTrue(lock.isLocked)
    }

    func testAttivareRichiedeAutenticazione() async {
        let lock = makeLock()
        await lock.setEnabled(true, reason: "r")
        XCTAssertEqual(auth.calls, 1)
        XCTAssertTrue(lock.isEnabled)
        XCTAssertFalse(lock.isLocked, "Appena autenticata, la persona non deve vedere subito il blocco")
    }

    func testAttivareFallitoRestaSpento() async {
        auth.outcome = .failed
        let lock = makeLock()
        await lock.setEnabled(true, reason: "r")
        XCTAssertFalse(lock.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: "native.lock.enabled"))
    }

    func testAttivareSenzaCodiceRestaSpento() async {
        auth.isAvailable = false
        auth.outcome = .unavailable
        let lock = makeLock()
        XCTAssertFalse(lock.canEnable)
        await lock.setEnabled(true, reason: "r")
        XCTAssertFalse(lock.isEnabled)
    }

    func testDisattivareRichiedeAutenticazione() async {
        let lock = await enabledLock()
        auth.outcome = .failed
        await lock.setEnabled(false, reason: "r")
        XCTAssertTrue(lock.isEnabled, "Se l'autenticazione fallisce il valore resta com'era")
        auth.outcome = .success
        await lock.setEnabled(false, reason: "r")
        XCTAssertFalse(lock.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: "native.lock.enabled"))
        XCTAssertEqual(auth.calls, 3)
    }

    func testInattivoNonBloccaMaCopre() async {
        let lock = await enabledLock()
        lock.sceneDidChange(to: .inactive)
        XCTAssertFalse(lock.isLocked)
        XCTAssertTrue(lock.isObscured)
        lock.sceneDidChange(to: .active)
        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(lock.isObscured)
    }

    func testBackgroundBlocca() async {
        let lock = await enabledLock()
        lock.sceneDidChange(to: .background)
        XCTAssertTrue(lock.isLocked)
        XCTAssertTrue(lock.isObscured)
    }

    func testUnlockRiuscitoSblocca() async {
        let lock = await enabledLock()
        lock.sceneDidChange(to: .background)
        lock.sceneDidChange(to: .active)
        await lock.unlock(reason: "r")
        XCTAssertFalse(lock.isLocked)
        XCTAssertTrue(lock.isEnabled)
    }

    func testAnnullareLasciaBloccato() async {
        let lock = await enabledLock()
        lock.sceneDidChange(to: .background)
        auth.outcome = .failed
        await lock.unlock(reason: "r")
        XCTAssertTrue(lock.isLocked)
        XCTAssertTrue(lock.isEnabled)
    }

    func testSenzaCodiceSiSbloccaESiSpegne() async {
        let lock = await enabledLock()
        lock.sceneDidChange(to: .background)
        auth.outcome = .unavailable
        await lock.unlock(reason: "r")
        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(lock.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: "native.lock.enabled"))
    }

    func testDueUnlockInsiemeChiedonoUnaVolta() async {
        let lock = await enabledLock()
        lock.sceneDidChange(to: .background)
        let before = auth.calls
        auth.holds = true
        let first = Task { await lock.unlock(reason: "r") }
        while auth.calls == before { await Task.yield() }
        let second = Task { await lock.unlock(reason: "r") }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(auth.calls, before + 1)
        auth.release()
        await first.value
        await second.value
        XCTAssertEqual(auth.calls, before + 1)
        XCTAssertFalse(lock.isLocked)
    }

    func testUnSuccessArrivatoDopoIlBackgroundNonSblocca() async {
        let lock = await enabledLock()
        lock.sceneDidChange(to: .background)
        lock.sceneDidChange(to: .active)
        let before = auth.calls
        auth.holds = true
        let pending = Task { await lock.unlock(reason: "r") }
        while auth.calls == before { await Task.yield() }
        lock.sceneDidChange(to: .background) // mentre il foglio è ancora aperto
        auth.release()
        await pending.value
        XCTAssertTrue(lock.isLocked, "Un'autenticazione partita prima del background non deve sbloccare dopo")
    }

    func testSbloccoSenzaScenaAttivaScopreIlContenuto() async {
        let lock = await enabledLock()
        lock.sceneDidChange(to: .inactive)
        lock.sceneDidChange(to: .background) // nasce una scena nuova già attiva: nessun .active arriva
        await lock.unlock(reason: "r")
        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(lock.isObscured, "Senza tasto Sblocca la copertura non deve restare accesa")
    }

    func testLaSceltaSopravviveAlRiavvio() async {
        _ = await enabledLock()
        let reopened = makeLock()
        XCTAssertTrue(reopened.isEnabled)
        XCTAssertTrue(reopened.isLocked)
    }
}
