import Foundation

/// Una tela a un canale, senza sfumature ai bordi: il disegno della posa che FASHN si aspetta è fatto così.
public struct GrayCanvas: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, fill: UInt8 = 0) {
        self.width = width
        self.height = height
        pixels = [UInt8](repeating: fill, count: width * height)
    }

    public subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }

    private func clampedRows(_ low: Double, _ high: Double) -> ClosedRange<Int>? {
        let a = max(0, Int(low.rounded(.down))), b = min(height - 1, Int(high.rounded(.up)))
        return a <= b ? a...b : nil
    }

    private func clampedColumns(_ low: Double, _ high: Double) -> ClosedRange<Int>? {
        let a = max(0, Int(low.rounded(.down))), b = min(width - 1, Int(high.rounded(.up)))
        return a <= b ? a...b : nil
    }

    /// Cerchio pieno, come `cv2.circle(..., thickness=-1)`.
    public mutating func fillCircle(x: Int, y: Int, radius: Int, value: UInt8) {
        let r = Double(radius)
        guard let rows = clampedRows(Double(y) - r, Double(y) + r), let columns = clampedColumns(Double(x) - r, Double(x) + r) else { return }
        let limit = (r + 0.5) * (r + 0.5)
        for py in rows {
            for px in columns {
                let dx = Double(px - x), dy = Double(py - y)
                if dx * dx + dy * dy <= limit { self[px, py] = value }
            }
        }
    }

    /// Ellisse piena ruotata: l'arto di `draw_bodypose` (`ellipse2Poly` + `fillConvexPoly`).
    public mutating func fillEllipse(centerX: Int, centerY: Int, semiMajor: Int, semiMinor: Int, degrees: Int, value: UInt8) {
        let a = max(Double(semiMajor), 0.5), b = max(Double(semiMinor), 0.5)
        let reach = max(a, b) + 1
        guard let rows = clampedRows(Double(centerY) - reach, Double(centerY) + reach),
              let columns = clampedColumns(Double(centerX) - reach, Double(centerX) + reach) else { return }
        let angle = Double(degrees) * .pi / 180
        let cosA = cos(angle), sinA = sin(angle)
        for py in rows {
            for px in columns {
                let dx = Double(px - centerX), dy = Double(py - centerY)
                let u = dx * cosA + dy * sinA, v = -dx * sinA + dy * cosA
                if (u * u) / (a * a) + (v * v) / (b * b) <= 1 { self[px, py] = value }
            }
        }
    }

    /// Segmento spesso `thickness` pixel, come `cv2.line`.
    public mutating func drawLine(fromX x1: Int, fromY y1: Int, toX x2: Int, toY y2: Int, thickness: Int, value: UInt8) {
        let half = Double(thickness) / 2
        guard let rows = clampedRows(Double(min(y1, y2)) - half, Double(max(y1, y2)) + half),
              let columns = clampedColumns(Double(min(x1, x2)) - half, Double(max(x1, x2)) + half) else { return }
        let ax = Double(x1), ay = Double(y1), bx = Double(x2), by = Double(y2)
        let lengthSquared = (bx - ax) * (bx - ax) + (by - ay) * (by - ay)
        for py in rows {
            for px in columns {
                let x = Double(px), y = Double(py)
                let t = lengthSquared == 0 ? 0 : min(1, max(0, ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / lengthSquared))
                let dx = x - (ax + t * (bx - ax)), dy = y - (ay + t * (by - ay))
                if dx * dx + dy * dy <= half * half { self[px, py] = value }
            }
        }
    }

    /// Ridimensiona scegliendo il pixel più vicino (`INTER_NEAREST_EXACT`): i grigi del disegno non si mescolano.
    public func resizedNearest(width newWidth: Int, height newHeight: Int) -> GrayCanvas {
        guard newWidth != width || newHeight != height else { return self }
        var out = GrayCanvas(width: newWidth, height: newHeight)
        let scaleX = Double(width) / Double(newWidth), scaleY = Double(height) / Double(newHeight)
        for y in 0..<newHeight {
            let sy = min(height - 1, Int((Double(y) + 0.5) * scaleY))
            for x in 0..<newWidth {
                out[x, y] = self[min(width - 1, Int((Double(x) + 0.5) * scaleX)), sy]
            }
        }
        return out
    }

    /// Aggiunge bordi neri fino alla misura data, con il contenuto al centro.
    public func padded(to frame: Frame) -> GrayCanvas {
        var out = GrayCanvas(width: frame.targetWidth, height: frame.targetHeight)
        for y in 0..<height {
            let row = (y + frame.top) * frame.targetWidth + frame.left
            out.pixels.replaceSubrange(row..<(row + width), with: pixels[(y * width)..<((y + 1) * width)])
        }
        return out
    }
}
