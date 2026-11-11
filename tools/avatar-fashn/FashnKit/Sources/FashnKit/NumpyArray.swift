import Foundation

/// Un file .npy di numpy: forma e dati grezzi (little endian, riga per riga). Serve a confrontarsi con gli ingressi
/// catturati dalla pipeline originale.
public struct NumpyArray {
    public let shape: [Int]
    public let descr: String
    public let data: Data

    public init(contentsOf url: URL) throws {
        let raw = try Data(contentsOf: url, options: .mappedIfSafe)
        guard raw.count > 12, raw[0] == 0x93, String(data: raw[1..<6], encoding: .ascii) == "NUMPY" else {
            throw FashnError.image("\(url.lastPathComponent): non è un .npy")
        }
        let major = raw[6]
        let headerLength = major == 1 ? Int(raw[8]) | Int(raw[9]) << 8
            : Int(raw[8]) | Int(raw[9]) << 8 | Int(raw[10]) << 16 | Int(raw[11]) << 24
        let start = major == 1 ? 10 : 12
        guard let header = String(data: raw[start..<(start + headerLength)], encoding: .ascii) else {
            throw FashnError.image("\(url.lastPathComponent): intestazione illeggibile")
        }
        guard !header.contains("'fortran_order': True") else { throw FashnError.image("ordine Fortran non gestito") }
        func field(_ name: String, until end: Character) -> String? {
            guard let range = header.range(of: "'\(name)':") else { return nil }
            let rest = header[range.upperBound...].drop { $0 == " " || $0 == "'" || $0 == "(" }
            return String(rest.prefix { $0 != end })
        }
        descr = field("descr", until: "'") ?? ""
        shape = (field("shape", until: ")") ?? "").split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        data = raw.subdata(in: (start + headerLength)..<raw.count)
    }

    /// I numeri del primo elemento del lotto (la metà con la guida), come Float.
    public func firstBatchFloats() throws -> [Float] {
        guard descr == "<f4" else { throw FashnError.image("atteso <f4, trovato \(descr)") }
        let count = shape.dropFirst().reduce(1, *)
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self).prefix(count)) }
    }

    public func firstInteger() throws -> Int {
        switch descr {
        case "<i8": return data.withUnsafeBytes { Int($0.loadUnaligned(as: Int64.self)) }
        case "<i4": return data.withUnsafeBytes { Int($0.loadUnaligned(as: Int32.self)) }
        default: throw FashnError.image("intero atteso, trovato \(descr)")
        }
    }
}
