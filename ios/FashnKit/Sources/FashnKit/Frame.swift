import Foundation

/// Come una foto entra nel riquadro del modello: quanto si ridimensiona e quanti bordi neri servono.
/// Stessi conti di `AspectPreserveResize` e `PadToShape` della pipeline originale (interi troncati, bordo in più a destra e in basso).
public struct Frame: Equatable, Sendable {
    public let targetWidth: Int
    public let targetHeight: Int
    /// La misura della foto dentro il riquadro, senza bordi.
    public let width: Int
    public let height: Int
    public let left: Int
    public let top: Int

    public var right: Int { targetWidth - width - left }
    public var bottom: Int { targetHeight - height - top }

    public init(sourceWidth: Int, sourceHeight: Int, targetWidth: Int = FashnModel.width, targetHeight: Int = FashnModel.height) {
        let scale = min(Double(targetWidth) / Double(sourceWidth), Double(targetHeight) / Double(sourceHeight))
        let w = scale == 1 ? sourceWidth : Int(scale * Double(sourceWidth))
        let h = scale == 1 ? sourceHeight : Int(scale * Double(sourceHeight))
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        width = min(max(w, 1), targetWidth)
        height = min(max(h, 1), targetHeight)
        left = (targetWidth - width) / 2
        top = (targetHeight - height) / 2
    }

    /// La misura a cui portare una foto prima di cercarne la posa: il lato lungo a 864 al massimo, mai ingrandita.
    public static func preResized(width: Int, height: Int, maxSide: Int = FashnModel.height) -> (width: Int, height: Int) {
        let scale = min(Double(maxSide) / Double(width), Double(maxSide) / Double(height))
        guard scale < 1 else { return (width, height) }
        return (max(1, Int(scale * Double(width))), max(1, Int(scale * Double(height))))
    }
}

/// Le misure fisse del modello convertito.
public enum FashnModel {
    public static let width = 576
    public static let height = 864
    public static let channels = 3
}

/// La categoria del capo, con il numero che il modello si aspetta (`CATEGORY_TO_LABEL`).
public enum GarmentCategory: Int, CaseIterable, Sendable {
    case tops = 1, bottoms = 2, onePieces = 3
}
