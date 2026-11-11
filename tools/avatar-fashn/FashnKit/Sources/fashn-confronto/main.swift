import CoreGraphics
import CoreML
import FashnKit
import FashnWorn
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Confronta gli ingressi preparati in Swift (posa di Apple Vision) con quelli catturati dalla pipeline originale
// (posa di DWPose), e se serve genera l'immagine sul Mac.
// Uso: fashn-confronto <persona> <capo> <uscita> [--originali <cartella dei .npy>] [--categoria tops|bottoms|one-pieces]
//        [--indossato-intero] [--genera <FashnTryOn.mlmodelc>] [--passi N] [--rumore-originale]

func savePNG(_ image: CGImage, _ url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

func rgbImage(_ bytes: [UInt8], width: Int, height: Int) -> CGImage? {
    guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

/// Un tensore a colori (canale-riga-colonna, da -1 a 1) come immagine.
func picture(color values: [Float]) -> CGImage? {
    let w = FashnModel.width, h = FashnModel.height, plane = w * h
    var bytes = [UInt8](repeating: 255, count: plane * 4)
    for i in 0..<plane { for c in 0..<3 { bytes[i * 4 + c] = UInt8((min(max(values[c * plane + i], -1), 1) + 1) * 127.5) } }
    return rgbImage(bytes, width: w, height: h)
}

func grayBytes(_ values: [Float]) -> [UInt8] { values.map { UInt8((min(max($0, -1), 1) + 1) * 127.5) } }

func picture(gray values: [UInt8]) -> CGImage? {
    var bytes = [UInt8](repeating: 255, count: values.count * 4)
    for i in values.indices { bytes[i * 4] = values[i]; bytes[i * 4 + 1] = values[i]; bytes[i * 4 + 2] = values[i] }
    return rgbImage(bytes, width: FashnModel.width, height: FashnModel.height)
}

/// Le due pose una sull'altra: rosso l'originale, verde la mia, giallo dove coincidono.
func overlay(reference: [UInt8], mine: [UInt8]) -> CGImage? {
    var bytes = [UInt8](repeating: 255, count: mine.count * 4)
    for i in mine.indices { bytes[i * 4] = reference[i] > 0 ? 255 : 0; bytes[i * 4 + 1] = mine[i] > 0 ? 255 : 0; bytes[i * 4 + 2] = 0 }
    return rgbImage(bytes, width: FashnModel.width, height: FashnModel.height)
}

func meanAbsoluteDifference(_ a: [Float], _ b: [Float]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return .nan }
    var sum = 0.0
    for i in a.indices { sum += Double(abs(a[i] - b[i])) }
    return sum / Double(a.count) * 127.5
}

func run() async throws {
    let args = CommandLine.arguments
    guard args.count >= 4 else {
        print("uso: fashn-confronto <persona> <capo> <uscita> [--originali <cartella>] [--categoria tops] [--indossato-intero] [--genera <mlmodelc>] [--passi N] [--rumore-originale]")
        exit(2)
    }
    func option(_ name: String) -> String? { args.firstIndex(of: name).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } }
    let out = URL(fileURLWithPath: args[3])
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let category: GarmentCategory = switch option("--categoria") { case "bottoms": .bottoms; case "one-pieces": .onePieces; default: .tops }

    let start = Date()
    var garment = try FashnPrepare.loadImage(URL(fileURLWithPath: args[2]))
    // Di base il capo indossato si riconosce e si isola da solo; --indossato-intero: la foto entra com'è, con la sua posa
    var wholeWornPhoto = args.contains("--indossato-intero")
    if !wholeWornPhoto {
        let prepared = await WornGarmentPhoto.prepared(garment, category: category)
        switch prepared.outcome {
        case .alone: print("capo da solo")
        case .isolated: print("capo isolato da chi lo indossa: \(prepared.image.width)×\(prepared.image.height)")
        case .notIsolated: print("capo indossato ma non isolato: entra la foto intera")
        }
        garment = prepared.image
        wholeWornPhoto = prepared.outcome == .notIsolated
    }
    let inputs = try FashnPrepare.inputs(person: try FashnPrepare.loadImage(URL(fileURLWithPath: args[1])),
                                         garment: garment, category: category, garmentIsWorn: wholeWornPhoto)
    print(String(format: "preparazione %.2f s, punti del corpo %d su 18, persona %d×%d nel riquadro", Date().timeIntervalSince(start),
                 inputs.bodyPointsFound, inputs.personFrame.width, inputs.personFrame.height))
    if let image = picture(color: inputs.person) { savePNG(image, out.appendingPathComponent("persona-swift.png")) }
    if let image = picture(color: inputs.garment) { savePNG(image, out.appendingPathComponent("capo-swift.png")) }
    let minePose = grayBytes(inputs.personPose)
    if let image = picture(gray: minePose) { savePNG(image, out.appendingPathComponent("posa-vision.png")) }

    var originalNoise: [Float]?
    if let folder = option("--originali").map({ URL(fileURLWithPath: $0) }) {
        func load(_ name: String) throws -> NumpyArray { try NumpyArray(contentsOf: folder.appendingPathComponent("\(name).npy")) }
        for (name, mine) in [("ca_images", inputs.person), ("garment_images", inputs.garment), ("person_poses", inputs.personPose),
                             ("garment_poses", inputs.garmentPose)] {
            let array = try load(name)
            let reference = try array.firstBatchFloats()
            print(String(format: "%@ forma %@: differenza media %.2f su 255", name, "\(array.shape)", meanAbsoluteDifference(mine, reference)))
            if name == "person_poses" {
                let ref = grayBytes(reference)
                if let image = picture(gray: ref) { savePNG(image, out.appendingPathComponent("posa-dwpose.png")) }
                if let image = overlay(reference: ref, mine: minePose) { savePNG(image, out.appendingPathComponent("posa-sovrapposta.png")) }
                var both = 0, either = 0, sameGray = 0
                for i in ref.indices {
                    let a = ref[i] > 0, b = minePose[i] > 0
                    if a || b { either += 1 }
                    if a && b { both += 1; if abs(Int(ref[i]) - Int(minePose[i])) <= 2 { sameGray += 1 } }
                }
                print(String(format: "posa: sovrapposizione %.0f%% dei pixel disegnati, stesso grigio nel %.0f%% di quelli in comune",
                             either == 0 ? 0 : 100 * Double(both) / Double(either), both == 0 ? 0 : 100 * Double(sameGray) / Double(both)))
            }
        }
        print("categoria originale \(try load("garment_categories").firstInteger()), mia \(inputs.category.rawValue)")
        if args.contains("--rumore-originale") { originalNoise = try load("x").firstBatchFloats() }
    }

    guard let modelPath = option("--genera") else { return }
    let steps = option("--passi").flatMap(Int.init) ?? 20
    let loadStart = Date()
    let sampler = try FashnSampler(modelURL: URL(fileURLWithPath: modelPath))
    print(String(format: "modello caricato in %.1f s", Date().timeIntervalSince(loadStart)))
    let generationStart = Date()
    var lastPercent = -1
    let result = try sampler.generate(inputs, steps: steps, noise: originalNoise) { progress in
        guard progress.percent != lastPercent else { return }
        lastPercent = progress.percent
        print(String(format: "%3d%%  passo %d di %d, %.0f s", progress.percent, progress.step, progress.steps, Date().timeIntervalSince(generationStart)))
        fflush(stdout)
    }
    print(String(format: "generazione %.1f s", Date().timeIntervalSince(generationStart)))
    if let image = FashnPrepare.image(fromOutput: result, frame: inputs.personFrame) {
        savePNG(image, out.appendingPathComponent("risultato-\(steps).png"))
    }
}

do { try await run() } catch { print("ERRORE \(error)"); exit(1) }
