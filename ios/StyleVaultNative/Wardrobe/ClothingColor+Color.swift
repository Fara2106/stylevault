import StyleVaultCore
import SwiftUI

extension ClothingColor {
    var color: Color {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0xCCCCCC
        return Color(red: Double((value >> 16) & 0xFF) / 255,
                     green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }
}
