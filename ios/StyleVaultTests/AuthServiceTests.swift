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

    func testNuovaPasswordUgualeAllaVecchia() {
        XCTAssertEqual(AuthErrorKind.from(apiError(.samePassword)), .samePassword)
        XCTAssertEqual(AuthErrorKind.samePassword.message,
                       "La nuova password deve essere diversa da quella vecchia.")
    }

    func testTroppeEmailDiReset() {
        XCTAssertEqual(AuthErrorKind.from(apiError(.overEmailSendRateLimit)), .tooManyEmails)
    }
}

final class PasswordRecoveryTests: XCTestCase {
    // Il link dell'email di reset riapre l'app su un indirizzo suo, diverso
    // dal ritorno del login Google
    func testLinkDelResetRiconosciuto() {
        XCTAssertEqual(AppConfig.recoveryCallback.absoluteString, "stylevault://reset-password")
        XCTAssertTrue(AuthService.isRecoveryLink(URL(string: "stylevault://reset-password?code=abc")!))
        XCTAssertFalse(AuthService.isRecoveryLink(URL(string: "stylevault://auth-callback?code=abc")!))
        XCTAssertFalse(AuthService.isRecoveryLink(URL(string: "https://example.com/reset-password?code=abc")!))
    }
}

final class GoogleAvailabilityTests: XCTestCase {
    func testGoogleVisibileSoloSeAttivoSuSupabase() {
        XCTAssertTrue(AuthService.googleEnabled(in: Data(#"{"external":{"google":true,"email":true}}"#.utf8)))
        XCTAssertFalse(AuthService.googleEnabled(in: Data(#"{"external":{"google":false}}"#.utf8)))
        XCTAssertFalse(AuthService.googleEnabled(in: Data("non json".utf8)))
    }
}
