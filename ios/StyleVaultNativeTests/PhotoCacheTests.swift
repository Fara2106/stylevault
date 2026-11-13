import CoreGraphics
import XCTest
@testable import StyleVaultNative

@MainActor final class PhotoCacheTests: XCTestCase {
    /// 1600×2133 come il dettaglio: 13,6 MB a foto una volta decodificata.
    private func large() throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: 1600, height: 2133, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        return try XCTUnwrap(context.makeImage())
    }

    func testLeFotoGrandiNonRestanoTutteInMemoria() throws {
        let side = 7777 // Una cache solo per questo test.
        let image = try large()
        for index in 0..<30 {
            PhotoCache.store(image, for: Data("foto \(index)".utf8), maxSide: side)
        }
        XCTAssertNil(PhotoCache.image(for: Data("foto 0".utf8), maxSide: side))
        XCTAssertNotNil(PhotoCache.image(for: Data("foto 29".utf8), maxSide: side))
    }
}
