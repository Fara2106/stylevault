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
func panel(_ images: [CGImage]) -> CGImage? {
    let H = 640.0
    let widths = images.map { Double($0.width) * H / Double($0.height) }
    let W = widths.reduce(0, +) + Double(images.count - 1) * 10
    guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    var x = 0.0
    for (i, img) in images.enumerated() { ctx.draw(img, in: CGRect(x: x, y: 0, width: widths[i], height: H)); x += widths[i] + 10 }
    return ctx.makeImage()
}
func file(_ id: String) -> URL {
    let name = try! FileManager.default.contentsOfDirectory(atPath: inDir.path).first { $0.hasPrefix(id) }!
    return inDir.appendingPathComponent(name)
}
let outfits: [(String, [(String, String)])] = [
    ("negozio", [("top", "capo-34"), ("bottom", "capo-44"), ("shoes", "capo-40")]),
    ("jeans-giacca", [("top", "capo-35"), ("bottom", "capo-45"), ("outerwear", "capo-45")]),
    ("marrone", [("top", "capo-40"), ("bottom", "capo-43")]),
    ("misto", [("top", "capo-26"), ("bottom", "capo-42"), ("shoes", "capo-23")]),
    ("abito", [("dress", "capo-46")]),
]
let bodies = args.count > 3 ? args[3].split(separator: ",").map(String.init) : ["persona-18", "persona-19", "persona-20"]
let stamp = UUID().uuidString.prefix(6)
for bodyId in bodies {
    let rawBody = try Data(contentsOf: file(bodyId))
    let body = GarmentImage.prepared(rawBody, maxSide: BodyPhotoAnalyzer.photoMaxSide)!
    for (name, outfit) in outfits {
        let garments = try outfit.map { slot, id in
            AvatarGarment(slot: slot, photo: GarmentImage.prepared(try Data(contentsOf: file(id)))!, key: id)
        }
        var images = [load(body)!]
        for mode in ["prima", "dopo"] {
            let folder = outDir.appendingPathComponent("cache-\(stamp)-\(mode)")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if mode == "prima" {
                for g in garments { FileManager.default.createFile(atPath: folder.appendingPathComponent("\(g.key)-\(g.slot)-capo1.nessuno").path, contents: nil) }
            }
            let cache = CutoutCache(folder: folder)
            for view in [BodyView.front] {
                do {
                    let t0 = Date()
                    let a = try await AvatarRenderer.render(body: body, bodyKey: bodyId, garments: garments, view: view, cache: cache)
                    if mode == "dopo" { print(bodyId, name, String(format: "%.2fs", Date().timeIntervalSince(t0)), "mancanti", a.unavailable) }
                    images.append(a.image)
                } catch { print(bodyId, name, mode, error) }
            }
        }
        save(panel(images)!, "\(bodyId)-\(name).jpg")
    }
}
