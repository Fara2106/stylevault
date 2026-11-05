import CloudKit
import XCTest
@testable import StyleVaultNative

final class SyncMonitorTests: XCTestCase {
    func testTuttoBene() {
        XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: nil), .active)
    }

    func testSenzaAccountCompareLAvviso() {
        let statuses: [CKAccountStatus] = [.noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable]
        for status in statuses {
            XCTAssertEqual(SyncRules.state(health: .cloud, account: status, lastError: nil), .unavailable)
        }
    }

    func testICloudPieno() {
        XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: CKError(.quotaExceeded)), .unavailable)
    }

    func testSenzaReteNonEUnProblema() {
        let codes: [CKError.Code] = [.networkUnavailable, .networkFailure, .serviceUnavailable]
        for code in codes {
            XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: CKError(code)), .active)
        }
    }

    func testArchivioSoloLocale() {
        XCTAssertEqual(SyncRules.state(health: .localOnly, account: .available, lastError: nil), .unavailable)
    }

    func testArchivioTemporaneo() {
        XCTAssertEqual(SyncRules.state(health: .temporary, account: .available, lastError: nil), .temporaryStore)
    }

    private func partial(_ inner: CKError.Code) -> CKError {
        let id = CKRecord.ID(recordName: "x")
        return CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [id: CKError(inner)]])
    }

    func testICloudPienoDentroPartialFailure() {
        XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: partial(.quotaExceeded)), .unavailable)
    }

    func testPartialFailureSenzaQuotaRestaAttivo() {
        XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: partial(.zoneBusy)), .active)
    }

    func testICloudPienoDentroUnderlyingError() {
        let inner = CKError(.quotaExceeded)
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134400, userInfo: [NSUnderlyingErrorKey: inner])
        XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: wrapped), .unavailable)
    }

    func testICloudPienoComeNSError() {
        let error = NSError(domain: CKErrorDomain, code: CKError.quotaExceeded.rawValue)
        XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: error), .unavailable)
    }

    @MainActor
    func testMonitorCloudParteAttivoSenzaLampo() {
        XCTAssertEqual(SyncMonitor(health: .cloud).state, .active)
    }

    @MainActor
    func testEventoPrimaDellAccountNonFaLampeggiare() {
        let monitor = SyncMonitor(health: .cloud)
        monitor.record(succeeded: true, error: nil)
        XCTAssertEqual(monitor.state, .active)
        monitor.record(succeeded: false, error: CKError(.quotaExceeded))
        XCTAssertEqual(monitor.state, .active)
        monitor.apply(account: .available)
        XCTAssertEqual(monitor.state, .unavailable)
    }

    @MainActor
    func testAccountNonDisponibileDopoLaRisposta() {
        let monitor = SyncMonitor(health: .cloud)
        monitor.apply(account: .noAccount)
        XCTAssertEqual(monitor.state, .unavailable)
    }

    @MainActor
    func testMonitorTemporaneoNonContattaCloudKit() {
        let monitor = SyncMonitor(health: .temporary)
        monitor.start()
        monitor.start()
        XCTAssertEqual(monitor.state, .temporaryStore)
    }
}
