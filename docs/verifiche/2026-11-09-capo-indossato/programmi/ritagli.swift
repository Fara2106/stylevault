import CoreGraphics
import Foundation
import ImageIO
import StyleVaultCore
import UniformTypeIdentifiers

let args = CommandLine.arguments
let inDir = URL(fileURLWithPath: args[1]), outDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
func load(_ d: Data) -> CGImage? {
    guard let s = CGImageSourceCreateWithData(d as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(s, 0, nil)
}
func save(_ img: CGImage, _ name: String) {
    let out = NSMutableData()
    let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    CGImageDestinationFinalize(dest)
    try? (out as Data).write(to: outDir.appendingPathComponent(name))
}
/// Pannelli alti 480: modo 0 normale, 2 su magenta.
func panel(_ images: [(CGImage, Int)]) -> CGImage? {
    let H = 480.0
    let widths = images.map { Double($0.0.width) * H / Double($0.0.height) }
    let W = widths.reduce(0, +) + Double(images.count - 1) * 10
    guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    var x = 0.0
    for (i, (img, mode)) in images.enumerated() {
        let r = CGRect(x: x, y: 0, width: widths[i], height: H)
        if mode == 2 { ctx.setFillColor(CGColor(red: 1, green: 0, blue: 1, alpha: 1)); ctx.fill(r) }
        ctx.draw(img, in: r)
        x += widths[i] + 10
    }
    return ctx.makeImage()
}

let slots: [String: [String]] = [
    "30": ["top"], "31": ["top"], "32": ["top", "bottom"], "33": ["top"], "34": ["top"], "35": ["top"], "36": ["top"],
    "37": ["top"], "38": ["top"], "40": ["top", "bottom", "shoes"], "41": ["top", "bottom"], "42": ["top", "bottom"],
    "43": ["top", "bottom"], "44": ["bottom", "shoes"], "45": ["outerwear", "bottom"], "46": ["dress"], "27": ["top", "bottom"],
    "03": ["outerwear"], "05": ["top"], "06": ["outerwear"], "07": ["shoes"], "13": ["top"], "15": ["dress"], "18": ["bottom"],
    "23": ["shoes"], "25": ["top"], "26": ["top"],
]
let only = args.count > 3 ? Set(args[3].split(separator: ",").map(String.init)) : nil
for f in try FileManager.default.contentsOfDirectory(atPath: inDir.path).filter({ $0.hasPrefix("capo") }).sorted() {
    let id = String(f.dropFirst(5).prefix(2))
    guard let list = slots[id], only?.contains(id) ?? true else { continue }
    let raw = try Data(contentsOf: inDir.appendingPathComponent(f))
    let photo = ImagePrep.downscaled(ImagePrep.decodedForAnalysis(GarmentImage.prepared(raw)!)!)
    guard let cutout = try? await PersonCutout.cutout(photo, allInstances: true) else { print("\(f)\tnessun soggetto"); continue }
    var pieces: [(CGImage, Int)] = [(photo, 0), (cutout.image, 2)]
    for slot in list {
        let t0 = Date()
        let piece = await WornGarment.piece(from: cutout, photo: photo, slot: slot)
        print(String(format: "%@\t%@\t%@\tposa %@\t%.2fs", f, slot, piece == nil ? "intero (nessuna persona o nessun capo)" : "\(piece!.image.width)x\(piece!.image.height)",
                     piece?.pose == nil ? "no" : "sì", Date().timeIntervalSince(t0)))
        if let piece { pieces.append((piece.image, 2)) }
    }
    save(panel(pieces)!, f.replacingOccurrences(of: ".jpg", with: "-capo.jpg"))
}
