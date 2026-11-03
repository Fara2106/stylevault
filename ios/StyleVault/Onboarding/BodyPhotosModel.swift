import Foundation

/// Le 3 foto del corpo: davanti (è la foto di riferimento del profilo), lato, spalle.
enum BodyView: String, CaseIterable, Identifiable {
    case front, side, back
    var id: String { rawValue }

    var title: String {
        switch self {
        case .front: return "Davanti"
        case .side: return "Di lato"
        case .back: return "Di spalle"
        }
    }

    var guide: String {
        switch self {
        case .front: return "In piedi, frontale, braccia un po' staccate dal corpo. Dalla testa ai piedi, con luce naturale."
        case .side: return "Girati di 90°, braccia lungo i fianchi. Sempre dalla testa ai piedi."
        case .back: return "Di spalle, stessa posizione della foto davanti. Dalla testa ai piedi."
        }
    }
}

enum PhotoCheck: Equatable {
    case ok, noPerson, multiplePeople, notFullBody

    var message: String? {
        switch self {
        case .ok: return nil
        case .noPerson: return "Non vedo nessuno nella foto: riprova inquadrandoti bene."
        case .multiplePeople: return "Nella foto ci sono più persone: serve solo tu."
        case .notFullBody: return "Non ti vedo dalla testa ai piedi: allontanati un po' e riprova."
        }
    }
}

enum BodyPhotosModel {
    /// Una foto va bene se c'è una sola persona e si vede intera: spalle e
    /// caviglie sempre; di fronte anche il viso (di spalle non si vede).
    static func validate(_ cutout: Cutout, pose: Pose?, view: BodyView) -> PhotoCheck {
        if cutout.instanceCount == 0 { return .noPerson }
        if cutout.instanceCount > 1 { return .multiplePeople }
        guard let points = pose?.points else { return .notFullBody }
        let hasShoulder = points[.leftShoulder] != nil || points[.rightShoulder] != nil
        let hasAnkle = points[.leftAnkle] != nil || points[.rightAnkle] != nil
        let hasFace = points[.nose] != nil || points[.neck] != nil
        guard hasShoulder, hasAnkle else { return .notFullBody }
        if view == .front, !hasFace { return .notFullBody }
        return .ok
    }

    /// Le viste ancora da fotografare, nell'ordine davanti → lato → spalle.
    static func needsOnboarding(existing: [BodyView: URL]) -> [BodyView] {
        BodyView.allCases.filter { existing[$0] == nil }
    }
}
