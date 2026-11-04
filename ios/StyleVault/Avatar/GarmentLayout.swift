import CoreGraphics

/// Dove va ogni capo sul corpo, dai punti della posa (pixel, origine in alto
/// a sinistra) e dalla sagoma scontornata. Tarato a schermo sulla foto di
/// prova (2026-11-03): le spalle di Vision sono i giunti, più strette della
/// persona, quindi top e scarpe prendono la misura anche dalla sagoma; il
/// "collo" di Vision cade all'altezza delle spalle. Con la sagoma (2026-11-03,
/// prova sull'iPhone) top e pantaloni prendono la larghezza vera del petto e
/// dei fianchi, non quella del riquadro.
enum GarmentLayout {
    /// Una scarpa disegnata su un piede; `mirrored` la gira per avere la punta giusta.
    struct ShoePlacement {
        let frame: CGRect
        let mirrored: Bool
    }

    static func frame(for slot: String, pose: Pose, bodyBounds: CGRect,
                      garmentAspect: CGFloat, view: BodyView, silhouette: Silhouette? = nil) -> CGRect? {
        let p = pose.points
        // Senza spalle o fianchi (di lato/spalle Vision li perde) si usano le
        // proporzioni medie sulla sagoma: spalle al 18%, fianchi al 50%.
        let shoulderY = mid(p[.leftShoulder], p[.rightShoulder])?.y ?? bodyBounds.minY + 0.18 * bodyBounds.height
        let hipY = mid(p[.leftHip], p[.rightHip])?.y ?? bodyBounds.minY + 0.5 * bodyBounds.height
        guard hipY > shoulderY else { return nil }
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
        // Il petto sulla sagoma: braccia comprese (le maniche le coprono)
        let gap = 0.04 * bodyBounds.height
        let chest = silhouette?.run(row: shoulderY + 0.3 * torso, near: centerX, mergingGaps: gap)
        let topWidth = chest.map { 1.1 * ($0.upperBound - $0.lowerBound) } ?? max(1.3 * base, 0.9 * bodyBounds.width)
        let topX = chest.map { ($0.lowerBound + $0.upperBound) / 2 } ?? centerX

        switch slot {
        case "top":
            return centered(x: topX, width: topWidth, top: collarY, bottom: hipY + 0.08 * torso)
        case "outerwear":
            return centered(x: topX, width: topWidth * 1.12, top: collarY - 0.02 * torso,
                            bottom: hipY + 0.3 * torso)
        case "bottom":
            // La vita sta sopra il giunto dell'anca di Vision (così non resta
            // scoperta la maglia sotto il top); l'orlo scende a metà tra
            // caviglia e pianta e copre l'orlo originale
            let top = hipY - 0.1 * torso
            let bottom = ankle.y + 0.5 * (feetY - ankle.y)
            if view == .side, let hips = silhouette?.run(row: hipY + 0.1 * torso, near: hipX, mergingGaps: gap) {
                // Di lato il passo allarga le gambe: conta lo spessore dei fianchi
                let span = hips.upperBound - hips.lowerBound
                let width = min(max((bottom - top) * garmentAspect, span), 1.5 * span)
                return centered(x: (hips.lowerBound + hips.upperBound) / 2, width: width, top: top, bottom: bottom)
            }
            // Gambe divaricate: i pantaloni (gambe unite nella foto) le coprono
            let ankleSpan = abs((p[.rightAnkle]?.x ?? ankle.x) - (p[.leftAnkle]?.x ?? ankle.x))
            // ...ma mai più larghi di un terzo abbondante dell'altezza
            let width = min(max(min(max((bottom - top) * garmentAspect, 1.5 * hipSpan), 2.4 * hipSpan),
                                ankleSpan + 0.08 * bodyBounds.height), 0.35 * bodyBounds.height)
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

    /// Scarpe. Le foto prodotto di solito mostrano UNA scarpa di lato: va
    /// disegnata su ciascun piede, lunga quanto un piede (~15% dell'altezza),
    /// con la punta verso fuori (davanti, spalle) o dove guarda la persona (lato).
    /// Un paio resta una sola immagine sotto i due piedi.
    static func shoeFrames(pose: Pose, bodyBounds: CGRect, shoe: Silhouette, pair: Bool,
                           view: BodyView, silhouette: Silhouette?) -> [ShoePlacement] {
        let aspect = CGFloat(shoe.width) / CGFloat(max(shoe.height, 1))
        if pair {
            return frame(for: "shoes", pose: pose, bodyBounds: bodyBounds, garmentAspect: aspect, view: view)
                .map { [ShoePlacement(frame: $0, mirrored: false)] } ?? []
        }
        let p = pose.points
        var ankles = [p[.rightAnkle], p[.leftAnkle]].compactMap { $0 }
        if ankles.isEmpty {
            ankles = [CGPoint(x: bodyBounds.midX, y: bodyBounds.maxY - 0.03 * bodyBounds.height)]
        }
        let length = 0.15 * bodyBounds.height * (view == .side ? 1 : 0.85)
        let height = length / max(aspect, 0.3)
        let facingRight: Bool = {
            guard let nose = p[.nose], let neck = p[.neck] ?? mid(p[.leftShoulder], p[.rightShoulder]) else { return true }
            return nose.x >= neck.x
        }()
        let middle = ankles.map(\.x).reduce(0, +) / CGFloat(ankles.count)
        return ankles.map { ankle in
            let toeRight = view == .side ? facingRight : (ankles.count > 1 ? ankle.x > middle : ankle.x > bodyBounds.midX)
            // La caviglia sta sopra il tallone: la scarpa avanza verso la punta
            let x = ankle.x + (toeRight ? 1 : -1) * 0.2 * length
            let sole = silhouette?.lowestRow(columns: (ankle.x - 0.25 * length)...(ankle.x + 0.25 * length),
                                             from: ankle.y) ?? bodyBounds.maxY
            let frame = centered(x: x, width: length, top: sole + 0.03 * height - height, bottom: sole + 0.03 * height)
            return ShoePlacement(frame: frame, mirrored: toeRight == shoe.toeOnLeft)
        }
    }

    /// Righe (pixel, origine in alto) dove la parte di sopra realistica si
    /// ridisegna sopra il collage: dal collo (come `collarY` del top) alle
    /// ginocchia. Viso e piedi restano fuori. Senza punti, le stesse
    /// proporzioni di `frame`; ginocchia a metà tra fianchi e caviglie.
    static func overlayRows(pose: Pose, bodyBounds: CGRect) -> ClosedRange<CGFloat> {
        let p = pose.points
        let shoulderY = mid(p[.leftShoulder], p[.rightShoulder])?.y ?? bodyBounds.minY + 0.18 * bodyBounds.height
        var hipY = mid(p[.leftHip], p[.rightHip])?.y ?? bodyBounds.minY + 0.5 * bodyBounds.height
        if hipY <= shoulderY { hipY = shoulderY + 0.32 * bodyBounds.height }
        let ankleY = mid(p[.leftAnkle], p[.rightAnkle])?.y ?? bodyBounds.maxY - 0.03 * bodyBounds.height
        let collarY = shoulderY - 0.12 * (hipY - shoulderY)
        let kneeY = mid(p[.leftKnee], p[.rightKnee])?.y ?? hipY + 0.5 * max(ankleY - hipY, 0)
        return collarY...max(kneeY, collarY)
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
