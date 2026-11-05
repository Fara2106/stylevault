@testable import StyleVaultNative
import XCTest

final class AuthRouteTests: XCTestCase {
    private func route(restoring: Bool = false, recovering: Bool = false,
                       signedIn: Bool = false, skipped: Bool = false) -> AuthRoute {
        AuthRoute.resolve(restoring: restoring, recovering: recovering, signedIn: signedIn, skipped: skipped)
    }

    func testChiNonHaUnaSessioneVedeLAccesso() {
        XCTAssertEqual(route(), .login)
    }

    func testChiHaUnaSessioneEntra() {
        XCTAssertEqual(route(signedIn: true), .app)
    }

    func testChiHaSceltoDiNonAccedereEntra() {
        XCTAssertEqual(route(skipped: true), .app)
    }

    func testIlLinkDellaPasswordVinceSuTutto() {
        XCTAssertEqual(route(recovering: true, signedIn: true, skipped: true), .newPassword)
    }

    /// Finché la sessione salvata non è letta non si mostra l'accesso: sarebbe un lampo a ogni apertura.
    func testMentreLeggeLaSessioneAspetta() {
        XCTAssertEqual(route(restoring: true), .loading)
    }

    /// Senza rete o col servizio in pausa chi ha scelto di non accedere non resta chiuso fuori.
    func testChiNonAccedeNonAspettaIlServizio() {
        XCTAssertEqual(route(restoring: true, skipped: true), .app)
    }

    func testGliErroriHannoUnaChiaveTradotta() {
        XCTAssertEqual(AuthErrorKind.invalidCredentials.localizationKey, "auth.errors.invalid-credentials")
        XCTAssertEqual(AuthErrorKind.emailTaken.localizationKey, "auth.errors.email-taken")
        XCTAssertEqual(AuthErrorKind.weakPassword.localizationKey, "auth.errors.password-too-short")
        XCTAssertEqual(AuthErrorKind.samePassword.localizationKey, "auth.errors.same-password")
        XCTAssertEqual(AuthErrorKind.tooManyEmails.localizationKey, "auth.errors.rate-limited")
        XCTAssertEqual(AuthErrorKind.unreachable.localizationKey, "native.auth.unreachable")
        XCTAssertNil(AuthErrorKind.cancelled.localizationKey)
    }
}
