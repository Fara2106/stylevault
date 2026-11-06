import Compression
import Foundation

public enum ZipError: Error, Equatable {
    case notAZip, unsupported, damaged, tooLarge
}

private extension Data {
    mutating func append16(_ value: Int) { append(contentsOf: [UInt8(value & 255), UInt8((value >> 8) & 255)]) }
    mutating func append32(_ value: UInt32) {
        append16(Int(value & 0xFFFF))
        append16(Int(value >> 16))
    }

    func read16(_ offset: Int) -> Int {
        Int(self[startIndex + offset]) | Int(self[startIndex + offset + 1]) << 8
    }

    func read32(_ offset: Int) -> Int { read16(offset) | read16(offset + 2) << 16 }
}

private enum CRC32 {
    static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        (0..<8).reduce(UInt32(index)) { value, _ in
            value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
    }

    static func checksum(_ data: Data) -> UInt32 {
        ~data.reduce(UInt32.max) { table[Int(($0 ^ UInt32($1)) & 255)] ^ ($0 >> 8) }
    }
}

/// Scrive uno zip standard senza compressione: le foto sono già JPEG e non guadagnerebbero nulla.
public final class ZipWriter {
    private struct Entry {
        let name: Data
        let crc: UInt32
        let size: UInt32
        let offset: UInt32
    }

    private let handle: FileHandle
    private var entries: [Entry] = []
    private var offset: UInt64 = 0

    public init(url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
    }

    private func write(_ data: Data) throws {
        try handle.write(contentsOf: data)
        offset += UInt64(data.count)
    }

    public func add(name: String, data: Data) throws {
        guard offset + UInt64(data.count) < UInt64(UInt32.max) else { throw ZipError.tooLarge }
        let entry = Entry(name: Data(name.utf8), crc: CRC32.checksum(data), size: UInt32(data.count), offset: UInt32(offset))
        var header = Data()
        header.append32(0x0403_4B50)
        header.append16(20) // versione minima
        header.append16(0x0800) // nomi in UTF-8
        header.append16(0) // nessuna compressione
        header.append16(0) // ora
        header.append16(0x21) // data: 1 gennaio 1980
        header.append32(entry.crc)
        header.append32(entry.size)
        header.append32(entry.size)
        header.append16(entry.name.count)
        header.append16(0)
        header.append(entry.name)
        try write(header)
        try write(data)
        entries.append(entry)
    }

    public func close() throws {
        let start = offset
        for entry in entries {
            var record = Data()
            record.append32(0x0201_4B50)
            record.append16(20)
            record.append16(20)
            record.append16(0x0800)
            record.append16(0)
            record.append16(0)
            record.append16(0x21)
            record.append32(entry.crc)
            record.append32(entry.size)
            record.append32(entry.size)
            record.append16(entry.name.count)
            record.append(contentsOf: [UInt8](repeating: 0, count: 12)) // extra, commento, disco, attributi
            record.append32(entry.offset)
            record.append(entry.name)
            try write(record)
        }
        var end = Data()
        end.append32(0x0605_4B50)
        end.append16(0)
        end.append16(0)
        end.append16(entries.count)
        end.append16(entries.count)
        end.append32(UInt32(offset - start))
        end.append32(UInt32(start))
        end.append16(0)
        try write(end)
        try handle.close()
    }
}

/// Legge uno zip, senza compressione o con deflate. Si legge per nome: nulla viene estratto su disco.
public final class ZipReader {
    private struct Entry {
        let method: Int
        let compressed: Int
        let size: Int
        let offset: Int
    }

    /// Più grande di qualsiasi foto: ferma gli zip che si gonfiano a dismisura.
    private static let entryLimit = 256 * 1024 * 1024

    private let file: Data
    private var entries: [String: Entry] = [:]

    public var names: [String] { Array(entries.keys) }

    public init(url: URL) throws {
        file = try Data(contentsOf: url, options: .alwaysMapped)
        guard let end = Self.endRecord(in: file) else { throw ZipError.notAZip }
        let count = file.read16(end + 10)
        var position = file.read32(end + 16)
        for _ in 0..<count {
            guard position + 46 <= file.count, file.read32(position) == 0x0201_4B50 else { throw ZipError.damaged }
            let (nameLength, extra, comment) = (file.read16(position + 28), file.read16(position + 30), file.read16(position + 32))
            guard position + 46 + nameLength <= file.count else { throw ZipError.damaged }
            let range = (file.startIndex + position + 46)..<(file.startIndex + position + 46 + nameLength)
            entries[String(decoding: file[range], as: UTF8.self)] = Entry(
                method: file.read16(position + 10), compressed: file.read32(position + 20),
                size: file.read32(position + 24), offset: file.read32(position + 42))
            position += 46 + nameLength + extra + comment
        }
    }

    private static func endRecord(in file: Data) -> Int? {
        guard file.count >= 22 else { return nil }
        let lowest = max(0, file.count - 22 - 65_535)
        for position in stride(from: file.count - 22, through: lowest, by: -1)
        where file.read32(position) == 0x0605_4B50 {
            return position
        }
        return nil
    }

    public func data(name: String) throws -> Data? {
        guard let entry = entries[name] else { return nil }
        guard entry.size <= Self.entryLimit else { throw ZipError.tooLarge }
        guard entry.offset + 30 <= file.count, file.read32(entry.offset) == 0x0403_4B50 else { throw ZipError.damaged }
        let start = entry.offset + 30 + file.read16(entry.offset + 26) + file.read16(entry.offset + 28)
        guard start + entry.compressed <= file.count else { throw ZipError.damaged }
        let raw = file[(file.startIndex + start)..<(file.startIndex + start + entry.compressed)]
        switch entry.method {
        case 0: return Data(raw)
        case 8: return try Self.inflate(raw, size: entry.size)
        default: throw ZipError.unsupported
        }
    }

    private static func inflate(_ raw: Data, size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { target in
            raw.withUnsafeBytes { source in
                compression_decode_buffer(target.bindMemory(to: UInt8.self).baseAddress!, size,
                                          source.bindMemory(to: UInt8.self).baseAddress!, raw.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw ZipError.damaged }
        return output
    }
}
