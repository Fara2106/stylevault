import CoreGraphics

/// Dove va ogni capo sul corpo, dai punti della posa (pixel, origine in alto
/// a sinistra) e dalla sagoma scontornata. Tarato a schermo sulla foto di
/// prova (2026-11-03): le spalle di Vision sono i giunti, più strette della
/// persona, quindi top e scarpe prendono la misura anche dalla sagoma; il
/// "collo" di Vision cade all'altezza delle spalle.
enum GarmentLayout {
    static func frame(for slot: String, pose: Pose, bodyBounds: CGRect,
                      garmentAspect: CGFloat, view: BodyView) -> CGRect? {
        let p = pose.points
        guard let shoulderY = mid(p[.leftShoulder], p[.rightShoulder])?.y,
              let hipY = mid(p[.leftHip], p[.rightHip])?.y, hipY > shoulderY else { return nil }
        let ankle = mid(p[.leftAnkle], p[.rightAnkle])
            ?? CGPoint(x: bodyBounds.midX, y: bodyBounds.maxY - 0.03 * bodyBounds.height)
        let centerX = mid(p[.leftShoulder], p[.rightShoulder])?.x ?? bodyBounds.midX
        let hipX = mid(p[.leftHip], p[.rightHip])?.x ?? centerX

        // Larghezza delle spalle; di lato (o se le spalle si sovrappongono)
        // la si ricava dalla sagoma scontornata.
        let shoulderSpan = abs((p[.rightShoulder]?.x ?? 0) - (p[.leftShoulder]?.x ?? 0))
        let base = view == .side || shoulderSpan < 0.35 * bodyBounds.width
            ? bodyBounds.width / 1.3 : shoulderSpan
        let hipSpan = view == .side
            ? bodyBounds.width * 0.6
            : max(abs((p[.rightHip]?.x ?? 0) - (p[.leftHip]?.x ?? 0)), bodyBounds.width * 0.45)
        let torso = hipY - shoulderY
        let collarY = shoulderY - 0.12 * torso
        let feetY = max(bodyBounds.maxY, ankle.y)
        let topWidth = max(1.3 * base, 0.9 * bodyBounds.width)

        switch slot {
        case "top":
            return centered(x: centerX, width: topWidth, top: collarY, bottom: hipY + 0.08 * torso)
        case "outerwear":
            return centered(x: centerX, width: topWidth * 1.12, top: collarY - 0.02 * torso,
                            bottom: hipY + 0.3 * torso)
        case "bottom":
            // L'orlo scende a metà tra caviglia e pianta: copre l'orlo originale
            let top = hipY - 0.04 * torso
            let bottom = ankle.y + 0.5 * (feetY - ankle.y)
            let width = min(max((bottom - top) * garmentAspect, 1.5 * hipSpan), 2.4 * hipSpan)
            return centered(x: hipX, width: width, top: top, bottom: bottom)
        case "shoes":
            let ankleSpan = abs((p[.rightAnkle]?.x ?? ankle.x) - (p[.leftAnkle]?.x ?? ankle.x))
            // Poggiano sulla pianta del piede, larghe almeno come i piedi
            let width = max(ankleSpan + 0.6 * base, 0.6 * bodyBounds.width)
            let height = width / max(garmentAspect, 0.3)
            return centered(x: ankle.x, width: width, top: feetY - 0.95 * height, bottom: feetY + 0.05 * height)
        default:
            return nil
        }
    }

    private static func mid(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        switch (a, b) {
        case let (a?, b?): return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    private static func centered(x: CGFloat, width: CGFloat, top: CGFloat, bottom: CGFloat) -> CGRect {
        CGRect(x: x - width / 2, y: top, width: width, height: bottom - top)
    }
}
