import Foundation

public struct RGB: Equatable, Sendable {
    public var r: Int
    public var g: Int
    public var b: Int

    public init(r: Int, g: Int, b: Int) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct Lab: Equatable, Sendable {
    public var L: Double
    public var a: Double
    public var b: Double

    public init(L: Double, a: Double, b: Double) {
        self.L = L
        self.a = a
        self.b = b
    }
}

/// sRGB, Lab (D65) e distanza percettiva CIE76: l'unico posto con questa matematica.
public enum ColorLab {
    public static func rgb(hex: String) -> RGB? {
        var digits = hex
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let n = Int(digits, radix: 16) else { return nil }
        return RGB(r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255)
    }

    public static func hex(_ c: RGB) -> String {
        String(format: "#%02x%02x%02x", c.r, c.g, c.b)
    }

    private static func linear(_ c: Int) -> Double {
        let v = Double(c) / 255
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    private static func srgb(_ v: Double) -> Double {
        255 * (v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055)
    }

    public static func lab(_ c: RGB) -> Lab {
        let (R, G, B) = (linear(c.r), linear(c.g), linear(c.b))
        let X = (0.4124564 * R + 0.3575761 * G + 0.1804375 * B) / 0.95047
        let Y = 0.2126729 * R + 0.7151522 * G + 0.072175 * B
        let Z = (0.0193339 * R + 0.119192 * G + 0.9503041 * B) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116 }
        let (fx, fy, fz) = (f(X), f(Y), f(Z))
        return Lab(L: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    public static func lab(hex: String) -> Lab? {
        rgb(hex: hex).map { lab($0) }
    }

    public static func rgb(_ value: Lab) -> RGB {
        let fy = (value.L + 16) / 116
        let fx = fy + value.a / 500
        let fz = fy - value.b / 200
        func inv(_ t: Double) -> Double { t * t * t > 0.008856 ? t * t * t : (t - 16.0 / 116) / 7.787 }
        let (X, Y, Z) = (inv(fx) * 0.95047, inv(fy), inv(fz) * 1.08883)
        let R = 3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z
        let G = -0.969266 * X + 1.8760108 * Y + 0.041556 * Z
        let B = 0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z
        func clamp(_ v: Double) -> Int { max(0, min(255, Int(srgb(max(v, 0)).rounded()))) }
        return RGB(r: clamp(R), g: clamp(G), b: clamp(B))
    }

    public static func deltaE(_ x: Lab, _ y: Lab) -> Double {
        let (dL, da, db) = (x.L - y.L, x.a - y.a, x.b - y.b)
        return (dL * dL + da * da + db * db).squareRoot()
    }

    /// Colore di una regione: ordina per L, scarta gli estremi (ombre e riflessi) e prende la mediana.
    public static func representative(_ pixels: [RGB], trim: Double = 0.15) -> String? {
        guard !pixels.isEmpty else { return nil }
        let labs = pixels.map { lab($0) }.sorted { $0.L < $1.L }
        let cut = Int(Double(labs.count) * trim)
        let kept = labs[cut..<(labs.count - cut)]
        guard !kept.isEmpty else { return nil }
        func median(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            let middle = sorted.count / 2
            return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
        }
        return hex(rgb(Lab(L: median(kept.map(\.L)), a: median(kept.map(\.a)), b: median(kept.map(\.b)))))
    }
}
