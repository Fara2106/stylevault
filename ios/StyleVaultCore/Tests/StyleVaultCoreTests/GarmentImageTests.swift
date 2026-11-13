import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import StyleVaultCore

final class GarmentImageTests: XCTestCase {
    // MARK: Aiutanti

    private func makeImage(width: Int, height: Int, alpha: CGFloat = 1) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: alpha))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func encode(_ image: CGImage, type: UTType, orientation: Int = 1) -> Data {
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)!
        let properties = [kCGImagePropertyOrientation: orientation] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func decode(_ data: Data) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func rgba(_ image: CGImage) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    private func transparentFraction(_ image: CGImage) -> Double {
        let pixels = rgba(image)
        let total = pixels.count / 4
        let transparent = stride(from: 3, to: pixels.count, by: 4).reduce(0) { $0 + (pixels[$1] < 26 ? 1 : 0) }
        return Double(transparent) / Double(total)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    // MARK: Foto pronta

    func testRiduceIlLatoLungo() throws {
        let out = try XCTUnwrap(GarmentImage.prepared(encode(makeImage(width: 3000, height: 2000), type: .png)))
        let image = try decode(out)
        XCTAssertEqual(image.width, 1600)
        XCTAssertEqual(image.height, 1067)
    }

    func testNonIngrandisce() throws {
        let out = try XCTUnwrap(GarmentImage.prepared(encode(makeImage(width: 300, height: 200), type: .png)))
        XCTAssertEqual(try decode(out).width, 300)
    }

    func testRaddrizzaConLEXIF() throws {
        let rotated = encode(makeImage(width: 400, height: 200), type: .jpeg, orientation: 6)
        let image = try decode(XCTUnwrap(GarmentImage.prepared(rotated)))
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 400)
    }

    func testIlTrasparenteDiventaBianco() throws {
        let out = try XCTUnwrap(GarmentImage.prepared(encode(makeImage(width: 50, height: 50, alpha: 0), type: .png)))
        XCTAssertGreaterThan(rgba(try decode(out))[0], 250)
    }

    func testDatiNonImmagine() {
        XCTAssertNil(GarmentImage.prepared(Data("ciao".utf8)))
    }

    func testMiniatura() throws {
        let thumb = try XCTUnwrap(GarmentImage.thumbnail(encode(makeImage(width: 3000, height: 1000), type: .png)))
        XCTAssertEqual(thumb.width, 400)
    }

    // MARK: Scontorno. Vision gira qui sul Mac, non nel simulatore.

    func testScontornoDelCapo() async throws {
        let photo = try fixture("maglione.jpg")
        let result = await GarmentImage.cutout(photo)
        let png = try XCTUnwrap(result)
        let image = try decode(png)
        print("Scontorno: \(png.count) byte da una foto di \(photo.count), \(image.width)x\(image.height)")
        XCTAssertLessThanOrEqual(max(image.width, image.height), GarmentImage.cutoutMaxSide)
        XCTAssertGreaterThan(transparentFraction(image), 0.1)
        XCTAssertLessThan(transparentFraction(image), 0.95)
    }

    func testIUnPaioDiScarpeRestaIntero() async throws {
        let result = await GarmentImage.cutout(try fixture("sneakers.jpg"))
        let png = try XCTUnwrap(result)
        XCTAssertLessThan(transparentFraction(try decode(png)), 0.95)
    }

    func testTintaUnitaNonHaSoggetto() async {
        let plain = encode(makeImage(width: 600, height: 600), type: .jpeg)
        let out = await GarmentImage.cutout(plain)
        XCTAssertNil(out)
    }


    // MARK: Foto da un file importato

    func testUnaFotoComeQuelleDellAppEntraComE() throws {
        let photo = encode(makeImage(width: 400, height: 300), type: .jpeg)
        XCTAssertEqual(GarmentImage.imported(photo), photo)
    }

    func testUnaFotoInUnAltroFormatoOTroppoGrandeSiRifa() throws {
        let png = try XCTUnwrap(GarmentImage.imported(encode(makeImage(width: 300, height: 200), type: .png)))
        XCTAssertEqual(CGImageSourceGetType(try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))) as String?, UTType.jpeg.identifier)
        let big = try XCTUnwrap(GarmentImage.imported(encode(makeImage(width: 3000, height: 2000), type: .jpeg)))
        XCTAssertEqual(try decode(big).width, 1600)
    }

    func testCiòCheNonEUnaFotoNonEntra() throws {
        XCTAssertNil(GarmentImage.imported(Data([1, 2, 3])))
        XCTAssertNil(GarmentImage.imported(Data()))
        // Formati che l'app non produce: il file può venire da chiunque, meglio non darli in pasto al decodificatore
        XCTAssertNil(GarmentImage.imported(encode(makeImage(width: 40, height: 30), type: .tiff)))
        XCTAssertNil(GarmentImage.imported(encode(makeImage(width: 40, height: 30), type: .gif)))
        XCTAssertNil(GarmentImage.imported(encode(makeImage(width: 40, height: 30), type: .bmp)))
    }

    func testUnaFotoCheDichiaraMisureEnormiNonEntra() throws {
        // Un PNG piccolo che nell'intestazione dichiara 60.000 × 60.000 pixel
        var png = encode(makeImage(width: 40, height: 30), type: .png)
        let header = try XCTUnwrap(png.range(of: Data("IHDR".utf8)))
        let side: [UInt8] = [0x00, 0x00, 0xEA, 0x60]
        png.replaceSubrange(header.upperBound..<(header.upperBound + 8), with: side + side)
        XCTAssertNil(GarmentImage.imported(png))
        XCTAssertNil(GarmentImage.importedCutout(png))
    }

    func testLoScontornoImportatoESoloUnPNG() throws {
        let png = encode(makeImage(width: 200, height: 300, alpha: 0.5), type: .png)
        XCTAssertEqual(GarmentImage.importedCutout(png), png)
        XCTAssertNil(GarmentImage.importedCutout(encode(makeImage(width: 200, height: 300), type: .jpeg)))
        XCTAssertNil(GarmentImage.importedCutout(encode(makeImage(width: 3000, height: 300), type: .png)))
        XCTAssertNil(GarmentImage.importedCutout(Data([4])))
    }
}
