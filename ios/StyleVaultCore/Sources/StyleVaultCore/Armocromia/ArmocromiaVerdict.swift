import Foundation

/// Ciò che resta salvato in `Profile.armocromia`. Si legge anche il formato del sito.
public struct ArmocromiaVerdict: Equatable, Sendable {
    public var season: String
    public var detected: FaceColors
    public var confidence: Double
    /// Stagione scelta dal menu, senza analisi: non si mostra nessuna affidabilità.
    public var chosenByHand: Bool
    public var updatedAt: Date

    public init(season: String, detected: FaceColors = FaceColors(), confidence: Double = 0,
                chosenByHand: Bool = false, updatedAt: Date = .now) {
        self.season = season
        self.detected = detected
        self.confidence = confidence
        self.chosenByHand = chosenByHand
        self.updatedAt = updatedAt
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data?) -> ArmocromiaVerdict? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(ArmocromiaVerdict.self, from: data)
    }
}

extension ArmocromiaVerdict: Codable {
    private enum CodingKeys: String, CodingKey { case season, detected, confidence, chosenByHand, updatedAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        season = try c.decode(String.self, forKey: .season)
        detected = try c.decodeIfPresent(FaceColors.self, forKey: .detected) ?? FaceColors()
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        chosenByHand = try c.decodeIfPresent(Bool.self, forKey: .chosenByHand) ?? false
        let text = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        updatedAt = Self.date(from: text) ?? .now
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(season, forKey: .season)
        try c.encode(detected, forKey: .detected)
        try c.encode(confidence, forKey: .confidence)
        try c.encode(chosenByHand, forKey: .chosenByHand)
        try c.encode(Self.text(from: updatedAt), forKey: .updatedAt)
    }

    private static func date(from text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    private static func text(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
