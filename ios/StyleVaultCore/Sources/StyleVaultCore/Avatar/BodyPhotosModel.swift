import CoreGraphics
import Foundation

/// Le 3 foto del corpo: davanti, lato, spalle. `rawValue` è il `kind` di `BodyPhoto`.
public enum BodyView: String, CaseIterable, Identifiable, Sendable {
    case front, side, back
    public var id: String { rawValue }

    public var labelKey: String {
        switch self {
        case .front: return "profile.bodyViewFront"
        case .side: return "profile.bodyViewSide"
        case .back: return "profile.bodyViewBack"
        }
    }

    public var guideKey: String { "native.body.guide.\(rawValue)" }
    public var missingKey: String { "native.avatar.missing.\(rawValue)" }
}

public enum PhotoCheck: Equatable, Sendable {
    case ok, noPerson, multiplePeople, notFullBody
    case wrongView(seen: BodyView, wanted: BodyView)

    public var messageKey: String? {
        switch self {
        case .ok: return nil
        case .noPerson: return "native.body.check.noPerson"
        case .multiplePeople: return "native.body.check.multiplePeople"
        case .notFullBody: return "native.body.check.notFullBody"
        case let .wrongView(_, wanted): return "native.body.check.wrongView.\(wanted.rawValue)"
        }
    }
}

public enum BodyPhotosModel {
    /// Una foto va bene se c'è una sola persona e si vede intera: spalle e
    /// caviglie sempre; di fronte anche il viso (di spalle non si vede).
    /// - people: persone contate da Vision (i "soggetti" dello scontorno
    ///   includono anche borse, sedie, piante: non bastano a dire "più persone").
    public static func validate(_ cutout: Cutout, pose: Pose?, view: BodyView, people: Int) -> PhotoCheck {
        if cutout.instanceCount == 0 || people == 0 { return .noPerson }
        if people > 1 { return .multiplePeople }
        guard let points = pose?.points else { return .notFullBody }
        let hasShoulder = points[.leftShoulder] != nil || points[.rightShoulder] != nil
        let hasAnkle = points[.leftAnkle] != nil || points[.rightAnkle] != nil
        let hasFace = points[.nose] != nil || points[.neck] != nil
        guard hasShoulder, hasAnkle else { return .notFullBody }
        if view == .front, !hasFace { return .notFullBody }
        if let seen = seenView(points), seen != view { return .wrongView(seen: seen, wanted: view) }
        return .ok
    }

    /// Da che lato è stata fatta la foto, dalle spalle: di lato si
    /// sovrappongono (meno di un terzo del busto); davanti Vision mette la
    /// spalla sinistra a destra nell'immagine, di spalle a sinistra. nil se
    /// mancano spalle o fianchi.
    static func seenView(_ points: [Joint: CGPoint]) -> BodyView? {
        guard let left = points[.leftShoulder], let right = points[.rightShoulder],
              let hip = points[.leftHip] ?? points[.rightHip] else { return nil }
        let torso = hip.y - (left.y + right.y) / 2
        guard torso > 0 else { return nil }
        if abs(left.x - right.x) < 0.35 * torso { return .side }
        return left.x > right.x ? .front : .back
    }
}
