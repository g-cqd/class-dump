import Foundation
import Testing

@testable import ClassDumpCore

@Suite("DataCursor Tests", .serialized)
struct TestDataCursor {
    @Test("Init with valid offset")
    func testInitWithValidOffset() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let cursor = try DataCursor(data: data, offset: 2)
        #expect(cursor.offset == 2)
        #expect(cursor.remaining == 2)
    }

    @Test("Init with offset past end throws")
    func testInitWithOffsetPastEnd() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        #expect(throws: DataCursorError.self) {
            _ = try DataCursor(data: data, offset: 10)
        }
    }

    @Test("Read byte advances offset")
    func testReadByte() throws {
        let data = Data([0xAB, 0xCD])
        var cursor = try DataCursor(data: data)
        let byte = try cursor.readByte()
        #expect(byte == 0xAB)
        #expect(cursor.offset == 1)
    }

    @Test("Read little endian Int16")
    func testReadLittleInt16() throws {
        let data = Data([0x34, 0x12])  // 0x1234 in little endian
        var cursor = try DataCursor(data: data)
        let value = try cursor.readLittleInt16()
        #expect(value == 0x1234)
        #expect(cursor.offset == 2)
    }

    @Test("Read big endian Int16")
    func testReadBigInt16() throws {
        let data = Data([0x12, 0x34])  // 0x1234 in big endian
        var cursor = try DataCursor(data: data)
        let value = try cursor.readBigInt16()
        #expect(value == 0x1234)
        #expect(cursor.offset == 2)
    }

    @Test("Read little endian Int32")
    func testReadLittleInt32() throws {
        let data = Data([0x78, 0x56, 0x34, 0x12])  // 0x12345678 in little endian
        var cursor = try DataCursor(data: data)
        let value = try cursor.readLittleInt32()
        #expect(value == 0x1234_5678)
        #expect(cursor.offset == 4)
    }

    @Test("Read big endian Int32")
    func testReadBigInt32() throws {
        let data = Data([0x12, 0x34, 0x56, 0x78])  // 0x12345678 in big endian
        var cursor = try DataCursor(data: data)
        let value = try cursor.readBigInt32()
        #expect(value == 0x1234_5678)
        #expect(cursor.offset == 4)
    }

    @Test("Read little endian Int64")
    func testReadLittleInt64() throws {
        let data = Data([0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01])
        var cursor = try DataCursor(data: data)
        let value = try cursor.readLittleInt64()
        #expect(value == 0x0123_4567_89AB_CDEF)
        #expect(cursor.offset == 8)
    }

    @Test("Read C string")
    func testReadCString() throws {
        let data = Data("hello\0world\0".utf8)
        var cursor = try DataCursor(data: data)
        let str1 = try cursor.readCString()
        #expect(str1 == "hello")
        // advance past null
        try cursor.advance(by: 1)
        let str2 = try cursor.readCString()
        #expect(str2 == "world")
    }

    @Test("Read fixed length string")
    func testReadStringOfLength() throws {
        let data = Data("hello world".utf8)
        var cursor = try DataCursor(data: data)
        let str = try cursor.readString(length: 5, encoding: .ascii)
        #expect(str == "hello")
        #expect(cursor.offset == 5)
    }

    @Test("Read ULEB128 single byte")
    func testReadULEB128SingleByte() throws {
        let data = Data([0x7F])  // 127
        var cursor = try DataCursor(data: data)
        let value = try cursor.readULEB128()
        #expect(value == 127)
    }

    @Test("Read ULEB128 multi byte")
    func testReadULEB128MultiByte() throws {
        let data = Data([0xE5, 0x8E, 0x26])  // 624485
        var cursor = try DataCursor(data: data)
        let value = try cursor.readULEB128()
        #expect(value == 624485)
    }

    @Test("Read SLEB128 positive")
    func testReadSLEB128Positive() throws {
        let data = Data([0x3F])  // 63
        var cursor = try DataCursor(data: data)
        let value = try cursor.readSLEB128()
        #expect(value == 63)
    }

    @Test("Read SLEB128 negative")
    func testReadSLEB128Negative() throws {
        let data = Data([0x7F])  // -1
        var cursor = try DataCursor(data: data)
        let value = try cursor.readSLEB128()
        #expect(value == -1)
    }

    @Test("isAtEnd returns true when cursor at end")
    func testIsAtEnd() throws {
        let data = Data([0x01])
        var cursor = try DataCursor(data: data)
        #expect(!cursor.isAtEnd)
        _ = try cursor.readByte()
        #expect(cursor.isAtEnd)
    }

    @Test("Read past end throws")
    func testReadPastEnd() throws {
        let data = Data([0x01])
        var cursor = try DataCursor(data: data)
        _ = try cursor.readByte()
        #expect(throws: DataCursorError.self) {
            _ = try cursor.readByte()
        }
    }

    @Test("Seek to valid offset")
    func testSeekToValidOffset() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        var cursor = try DataCursor(data: data)
        try cursor.seek(to: 2)
        #expect(cursor.offset == 2)
    }

    @Test("Seek past end throws")
    func testSeekPastEnd() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        var cursor = try DataCursor(data: data)
        #expect(throws: DataCursorError.self) {
            try cursor.seek(to: 10)
        }
    }

    @Test("Read bytes returns correct data")
    func testReadBytes() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        var cursor = try DataCursor(data: data)
        try cursor.advance(by: 1)
        let bytes = try cursor.readBytes(length: 3)
        #expect(bytes == Data([0x02, 0x03, 0x04]))
        #expect(cursor.offset == 4)
    }
}
