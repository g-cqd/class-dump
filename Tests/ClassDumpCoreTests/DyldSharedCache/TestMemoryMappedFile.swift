// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for MemoryMappedFile.
@Suite("Memory Mapped File Tests")
struct MemoryMappedFileTests {

    // MARK: - Basic File Operations

    @Test("Memory maps a file successfully")
    func mapsFileSuccessfully() throws {
        // Create a temp file
        let tempPath = createTempFile(content: "Hello, World!")
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let file = try MemoryMappedFile(path: tempPath)

        #expect(file.size == 13)
        #expect(file.path == tempPath)
    }

    @Test("Throws for non-existent file")
    func throwsForNonExistentFile() {
        #expect(throws: MemoryMappedFile.Error.self) {
            _ = try MemoryMappedFile(path: "/nonexistent/path/to/file")
        }
    }

    // MARK: - Data Reading

    @Test("Reads data at offset")
    func readsDataAtOffset() throws {
        let content = "Hello, World!"
        let tempPath = createTempFile(content: content)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let file = try MemoryMappedFile(path: tempPath)
        let data = try file.data(at: 7, count: 5)

        #expect(String(data: data, encoding: .utf8) == "World")
    }

    @Test("Reads typed values")
    func readsTypedValues() throws {
        // Create file with binary content
        var data = Data()
        var value32: UInt32 = 0x1234_5678
        var value64: UInt64 = 0xDEAD_BEEF_CAFE_BABE
        data.append(Data(bytes: &value32, count: 4))
        data.append(Data(bytes: &value64, count: 8))

        let tempPath = createTempFileWithData(data)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let file = try MemoryMappedFile(path: tempPath)

        let read32 = try file.read(UInt32.self, at: 0)
        #expect(read32 == 0x1234_5678)

        let read64 = try file.read(UInt64.self, at: 4)
        #expect(read64 == 0xDEAD_BEEF_CAFE_BABE)
    }

    @Test("Reads C string")
    func readsCString() throws {
        let content = "Hello\0World\0"
        let tempPath = createTempFile(content: content)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let file = try MemoryMappedFile(path: tempPath)

        #expect(file.readCString(at: 0) == "Hello")
        #expect(file.readCString(at: 6) == "World")
    }

    @Test("Reads array of values")
    func readsArrayOfValues() throws {
        var data = Data()
        for i: UInt32 in [1, 2, 3, 4, 5] {
            var value = i
            data.append(Data(bytes: &value, count: 4))
        }

        let tempPath = createTempFileWithData(data)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let file = try MemoryMappedFile(path: tempPath)
        let array = try file.readArray(UInt32.self, at: 0, count: 5)

        #expect(array == [1, 2, 3, 4, 5])
    }

    // MARK: - Bounds Checking

    @Test("Throws for out of bounds read")
    func throwsForOutOfBoundsRead() throws {
        let tempPath = createTempFile(content: "Hello")
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let file = try MemoryMappedFile(path: tempPath)

        #expect(throws: MemoryMappedFile.Error.self) {
            _ = try file.data(at: 10, count: 5)
        }
    }

    @Test("Throws for negative offset")
    func throwsForNegativeOffset() throws {
        let tempPath = createTempFile(content: "Hello")
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let file = try MemoryMappedFile(path: tempPath)

        #expect(throws: MemoryMappedFile.Error.self) {
            _ = try file.data(at: -1, count: 1)
        }
    }

    // MARK: - Helpers

    private func createTempFile(content: String) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let path = tempDir.appendingPathComponent(UUID().uuidString).path
        FileManager.default.createFile(atPath: path, contents: content.data(using: .utf8))
        return path
    }

    private func createTempFileWithData(_ data: Data) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let path = tempDir.appendingPathComponent(UUID().uuidString).path
        FileManager.default.createFile(atPath: path, contents: data)
        return path
    }
}
