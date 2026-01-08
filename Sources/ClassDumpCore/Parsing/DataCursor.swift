import Foundation

public enum DataCursorError: Error, Equatable, Sendable {
    case offsetOutOfBounds(offset: Int, dataCount: Int)
    case readOutOfBounds(offset: Int, length: Int, dataCount: Int)
    case invalidCString
    case invalidStringEncoding
    case invalidPointerSize(UInt)
    case leb128Malformed
    case leb128TooLarge
}

public struct DataCursor: Sendable {
    public let data: Data
    public private(set) var offset: Int

    public init(data: Data, offset: Int = 0) throws(DataCursorError) {
        self.data = data
        self.offset = 0
        try seek(to: offset)
    }

    public var remaining: Int {
        data.count - offset
    }

    public var isAtEnd: Bool {
        offset >= data.count
    }

    public mutating func seek(to newOffset: Int) throws(DataCursorError) {
        guard newOffset >= 0 else {
            throw .offsetOutOfBounds(offset: newOffset, dataCount: data.count)
        }
        guard newOffset <= data.count else {
            throw .offsetOutOfBounds(offset: newOffset, dataCount: data.count)
        }
        offset = newOffset
    }

    public mutating func advance(by length: Int) throws(DataCursorError) {
        try requireAvailable(length)
        offset += length
    }

    public mutating func readByte() throws(DataCursorError) -> UInt8 {
        try requireAvailable(1)
        let byte = data[offset]
        offset += 1
        return byte
    }

    public mutating func readLittleInt16() throws(DataCursorError) -> UInt16 {
        let raw: UInt16 = try readInteger()
        return UInt16(littleEndian: raw)
    }

    public mutating func readLittleInt32() throws(DataCursorError) -> UInt32 {
        let raw: UInt32 = try readInteger()
        return UInt32(littleEndian: raw)
    }

    public mutating func readLittleInt64() throws(DataCursorError) -> UInt64 {
        let raw: UInt64 = try readInteger()
        return UInt64(littleEndian: raw)
    }

    public mutating func readBigInt16() throws(DataCursorError) -> UInt16 {
        let raw: UInt16 = try readInteger()
        return UInt16(bigEndian: raw)
    }

    public mutating func readBigInt32() throws(DataCursorError) -> UInt32 {
        let raw: UInt32 = try readInteger()
        return UInt32(bigEndian: raw)
    }

    public mutating func readBigInt64() throws(DataCursorError) -> UInt64 {
        let raw: UInt64 = try readInteger()
        return UInt64(bigEndian: raw)
    }

    public mutating func readLittleFloat32() throws(DataCursorError) -> Float {
        Float(bitPattern: try readLittleInt32())
    }

    public mutating func readBigFloat32() throws(DataCursorError) -> Float {
        Float(bitPattern: try readBigInt32())
    }

    public mutating func readLittleFloat64() throws(DataCursorError) -> Double {
        Double(bitPattern: try readLittleInt64())
    }

    public mutating func appendBytes(length: Int, into data: inout Data) throws(DataCursorError) {
        try requireAvailable(length)
        data.append(self.data[offset..<(offset + length)])
        offset += length
    }

    public mutating func readBytes(length: Int, into buffer: UnsafeMutableRawPointer) throws(DataCursorError) {
        try requireAvailable(length)
        self.data.copyBytes(
            to: buffer.assumingMemoryBound(to: UInt8.self),
            from: offset..<(offset + length))
        offset += length
    }

    public mutating func readBytes(length: Int) throws(DataCursorError) -> Data {
        try requireAvailable(length)
        let slice = data[offset..<(offset + length)]
        offset += length
        return Data(slice)
    }

    public mutating func readCString(encoding: String.Encoding = .ascii) throws(DataCursorError) -> String {
        guard offset < data.count else {
            throw .invalidCString
        }
        let range = offset..<data.count
        guard let zeroIndex = data[range].firstIndex(of: 0) else {
            throw .invalidCString
        }
        let length = data.distance(from: data.startIndex, to: zeroIndex) - offset
        return try readString(length: length, encoding: encoding)
    }

    public mutating func readString(length: Int, encoding: String.Encoding) throws(DataCursorError) -> String {
        try requireAvailable(length)
        let range = offset..<(offset + length)
        let slice = data[range]
        if encoding == .ascii {
            let trimmed = slice.prefix { $0 != 0 }
            guard let string = String(bytes: trimmed, encoding: encoding) else {
                throw .invalidStringEncoding
            }
            offset += length
            return string
        }

        guard let string = String(data: Data(slice), encoding: encoding) else {
            throw .invalidStringEncoding
        }
        offset += length
        return string
    }

    public mutating func readULEB128() throws(DataCursorError) -> UInt64 {
        var result: UInt64 = 0
        var bit = 0
        var byte: UInt8 = 0

        repeat {
            guard offset < data.count else {
                throw .leb128Malformed
            }
            byte = data[offset]
            offset += 1

            let slice = UInt64(byte & 0x7f)
            if bit >= 64 || ((slice << bit) >> bit) != slice {
                throw .leb128TooLarge
            }
            result |= slice << bit
            bit += 7
        } while (byte & 0x80) != 0

        return result
    }

    public mutating func readSLEB128() throws(DataCursorError) -> Int64 {
        var result: Int64 = 0
        var bit = 0
        var byte: UInt8 = 0

        repeat {
            guard offset < data.count else {
                throw .leb128Malformed
            }
            byte = data[offset]
            offset += 1

            result |= Int64(byte & 0x7f) << bit
            bit += 7
        } while (byte & 0x80) != 0

        if (byte & 0x40) != 0 {
            result |= (-1) << bit
        }

        return result
    }

    private mutating func readInteger<T: FixedWidthInteger>() throws(DataCursorError) -> T {
        let size = MemoryLayout<T>.size
        try requireAvailable(size)
        let value: T = data.withUnsafeBytes { buffer in
            buffer.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
        offset += size
        return value
    }

    private func requireAvailable(_ length: Int) throws(DataCursorError) {
        guard length >= 0 else {
            throw .readOutOfBounds(offset: offset, length: length, dataCount: data.count)
        }
        guard offset + length <= data.count else {
            throw .readOutOfBounds(offset: offset, length: length, dataCount: data.count)
        }
    }
}
