import CoreGraphics
import Foundation

/// I punti di una persona nel formato di DWPose/OpenPose, in pixel con l'origine in alto a sinistra.
/// `nil` vuol dire «non visto»: quel punto e gli arti che lo toccano non si disegnano.
public struct PoseKeypoints: Equatable, Sendable {
    /// 18 punti: naso, collo, spalla-gomito-polso destri, spalla-gomito-polso sinistri, anca-ginocchio-caviglia destri,
    /// anca-ginocchio-caviglia sinistri, occhio destro, occhio sinistro, orecchio destro, orecchio sinistro.
    /// Destra e sinistra sono quelle della persona.
    public var body: [CGPoint?]
    /// Per ogni mano 21 punti: polso, poi pollice, indice, medio, anulare, mignolo, quattro punti ciascuno dalla base alla punta.
    public var hands: [[CGPoint?]]
    /// I punti del viso, quanti ce ne sono.
    public var face: [CGPoint]

    public init(body: [CGPoint?] = [CGPoint?](repeating: nil, count: 18), hands: [[CGPoint?]] = [], face: [CGPoint] = []) {
        self.body = body
        self.hands = hands
        self.face = face
    }

    /// Nessuna persona: è la posa di un capo fotografato da solo.
    public static let none = PoseKeypoints()
}

/// Il disegno della posa in grigio che FASHN riceve insieme alle foto: stessi arti, stessi grigi e stessi spessori di
/// `draw_pose(..., grayscale=True)` della pipeline originale (adattata da DWPose, Apache 2.0).
public enum PoseSketch {
    /// Coppie di punti del corpo, numerati da 1 come nell'originale.
    static let limbs: [(Int, Int)] = [(2, 3), (2, 6), (3, 4), (4, 5), (6, 7), (7, 8), (2, 9), (9, 10), (10, 11), (2, 12), (12, 13),
                                      (13, 14), (2, 1), (1, 15), (15, 17), (1, 16), (16, 18)]
    static let handEdges: [(Int, Int)] = [(0, 1), (1, 2), (2, 3), (3, 4), (0, 5), (5, 6), (6, 7), (7, 8), (0, 9), (9, 10), (10, 11),
                                          (11, 12), (0, 13), (13, 14), (14, 15), (15, 16), (0, 17), (17, 18), (18, 19), (19, 20)]
    static let stickWidth = 4

    /// `np.linspace(low, high, count).astype(np.uint8)`
    static func linspace(_ low: Double, _ high: Double, _ count: Int) -> [UInt8] {
        (0..<count).map { UInt8(low + (high - low) * Double($0) / Double(count - 1)) }
    }

    static let limbGrays = linspace(20, 240, 18)
    static let handGrays = linspace(160, 220, handEdges.count)

    public static func draw(_ pose: PoseKeypoints, width: Int, height: Int) -> GrayCanvas {
        var canvas = GrayCanvas(width: width, height: height)
        func pixel(_ point: CGPoint?) -> (x: Int, y: Int)? { point.map { (Int($0.x), Int($0.y)) } }

        // Arti: ellissi su una tela a parte, poi attenuate a 0,6
        var limbCanvas = GrayCanvas(width: width, height: height)
        for (index, limb) in limbs.enumerated() {
            guard pose.body.count >= 18, let a = pixel(pose.body[limb.0 - 1]), let b = pixel(pose.body[limb.1 - 1]) else { continue }
            let length = Int(hypot(Double(a.x - b.x), Double(a.y - b.y)))
            let degrees = Int(atan2(Double(a.y - b.y), Double(a.x - b.x)) * 180 / .pi)
            limbCanvas.fillEllipse(centerX: (a.x + b.x) >> 1, centerY: (a.y + b.y) >> 1, semiMajor: length / 2, semiMinor: stickWidth,
                                   degrees: degrees, value: limbGrays[index])
        }
        for i in canvas.pixels.indices { canvas.pixels[i] = max(canvas.pixels[i], UInt8(Double(limbCanvas.pixels[i]) * 0.6)) }

        // Giunti: il grigio del primo arto che li tocca, più chiaro
        for joint in 1...18 where pose.body.count >= joint {
            guard let first = limbs.firstIndex(where: { $0.0 == joint || $0.1 == joint }), let p = pixel(pose.body[joint - 1]) else { continue }
            canvas.fillCircle(x: p.x, y: p.y, radius: 4, value: UInt8(min(255, Int(Double(limbGrays[first]) * 1.3))))
        }

        // Mani: l'originale salta i punti a zero o fuori a sinistra e in alto
        func visible(_ point: CGPoint?) -> (x: Int, y: Int)? { pixel(point).flatMap { $0.x > 0 && $0.y > 0 ? $0 : nil } }
        for hand in pose.hands where hand.count >= 21 {
            for (index, edge) in handEdges.enumerated() {
                guard let a = visible(hand[edge.0]), let b = visible(hand[edge.1]) else { continue }
                canvas.drawLine(fromX: a.x, fromY: a.y, toX: b.x, toY: b.y, thickness: 2, value: handGrays[index])
            }
            for point in hand {
                if let p = visible(point) { canvas.fillCircle(x: p.x, y: p.y, radius: 4, value: 240) }
            }
        }

        for point in pose.face {
            if let p = visible(point) { canvas.fillCircle(x: p.x, y: p.y, radius: 3, value: 200) }
        }
        return canvas
    }
}
