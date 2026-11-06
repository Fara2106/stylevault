import AuthenticationServices
import Auth
import XCTest
@testable import StyleVault

final class AuthServiceTests: XCTestCase {
    private func apiError(_ code: ErrorCode) -> AuthError {
        .api(message: "x", errorCode: code, underlyingData: Data(),
             underlyingResponse: HTTPURLResponse())
    }

    func testLoginAppleAnnullatoNonEUnErrore() {
        XCTAssertEqual(AuthErrorKind.from(ASAuthorizationError(.canceled)), .cancelled)
    }

    /// Apple firma il nonce cifrato, Supabase riceve quello in chiaro e rifà il conto.
    func testIlNonceDiAppleEIlSuoSHA256() {
        XCTAssertEqual(AppleNonce(raw: "abc").hashed,
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testIlNonceCambiaOgniVolta() {
        XCTAssertNotEqual(AppleNonce().raw, AppleNonce().raw)
    }

    func testIlNomeDiAppleUnisceNomeECognome() {
        var name = PersonNameComponents()
        name.givenName = "Marianna"
        name.familyName = "Cavaliere"
        XCTAssertEqual(AppleNonce.displayName(name), "Marianna Cavaliere")
    }

    /// Dal secondo accesso Apple non manda più il nome: quello salvato non va cancellato.
    func testSenzaNomeDaAppleNonSiToccaQuelloSalvato() {
        XCTAssertNil(AppleNonce.displayName(nil))
        XCTAssertNil(AppleNonce.displayName(PersonNameComponents()))
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

    func testUnErroreDiAppleDiceIlCodice() throws {
        let kind = AuthErrorKind.from(ASAuthorizationError(.failed))
        XCTAssertEqual(kind, .appleFailed(1004))
        XCTAssertTrue(try XCTUnwrap(kind.message).contains("1004"))
    }
}
