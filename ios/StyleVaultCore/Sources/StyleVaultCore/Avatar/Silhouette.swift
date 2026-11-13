import CoreGraphics

/// Maschera alfa di uno scontorno (pixel, origine in alto a sinistra): per
/// misurare la sagoma vera riga per riga invece del suo riquadro, che di lato
/// si allarga col passo e davanti con le braccia.
struct Silhouette {
    let width: Int
    let height: Int
    let alpha: [UInt8]

    init(width: Int, height: Int, alpha: [UInt8]) {
        self.width = width
        self.height = height
        self.alpha = alpha
    }

    init(_ image: CGImage) {
        let channel = PersonCutout.alphaChannel(image)
        self.init(width: channel.width, height: channel.height, alpha: channel.pixels)
    }

    private func opaque(_ x: Int, _ y: Int) -> Bool { alpha[y * width + x] >= 26 }

    /// Il tratto pieno della riga che contiene x (o il più vicino), unendo i
    /// buchi stretti come quello tra braccio e busto.
    func run(row: CGFloat, near x: CGFloat, mergingGaps gap: CGFloat) -> ClosedRange<CGFloat>? {
        let y = min(max(Int(row), 0), height - 1)
        var runs = [ClosedRange<Int>]()
        var start: Int?
        for col in 0...width {
            let full = col < width && opaque(col, y)
            if full, start == nil { start = col }
            if !full, let s = start {
                if let last = runs.last, CGFloat(s - last.upperBound - 1) <= gap {
                    runs[runs.count - 1] = last.lowerBound...(col - 1)
                } else {
                    runs.append(s...(col - 1))
                }
                start = nil
            }
        }
        let target = Int(x)
        let distance = { (r: ClosedRange<Int>) in r.contains(target) ? 0 : min(abs(r.lowerBound - target), abs(r.upperBound - target)) }
        return runs.min { distance($0) < distance($1) }.map { CGFloat($0.lowerBound)...CGFloat($0.upperBound) }
    }

    /// L'ultima riga piena nelle colonne date, a partire da `from` (la pianta del piede).
    func lowestRow(columns: ClosedRange<CGFloat>, from: CGFloat) -> CGFloat? {
        let x0 = max(Int(columns.lowerBound), 0), x1 = min(Int(columns.upperBound), width - 1)
        guard x0 <= x1 else { return nil }
        for y in stride(from: height - 1, through: max(Int(from), 0), by: -1) {
            if (x0...x1).contains(where: { opaque($0, y) }) { return CGFloat(y) }
        }
        return nil
    }

    /// Per una scarpa vista di lato: la punta è il lato più basso (il tallone
    /// ha il collarino).
    var toeOnLeft: Bool {
        func meanHeight(_ cols: Range<Int>) -> Double {
            let heights = cols.map { x in (0..<height).filter { opaque(x, $0) }.count }
            return Double(heights.reduce(0, +)) / Double(max(heights.count, 1))
        }
        let quarter = max(width / 4, 1)
        return meanHeight(0..<quarter) < meanHeight((width - quarter)..<width)
    }
}
