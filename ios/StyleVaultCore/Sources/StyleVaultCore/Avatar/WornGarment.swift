import CoreGraphics
import Vision

/// Un capo pronto per l'avatar: solo il capo, ritagliato al suo riquadro.
public struct GarmentPiece: @unchecked Sendable {
    public let image: CGImage
    /// La posa di chi lo indossava, nelle coordinate di `image`: serve ad allinearlo a spalle e fianchi.
    /// nil se la foto non la dà (foto da negozio tagliata sotto il mento).
    public let pose: Pose?

    public init(image: CGImage, pose: Pose?) {
        self.image = image
        self.pose = pose
    }
}

/// Capi fotografati addosso a qualcuno (foto da negozio o per strada). Lo scontorno di Vision tiene tutta la persona:
/// testa, braccia, borsa e gli altri capi. Qui si tiene solo il capo del posto dato, con i colori che ha sul busto
/// (o sulle cosce, o sotto le caviglie) e le parti attaccate.
public enum WornGarment {
    /// nil se nella foto non c'è una persona: il capo si usa intero, come prima.
    public static func piece(from cutout: Cutout, photo: CGImage, slot: String) async -> GarmentPiece? {
        await Task.detached(priority: .userInitiated) { () -> GarmentPiece? in
            guard hasPerson(photo) else { return nil }
            let pose = (try? await BodyPose.detect(photo)).flatMap { $0 }
            // Come la foto salvata del capo: in una foto a figura intera la maglia è piccola e sull'avatar si ingrandisce,
            // ma ogni pixel costa circa 25 byte durante il ritaglio
            let image = ImagePrep.downscaled(cutout.image, maxSide: GarmentImage.photoMaxSide)
            return extract(image, pose: pose.map { scale($0, from: photo, to: image) }, slot: slot)
        }.value
    }

    static func hasPerson(_ image: CGImage) -> Bool {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = false
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return !(request.results ?? []).isEmpty
    }

    private static func scale(_ pose: Pose, from a: CGImage, to b: CGImage) -> Pose {
        let sx = CGFloat(b.width) / CGFloat(a.width), sy = CGFloat(b.height) / CGFloat(a.height)
        return Pose(points: pose.points.mapValues { CGPoint(x: $0.x * sx, y: $0.y * sy) })
    }

    // MARK: - Dove sta il capo

    struct Regions: Equatable {
        /// Righe in cui può stare il capo (pixel, origine in alto).
        let rows: ClosedRange<CGFloat>
        /// Zone sicuramente coperte dal capo: da qui si prendono i suoi colori.
        let seeds: [CGRect]
        /// Zona del viso, per riconoscere la pelle. nil senza naso.
        let face: CGRect?
        /// Zona della testa sopra il naso, per riconoscere i capelli (che spesso cadono sul petto).
        var head: CGRect? = nil
    }

    static func regions(slot: String, pose: Pose?, subject: CGRect) -> Regions? {
        let p = pose?.points ?? [:]
        let face = p[.nose].map { nose -> CGRect in
            let size = 0.04 * subject.height
            return CGRect(x: nose.x - size / 2, y: nose.y - size / 2, width: size, height: size)
        }
        let head = p[.nose].flatMap { nose -> CGRect? in
            guard nose.y > subject.minY else { return nil }
            return CGRect(x: nose.x - 0.1 * subject.width, y: subject.minY, width: 0.2 * subject.width, height: nose.y - subject.minY)
        }
        // Un lato nascosto (testa girata, braccio davanti): lo si ricava a specchio dal collo
        let shoulders = pair(p[.leftShoulder], p[.rightShoulder], mirror: p[.neck]?.x)
        let hips = pair(p[.leftHip], p[.rightHip], mirror: shoulders.map { mid($0.0, $0.1).x })
        switch slot {
        case "top", "outerwear", "dress":
            guard let (sl, sr) = shoulders else { return fallback(slot: slot, subject: subject) }
            let s = mid(sl, sr), span = abs(sr.x - sl.x)
            guard span > 0.02 * subject.width else { return fallback(slot: slot, subject: subject) }
            let hip = hips.map { mid($0.0, $0.1) }
            let torso = hip.map { $0.y - s.y } ?? 1.25 * span
            guard torso > 0 else { return fallback(slot: slot, subject: subject) }
            let hipPoint = hip ?? CGPoint(x: s.x, y: s.y + torso)
            let chest = CGPoint(x: s.x + 0.45 * (hipPoint.x - s.x), y: s.y + 0.45 * torso)
            var seeds = [rect(center: chest, width: 0.45 * span, height: 0.3 * torso)]
            let bottom: CGFloat
            switch slot {
            case "top": bottom = hipPoint.y + 0.35 * torso
            case "outerwear":
                // Una giacca aperta lascia vedere il petto: i suoi colori stanno sulle maniche, sotto le spalle
                seeds = [sl, sr].map { rect(center: CGPoint(x: $0.x + ($0.x < s.x ? 0.05 : -0.05) * span, y: $0.y + 0.2 * torso),
                                            width: 0.15 * span, height: 0.2 * torso) }
                bottom = min(hipPoint.y + 0.9 * torso, subject.maxY)
            case "dress":
                seeds.append(rect(center: CGPoint(x: hipPoint.x, y: hipPoint.y + 0.3 * torso),
                                  width: 0.45 * span, height: 0.2 * torso))
                bottom = ankleY(p) ?? subject.maxY
            default: bottom = min(hipPoint.y + 0.9 * torso, subject.maxY)
            }
            // Il colletto sta poco sopra le spalle: più su c'è il collo
            return Regions(rows: (s.y - 0.12 * torso)...max(bottom, s.y), seeds: seeds, face: face, head: head)
        case "bottom":
            guard let (hl, hr) = hips else { return fallback(slot: slot, subject: subject) }
            let h = mid(hl, hr)
            let knee = pair(p[.leftKnee], p[.rightKnee], mirror: h.x).map { mid($0.0, $0.1) }
            let thigh = knee.map { $0.y - h.y } ?? 0.25 * subject.height
            guard thigh > 0 else { return fallback(slot: slot, subject: subject) }
            let span = max(abs(hr.x - hl.x), 0.3 * thigh)
            let seeds = [hl, hr].map { hip -> CGRect in
                let target = knee.map { CGPoint(x: hip.x + 0.4 * ($0.x - h.x), y: hip.y + 0.4 * thigh) }
                    ?? CGPoint(x: hip.x, y: hip.y + 0.4 * thigh)
                return rect(center: target, width: 0.4 * span, height: 0.25 * thigh)
            }
            // L'orlo scende fino a metà tra caviglia e pianta, come sull'avatar: sotto ci sono le scarpe
            let hem = ankleY(p).map { $0 + 0.5 * (subject.maxY - $0) } ?? subject.maxY
            return Regions(rows: (h.y - 0.45 * thigh)...max(hem, h.y), seeds: seeds, face: face)
        case "shoes":
            let ankles = [p[.leftAnkle], p[.rightAnkle]].compactMap { $0 }
            guard !ankles.isEmpty else { return nil }
            let knee = [p[.leftKnee], p[.rightKnee]].compactMap { $0 }.map(\.y).max()
            let shin = knee.map { ankles.map(\.y).max()! - $0 } ?? 0.2 * subject.height
            guard shin > 0 else { return nil }
            let seeds = ankles.map { rect(center: CGPoint(x: $0.x, y: $0.y + 0.15 * shin), width: 0.2 * shin, height: 0.15 * shin) }
            return Regions(rows: (ankles.map(\.y).min()! - 0.1 * shin)...subject.maxY, seeds: seeds, face: face)
        default:
            return nil
        }
    }

    /// Senza posa: solo per la foto da negozio tagliata sotto il mento, dove il capo sta in mezzo alla foto.
    /// Altrimenti (una mano che tiene la gruccia) il capo si usa intero.
    private static func fallback(slot: String, subject: CGRect) -> Regions? {
        guard subject.minY <= 1 else { return nil }
        let y: CGFloat
        switch slot {
        case "top", "outerwear", "dress": y = 0.35
        case "bottom": y = 0.45
        default: return nil
        }
        let seed = rect(center: CGPoint(x: subject.midX, y: subject.minY + y * subject.height),
                        width: 0.25 * subject.width, height: 0.12 * subject.height)
        return Regions(rows: subject.minY...subject.maxY, seeds: [seed], face: nil)
    }

    private static func ankleY(_ p: [Joint: CGPoint]) -> CGFloat? {
        [p[.leftAnkle], p[.rightAnkle]].compactMap { $0 }.map(\.y).max()
    }

    private static func pair(_ a: CGPoint?, _ b: CGPoint?, mirror axis: CGFloat?) -> (CGPoint, CGPoint)? {
        var a = a, b = b
        if let axis {
            if a == nil, let b { a = CGPoint(x: 2 * axis - b.x, y: b.y) }
            if b == nil, let a { b = CGPoint(x: 2 * axis - a.x, y: a.y) }
        }
        guard let a, let b else { return nil }
        return a.x <= b.x ? (a, b) : (b, a)
    }

    private static func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }

    private static func rect(center: CGPoint, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    // MARK: - Ritaglio

    /// Quota minima di una zona colore nelle zone del capo per essere del capo.
    static let seedShare = 0.15

    static func extract(_ image: CGImage, pose: Pose?, slot: String) -> GarmentPiece? {
        let pixels = RGBAPixels(image)
        let subject = PersonCutout.opaqueBounds(image)
        guard !subject.isEmpty, let regions = regions(slot: slot, pose: pose, subject: subject),
              let zones = ColorZones(pixels), let mask = mask(zones, regions: regions) else { return nil }
        return pixels.piece(mask: mask, pose: pose)
    }

    /// I pixel del capo che sta nelle zone date: i colori delle zone sicure, senza pelle e capelli, solo le parti
    /// collegate. nil se lì non c'è un capo riconoscibile.
    static func mask(_ zones: ColorZones, regions: Regions) -> [Bool]? {
        let w = zones.pixels.width, h = zones.pixels.height
        let cluster = zones.cluster
        let seedPixels = regions.seeds.flatMap(zones.indices)
        guard !seedPixels.isEmpty else { return nil }
        var share = [Int](repeating: 0, count: zones.count)
        for i in seedPixels { share[Int(cluster[i])] += 1 }
        var garment = Set(share.indices.filter { Double(share[$0]) >= seedShare * Double(seedPixels.count) })
        // Pelle (colore del viso) e capelli (il colore più presente in testa oltre alla pelle) non sono del capo,
        // a meno che il capo non sia proprio di quel colore
        let skin = zones.dominant(in: regions.face, except: nil)
        let hair = zones.dominant(in: regions.head, except: skin)
        // Il colore principale del capo resta anche se somiglia ai capelli (maglia marrone, capelli castani)
        let main = share.indices.filter { $0 != skin }.max { share[$0] < share[$1] }
        for part in [skin, hair == main ? nil : hair].compactMap({ $0 }) where Double(share[part]) < 0.6 * Double(seedPixels.count) {
            garment.remove(part)
        }
        guard !garment.isEmpty else { return nil }

        let rowMin = max(Int(regions.rows.lowerBound), 0), rowMax = min(Int(regions.rows.upperBound), h - 1)
        guard rowMin <= rowMax else { return nil }
        var mask = [Bool](repeating: false, count: w * h)
        for y in rowMin...rowMax {
            for x in 0..<w where zones.pixels.alpha(y * w + x) >= 26 && garment.contains(Int(cluster[y * w + x])) {
                mask[y * w + x] = true
            }
        }
        let radius = max(1, min(w, h) / 300)
        mask = Morphology.close(mask, width: w, height: h, radius: radius)
        mask = Morphology.connected(mask, width: w, height: h, to: seedPixels)
        mask = Morphology.fillingHoles(mask, width: w, height: h)
        // Una ciocca sulla spalla lascerebbe uno strappo nel capo: i capelli che stanno dentro il suo profilo restano,
        // come nella foto. La pelle no (una mano sul fianco non è del capo)
        if let hair, !garment.contains(hair) {
            let closed = Morphology.close(mask, width: w, height: h, radius: max(2, min(w, h) / 25))
            for y in rowMin...rowMax {
                for x in 0..<w where closed[y * w + x] && zones.opaque[y * w + x] && Int(cluster[y * w + x]) == hair {
                    mask[y * w + x] = true
                }
            }
            mask = Morphology.fillingHoles(mask, width: w, height: h)
        }
        // Le zone colore tagliano a denti di sega (pieghe, ombre, ciocche): il bordo si arrotonda, senza uscire
        // dalla persona né dalle righe del capo
        let smooth = Morphology.smoothed(mask, width: w, height: h, radius: max(2, min(w, h) / 150))
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                mask[i] = smooth[i] && zones.pixels.alpha(i) >= 26 && (rowMin...rowMax).contains(y)
            }
        }
        mask = Morphology.connected(mask, width: w, height: h, to: seedPixels)
        return mask.contains(true) ? mask : nil
    }

    // MARK: - Colori

    static func kMeans(_ samples: [Lab], k: Int, iterations: Int = 12) -> [Lab] {
        // Partenza deterministica: il punto più lontano da quelli già scelti
        var centers = [samples[samples.count / 2]]
        var distance = samples.map { deltaE($0, centers[0]) }
        while centers.count < min(k, samples.count) {
            guard let far = distance.indices.max(by: { distance[$0] < distance[$1] }), distance[far] > 1 else { break }
            centers.append(samples[far])
            for i in samples.indices { distance[i] = min(distance[i], deltaE(samples[i], samples[far])) }
        }
        for _ in 0..<iterations {
            var sum = [(Double, Double, Double, Int)](repeating: (0, 0, 0, 0), count: centers.count)
            for s in samples {
                let c = nearest(s, centers)
                sum[c] = (sum[c].0 + s.L, sum[c].1 + s.a, sum[c].2 + s.b, sum[c].3 + 1)
            }
            centers = centers.indices.map { c in
                sum[c].3 == 0 ? centers[c] : Lab(L: sum[c].0 / Double(sum[c].3), a: sum[c].1 / Double(sum[c].3),
                                                  b: sum[c].2 / Double(sum[c].3))
            }
        }
        return centers
    }

    private static func deltaE(_ a: Lab, _ b: Lab) -> Double {
        let dL = a.L - b.L, da = a.a - b.a, db = a.b - b.b
        return dL * dL + da * da + db * db
    }

    static func nearest(_ v: Lab, _ centers: [Lab]) -> Int {
        var best = 0, bestDistance = Double.infinity
        for (i, c) in centers.enumerated() {
            let d = deltaE(v, c)
            if d < bestDistance { best = i; bestDistance = d }
        }
        return best
    }
}

/// Le zone colore di uno scontorno (k-means in Lab, colori ridotti a 15 bit): ogni pixel visibile ha la sua.
struct ColorZones {
    let pixels: RGBAPixels
    let opaque: [Bool]
    let cluster: [UInt8]
    let count: Int

    /// nil se c'è troppo poco da guardare.
    init?(_ pixels: RGBAPixels) {
        let w = pixels.width, h = pixels.height
        var table = ColorTable()
        let keys = pixels.colorKeys()
        let opaque = (0..<(w * h)).map { pixels.alpha($0) >= 128 }
        let step = max(1, Int((Double(opaque.filter { $0 }.count) / 20_000).squareRoot()))
        var samples = [Lab]()
        for y in stride(from: 0, to: h, by: step) {
            for x in stride(from: 0, to: w, by: step) where opaque[y * w + x] { samples.append(table.lab(keys[y * w + x])) }
        }
        guard samples.count >= 50 else { return nil }
        let centers = WornGarment.kMeans(samples, k: 6)
        var clusterOfKey = [UInt8](repeating: .max, count: 1 << 15)
        self.cluster = keys.map { key -> UInt8 in
            if clusterOfKey[Int(key)] == .max { clusterOfKey[Int(key)] = UInt8(WornGarment.nearest(table.lab(key), centers)) }
            return clusterOfKey[Int(key)]
        }
        self.pixels = pixels
        self.opaque = opaque
        self.count = centers.count
    }

    /// I pixel visibili dentro il riquadro.
    func indices(in r: CGRect) -> [Int] {
        let w = pixels.width, h = pixels.height
        let x0 = max(Int(r.minX), 0), x1 = min(Int(r.maxX), w - 1)
        let y0 = max(Int(r.minY), 0), y1 = min(Int(r.maxY), h - 1)
        guard x0 <= x1, y0 <= y1 else { return [] }
        return (y0...y1).flatMap { y in (x0...x1).map { y * w + $0 } }.filter { opaque[$0] }
    }

    /// La zona colore più presente nel riquadro.
    func dominant(in r: CGRect?, except: Int?) -> Int? {
        guard let r else { return nil }
        var found = [Int](repeating: 0, count: count)
        for i in indices(in: r) where Int(cluster[i]) != except { found[Int(cluster[i])] += 1 }
        return found.indices.max { found[$0] < found[$1] }.flatMap { found[$0] > 0 ? $0 : nil }
    }
}

/// Lab dei colori a 15 bit, calcolati solo quando servono.
struct ColorTable {
    private var labs = [Lab?](repeating: nil, count: 1 << 15)

    mutating func lab(_ key: UInt16) -> Lab {
        if let hit = labs[Int(key)] { return hit }
        let k = Int(key)
        let lab = ColorLab.lab(RGB(r: (k >> 10 & 31) << 3 | 4, g: (k >> 5 & 31) << 3 | 4, b: (k & 31) << 3 | 4))
        labs[Int(key)] = lab
        return lab
    }
}

/// Pixel RGBA premoltiplicati, origine in alto a sinistra.
struct RGBAPixels {
    let width: Int
    let height: Int
    var data: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func alpha(_ i: Int) -> UInt8 { data[i * 4 + 3] }

    /// Il colore vero del pixel (non premoltiplicato), 0-255.
    func color(_ i: Int) -> (Double, Double, Double) {
        let a = Double(data[i * 4 + 3])
        guard a > 0 else { return (0, 0, 0) }
        return (min(255, Double(data[i * 4]) * 255 / a), min(255, Double(data[i * 4 + 1]) * 255 / a),
                min(255, Double(data[i * 4 + 2]) * 255 / a))
    }

    /// Il colore di ogni pixel a 5 bit per canale: bastano per le zone colore e la tabella resta piccola.
    func colorKeys() -> [UInt16] {
        (0..<(width * height)).map { i in
            let a = Int(data[i * 4 + 3])
            guard a > 0 else { return 0 }
            let r = min(255, Int(data[i * 4]) * 255 / a), g = min(255, Int(data[i * 4 + 1]) * 255 / a)
            let b = min(255, Int(data[i * 4 + 2]) * 255 / a)
            return UInt16((r >> 3) << 10 | (g >> 3) << 5 | (b >> 3))
        }
    }

    /// Solo i pixel della maschera, ritagliati al loro riquadro; la posa segue il ritaglio.
    func piece(mask: [Bool], pose: Pose?) -> GarmentPiece? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where mask[y * width + x] && alpha(y * width + x) >= 26 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        let w = maxX - minX + 1, h = maxY - minY + 1
        // Bordo morbido: la maschera viene da zone colore e taglia a scalini
        let soft = Morphology.softened(mask, width: width, height: height)
        var out = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let source = (y + minY) * width + x + minX
                let k = soft[source]
                guard k > 0 else { continue }
                for c in 0..<4 { out[(y * w + x) * 4 + c] = UInt8(Float(data[source * 4 + c]) * k) }
            }
        }
        guard let provider = CGDataProvider(data: Data(out) as CFData),
              let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        let shifted = pose.map { Pose(points: $0.points.mapValues { CGPoint(x: $0.x - CGFloat(minX), y: $0.y - CGFloat(minY)) }) }
        return GarmentPiece(image: image, pose: shifted)
    }
}

/// Operazioni su maschere binarie (riga per riga, origine in alto).
enum Morphology {
    static func close(_ mask: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        erode(dilate(mask, width: width, height: height, radius: radius), width: width, height: height, radius: radius)
    }

    static func dilate(_ mask: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        spread(mask, width: width, height: height, radius: radius, value: true)
    }

    static func erode(_ mask: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        spread(mask, width: width, height: height, radius: radius, value: false)
    }

    /// Un quadrato di lato 2r+1, separato in orizzontale e verticale.
    private static func spread(_ mask: [Bool], width: Int, height: Int, radius: Int, value: Bool) -> [Bool] {
        var horizontal = mask
        for y in 0..<height {
            for x in 0..<width where mask[y * width + x] != value {
                let x0 = max(0, x - radius), x1 = min(width - 1, x + radius)
                if (x0...x1).contains(where: { mask[y * width + $0] == value }) { horizontal[y * width + x] = value }
            }
        }
        var out = horizontal
        for y in 0..<height {
            for x in 0..<width where horizontal[y * width + x] != value {
                let y0 = max(0, y - radius), y1 = min(height - 1, y + radius)
                if (y0...y1).contains(where: { horizontal[$0 * width + x] == value }) { out[y * width + x] = value }
            }
        }
        return out
    }

    /// La media dei valori attorno a ogni pixel (quadrato di lato 2r+1), contando solo quelli con `weights`.
    /// Dove attorno non ce ne sono vale la media di tutti.
    static func average(_ values: [Double], weights: [Bool], width: Int, height: Int, radius: Int) -> [Double] {
        // Somme cumulate: il conto non dipende dal raggio
        let stride = width + 1
        var sums = [Double](repeating: 0, count: stride * (height + 1))
        var counts = [Double](repeating: 0, count: stride * (height + 1))
        var total = 0.0, number = 0.0
        for y in 0..<height {
            var row = 0.0, rowCount = 0.0
            for x in 0..<width {
                if weights[y * width + x] { row += values[y * width + x]; rowCount += 1 }
                sums[(y + 1) * stride + x + 1] = sums[y * stride + x + 1] + row
                counts[(y + 1) * stride + x + 1] = counts[y * stride + x + 1] + rowCount
            }
            total += row
            number += rowCount
        }
        let fallback = number > 0 ? total / number : 0
        var out = [Double](repeating: fallback, count: width * height)
        for y in 0..<height {
            let y0 = max(0, y - radius), y1 = min(height - 1, y + radius) + 1
            for x in 0..<width {
                let x0 = max(0, x - radius), x1 = min(width - 1, x + radius) + 1
                let n = counts[y1 * stride + x1] - counts[y0 * stride + x1] - counts[y1 * stride + x0] + counts[y0 * stride + x0]
                guard n > 0 else { continue }
                out[y * width + x] = (sums[y1 * stride + x1] - sums[y0 * stride + x1] - sums[y1 * stride + x0] + sums[y0 * stride + x0]) / n
            }
        }
        return out
    }

    /// Arrotonda il bordo: resta pieno dove attorno (quadrato di lato 2r+1) è pieno più di metà.
    /// Toglie i denti di sega e le lingue sottili, riempie le tacche; un bordo dritto non si sposta.
    static func smoothed(_ mask: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        let all = [Bool](repeating: true, count: mask.count)
        return average(mask.map { $0 ? 1 : 0 }, weights: all, width: width, height: height, radius: radius).map { $0 > 0.5 }
    }

    /// Media 3×3 ripetuta due volte: da 0/1 a una sfumatura di due pixel.
    static func softened(_ mask: [Bool], width: Int, height: Int) -> [Float] {
        var values = mask.map { $0 ? Float(1) : 0 }
        for _ in 0..<2 {
            var next = values
            for y in 0..<height {
                for x in 0..<width {
                    var sum: Float = 0, count: Float = 0
                    for ny in max(0, y - 1)...min(height - 1, y + 1) {
                        for nx in max(0, x - 1)...min(width - 1, x + 1) { sum += values[ny * width + nx]; count += 1 }
                    }
                    next[y * width + x] = sum / count
                }
            }
            values = next
        }
        return values
    }

    /// Tiene solo le parti collegate ai pixel dati.
    static func connected(_ mask: [Bool], width: Int, height: Int, to seeds: [Int]) -> [Bool] {
        var out = [Bool](repeating: false, count: mask.count)
        var stack = seeds.filter { mask[$0] }
        for s in stack { out[s] = true }
        while let i = stack.popLast() {
            let x = i % width, y = i / width
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            where nx >= 0 && ny >= 0 && nx < width && ny < height {
                let n = ny * width + nx
                if mask[n] && !out[n] { out[n] = true; stack.append(n) }
            }
        }
        return out
    }

    /// Chiude i buchi che non toccano il bordo (una stampa, un bottone di un altro colore).
    static func fillingHoles(_ mask: [Bool], width: Int, height: Int) -> [Bool] {
        var outside = [Bool](repeating: false, count: mask.count)
        var stack = [Int]()
        for x in 0..<width { stack.append(x); stack.append((height - 1) * width + x) }
        for y in 0..<height { stack.append(y * width); stack.append(y * width + width - 1) }
        stack = stack.filter { !mask[$0] }
        for s in stack { outside[s] = true }
        while let i = stack.popLast() {
            let x = i % width, y = i / width
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            where nx >= 0 && ny >= 0 && nx < width && ny < height {
                let n = ny * width + nx
                if !mask[n] && !outside[n] { outside[n] = true; stack.append(n) }
            }
        }
        return outside.map { !$0 }
    }
}
