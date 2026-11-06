import Foundation

/// `Math.round` di JavaScript: la metà va verso +∞. `.rounded()` di Swift la allontana da zero,
/// e a -2,5 gradi darebbe un numero diverso dal sito.
public func jsRound(_ value: Double) -> Int { Int((value + 0.5).rounded(.down)) }

/// Armonia dei colori di un outfit, come src/utils/colorHarmony.js.
public enum ColorHarmony {
    public struct HSL: Equatable, Sendable {
        public let h: Int
        public let s: Int
        public let l: Int
    }

    static func hsl(hex: String) -> HSL {
        let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = Int(clean, radix: 16) ?? 0
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        let high = max(r, g, b)
        let low = min(r, g, b)
        let delta = high - low
        let l = (high + low) / 2
        var h = 0.0
        var s = 0.0
        if delta != 0 {
            s = l > 0.5 ? delta / (2 - high - low) : delta / (high + low)
            if high == r {
                h = ((g - b) / delta + (g < b ? 6 : 0)) * 60
            } else if high == g {
                h = ((b - r) / delta + 2) * 60
            } else {
                h = ((r - g) / delta + 4) * 60
            }
        }
        return HSL(h: jsRound(h), s: jsRound(s * 100), l: jsRound(l * 100))
    }

    private static func isNeutral(_ hex: String) -> Bool {
        let color = hsl(hex: hex)
        return color.s < 15 || color.l < 10 || color.l > 95
    }

    private static func hueDistance(_ a: Int, _ b: Int) -> Int {
        let difference = abs(a - b)
        return difference > 180 ? 360 - difference : difference
    }

    public static func areCompatible(_ first: String, _ second: String) -> Bool {
        if isNeutral(first) || isNeutral(second) { return true }
        let distance = hueDistance(hsl(hex: first).h, hsl(hex: second).h)
        return distance <= 30 || (distance >= 100 && distance <= 180)
    }

    /// Da 0 a 100.
    public static func score(_ colors: [String]) -> Int {
        var unique: [String] = []
        for color in colors where !unique.contains(color) { unique.append(color) }
        guard unique.count > 1 else { return 100 }

        var pairs = 0.0
        var compatiblePairs = 0.0
        var hueTotal = 0.0
        for i in unique.indices {
            for j in unique.indices where j > i {
                let (first, second) = (unique[i], unique[j])
                pairs += 1
                let compatible = areCompatible(first, second)
                if compatible { compatiblePairs += 1 }
                if isNeutral(first) || isNeutral(second) {
                    hueTotal += 90
                    continue
                }
                let distance = hueDistance(hsl(hex: first).h, hsl(hex: second).h)
                if distance <= 15 {
                    hueTotal += 95
                } else if distance <= 30 {
                    hueTotal += 85
                } else if distance >= 165 {
                    hueTotal += 80
                } else if distance >= 110 && distance <= 130 {
                    hueTotal += 75
                } else if distance >= 140 && distance <= 160 {
                    hueTotal += 70
                } else {
                    hueTotal += compatible ? 60 : 25
                }
            }
        }
        let compatibility = compatiblePairs / pairs * 100
        let hue = hueTotal / pairs
        let chromatic = unique.filter { !isNeutral($0) }.count
        let penalty = chromatic > 3 ? Double(chromatic - 3) * 10 : 0
        return max(0, min(100, jsRound(compatibility * 0.4 + hue * 0.6 - penalty)))
    }
}
