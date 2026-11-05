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

    @MainActor
    func testMonitorTemporaneoNonContattaCloudKit() {
        let monitor = SyncMonitor(health: .temporary)
        monitor.start()
        monitor.start()
        XCTAssertEqual(monitor.state, .temporaryStore)
    }
}
