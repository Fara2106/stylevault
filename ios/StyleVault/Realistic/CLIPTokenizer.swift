import Foundation

/// Tokenizzatore BPE di CLIP (lo stesso di `CLIPTokenizer` di transformers),
/// per i due codificatori di testo di Mobile-VTON. Solo Foundation: compila
/// anche su macOS. Non applica `ftfy` né `html.unescape` (inutili sulle
/// didascalie dell'app, che sono testo semplice).
struct CLIPTokenizer {
    static let contextLength = 77
    static let startToken: Int32 = 49406
    static let endToken: Int32 = 49407

    enum LoadError: Error { case badVocab, unknownPadToken(String) }

    private let vocab: [String: Int32]
    private let ranks: [String: Int]          // "a b" -> rango del merge
    private let padID: Int32
    private let byteEncoder: [UInt8: Character]
    private let splitter: NSRegularExpression

    /// `padToken`: `"<|endoftext|>"` (primo codificatore) oppure `"!"` (secondo).
    init(vocab: URL, merges: URL, padToken: String) throws {
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: vocab))
        guard let dict = raw as? [String: Int] else { throw LoadError.badVocab }
        self.vocab = dict.mapValues { Int32($0) }
        guard let pad = self.vocab[padToken] else { throw LoadError.unknownPadToken(padToken) }
        padID = pad

        // Come CLIP: salta l'intestazione e tiene 49152 − 256 − 2 merge.
        let lines = try String(contentsOf: merges, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
        var ranks: [String: Int] = [:]
        for (i, line) in lines.dropFirst().prefix(49152 - 256 - 2).enumerated() {
            ranks[String(line)] = i
        }
        self.ranks = ranks

        byteEncoder = Self.makeByteEncoder()
        splitter = try NSRegularExpression(
            pattern: #"<\|startoftext\|>|<\|endoftext\|>|'s|'t|'re|'ve|'m|'ll|'d|[\p{L}]+|[\p{N}]|[^\s\p{L}\p{N}]+"#)
    }

    /// Sempre 77 id: BOS, token (al massimo 75), EOS, poi il riempimento.
    func ids(_ text: String) -> [Int32] {
        let cleaned = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
        let ns = cleaned as NSString
        var body: [Int32] = []
        for m in splitter.matches(in: cleaned, range: NSRange(location: 0, length: ns.length)) {
            let piece = ns.substring(with: m.range)
            if piece == "<|startoftext|>" { body.append(Self.startToken); continue }
            if piece == "<|endoftext|>" { body.append(Self.endToken); continue }
            let mapped = piece.utf8.map { String(byteEncoder[$0]!) }
            for symbol in bpe(mapped) {
                if let id = vocab[symbol] { body.append(id) }
            }
        }
        let limit = Self.contextLength
        var out = [Self.startToken] + body.prefix(limit - 2) + [Self.endToken]
        out += Array(repeating: padID, count: limit - out.count)
        return out
    }

    /// Fonde le coppie di simboli per rango crescente; l'ultimo simbolo porta `</w>`.
    private func bpe(_ chars: [String]) -> [String] {
        var word = chars
        word[word.count - 1] += "</w>"
        while word.count > 1 {
            var best: (rank: Int, index: Int)?
            for i in 0..<(word.count - 1) {
                if let r = ranks[word[i] + " " + word[i + 1]], best == nil || r < best!.rank {
                    best = (r, i)
                }
            }
            guard let (_, _) = best else { break }
            let first = word[best!.index], second = word[best!.index + 1]
            var merged: [String] = []
            var i = 0
            while i < word.count {
                if i < word.count - 1, word[i] == first, word[i + 1] == second {
                    merged.append(first + second); i += 2
                } else {
                    merged.append(word[i]); i += 1
                }
            }
            word = merged
        }
        return word
    }

    /// `bytes_to_unicode` di GPT-2: ogni byte diventa un carattere stampabile.
    private static func makeByteEncoder() -> [UInt8: Character] {
        var bs = Array(33...126) + Array(161...172) + Array(174...255)
        var cs = bs
        var n = 0
        for b in 0..<256 where !bs.contains(b) {
            bs.append(b); cs.append(256 + n); n += 1
        }
        var map: [UInt8: Character] = [:]
        for (b, c) in zip(bs, cs) { map[UInt8(b)] = Character(UnicodeScalar(UInt32(c))!) }
        return map
    }
}
