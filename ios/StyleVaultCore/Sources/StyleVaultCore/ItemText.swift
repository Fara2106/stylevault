import Foundation

public enum PriceInput: Equatable, Sendable {
    case empty
    case value(Double)
    case invalid
}

public enum ItemText {
    /// L'iniziale del segnaposto di un capo senza foto.
    public static func placeholderInitial(_ name: String?) -> String {
        guard let first = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).first else { return "·" }
        return String(first).uppercased(with: Locale(identifier: "it"))
    }

    /// Il prezzo digitato: accetta virgola o punto, una volta sola.
    public static func parsePrice(_ text: String) -> PriceInput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard normalized.filter({ $0 == "." }).count <= 1,
              let value = Double(normalized), value.isFinite, value >= 0 else { return .invalid }
        return .value(value)
    }
}
