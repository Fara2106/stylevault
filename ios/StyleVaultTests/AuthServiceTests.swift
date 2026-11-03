import AuthenticationServices
import Auth
import XCTest
@testable import StyleVault

final class AuthServiceTests: XCTestCase {
    private func apiError(_ code: ErrorCode) -> AuthError {
        .api(message: "x", errorCode: code, underlyingData: Data(),
             underlyingResponse: HTTPURLResponse())
    }

    func testLoginGoogleAnnullatoNonEUnErrore() {
        let error = ASWebAuthenticationSessionError(.canceledLogin)
        XCTAssertEqual(AuthErrorKind.from(error), .cancelled)
        XCTAssertNil(AuthErrorKind.cancelled.message)
    }

    func testCredenzialiSbagliate() {
        XCTAssertEqual(AuthErrorKind.from(apiError(.invalidCredentials)), .invalidCredentials)
    }

    func testEmailGiaRegistrata() {
        XCTAssertEqual(AuthErrorKind.from(apiError(.userAlreadyExists)), .emailTaken)
        XCTAssertEqual(AuthErrorKind.from(apiError(.emailExists)), .emailTaken)
    }

    func testSenzaRete() {
        XCTAssertEqual(AuthErrorKind.from(URLError(.notConnectedToInternet)), .unreachable)
    }

    // Review I3: senza rete si entra con la sessione salvata (offline), non sul login
    func testAvvioConLaSessioneSalvata() {
        XCTAssertTrue(Supa.authOptions.emitLocalSessionAsInitialSession)
    }

    func testMessaggiComeSulSito() {
        XCTAssertEqual(AuthErrorKind.invalidCredentials.message, "Email o password non corrette.")
        XCTAssertEqual(AuthErrorKind.emailTaken.message,
                       "Esiste già un account con questa email: prova ad accedere.")
    }
}

final class GoogleAvailabilityTests: XCTestCase {
    func testGoogleVisibileSoloSeAttivoSuSupabase() {
        XCTAssertTrue(AuthService.googleEnabled(in: Data(#"{"external":{"google":true,"email":true}}"#.utf8)))
        XCTAssertFalse(AuthService.googleEnabled(in: Data(#"{"external":{"google":false}}"#.utf8)))
        XCTAssertFalse(AuthService.googleEnabled(in: Data("non json".utf8)))
    }
}
