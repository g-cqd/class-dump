// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// A memory-mapped file for efficient access to large files.
///
/// This class uses `mmap()` to map a file into virtual memory, allowing
/// efficient random access without loading the entire file into RAM.
/// This is essential for dyld_shared_cache files which can be 3+ GB.
///
/// ## Usage
///
/// ```swift
/// let file = try MemoryMappedFile(path: "/path/to/dyld_shared_cache")
/// let data = file.data(at: 0x1000, count: 64)
/// ```
///
/// ## Thread Safety
///
/// Read operations are thread-safe. The mapped memory is read-only.
///
public final class MemoryMappedFile: @unchecked Sendable {
    /// The file path.
    public let path: String

    /// The total size of the mapped file in bytes.
    public let size: Int

    /// The mapped memory pointer.
    private let mappedPointer: UnsafeMutableRawPointer

    /// The file descriptor (kept open while mapped).
    private let fileDescriptor: Int32

    /// Errors that can occur during memory mapping.
    public enum Error: Swift.Error, CustomStringConvertible {
        case fileNotFound(String)
        case openFailed(String, Int32)
        case statFailed(String, Int32)
        case mmapFailed(String, Int32)
        case invalidRange(offset: Int, count: Int, fileSize: Int)

        public var description: String {
            switch self {
                case .fileNotFound(let path):
                    return "File not found: \(path)"
                case .openFailed(let path, let errno):
                    return "Failed to open file '\(path)': \(String(cString: strerror(errno)))"
                case .statFailed(let path, let errno):
                    return "Failed to stat file '\(path)': \(String(cString: strerror(errno)))"
                case .mmapFailed(let path, let errno):
                    return "Failed to mmap file '\(path)': \(String(cString: strerror(errno)))"
                case .invalidRange(let offset, let count, let fileSize):
                    return "Invalid range: offset \(offset) + count \(count) exceeds file size \(fileSize)"
            }
        }
    }

    /// Initialize a memory-mapped file.
    ///
    /// - Parameter path: The path to the file to map.
    /// - Throws: `MemoryMappedFile.Error` if the file cannot be mapped.
    public init(path: String) throws {
        self.path = path

        // Check file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw Error.fileNotFound(path)
        }

        // Open the file
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else {
            throw Error.openFailed(path, errno)
        }
        self.fileDescriptor = fd

        // Get file size
        var statInfo = stat()
        guard fstat(fd, &statInfo) == 0 else {
            close(fd)
            throw Error.statFailed(path, errno)
        }
        self.size = Int(statInfo.st_size)

        // Memory map the file
        let mapped = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd, 0)
        guard mapped != MAP_FAILED else {
            close(fd)
            throw Error.mmapFailed(path, errno)
        }
        self.mappedPointer = mapped!
    }

    deinit {
        munmap(mappedPointer, size)
        close(fileDescriptor)
    }

    // MARK: - Data Access

    /// Read bytes at the specified offset.
    ///
    /// - Parameters:
    ///   - offset: The byte offset to read from.
    ///   - count: The number of bytes to read.
    /// - Returns: A `Data` object containing the requested bytes.
    /// - Throws: `Error.invalidRange` if the range exceeds file bounds.
    public func data(at offset: Int, count: Int) throws -> Data {
        guard offset >= 0, count >= 0, offset + count <= size else {
            throw Error.invalidRange(offset: offset, count: count, fileSize: size)
        }
        return Data(bytes: mappedPointer.advanced(by: offset), count: count)
    }

    /// Read bytes at the specified offset without copying.
    ///
    /// - Parameters:
    ///   - offset: The byte offset to read from.
    ///   - count: The number of bytes to read.
    /// - Returns: An `UnsafeRawBufferPointer` to the mapped memory.
    /// - Throws: `Error.invalidRange` if the range exceeds file bounds.
    ///
    /// - Warning: The returned pointer is only valid while this `MemoryMappedFile`
    ///   instance is alive. Do not store or use it after the file is deallocated.
    public func unsafeBytes(at offset: Int, count: Int) throws -> UnsafeRawBufferPointer {
        guard offset >= 0, count >= 0, offset + count <= size else {
            throw Error.invalidRange(offset: offset, count: count, fileSize: size)
        }
        return UnsafeRawBufferPointer(start: mappedPointer.advanced(by: offset), count: count)
    }

    /// Get a pointer to the specified offset.
    ///
    /// - Parameter offset: The byte offset.
    /// - Returns: A raw pointer to the offset location.
    /// - Throws: `Error.invalidRange` if the offset exceeds file bounds.
    ///
    /// - Warning: The returned pointer is only valid while this `MemoryMappedFile`
    ///   instance is alive.
    public func pointer(at offset: Int) throws -> UnsafeRawPointer {
        guard offset >= 0, offset < size else {
            throw Error.invalidRange(offset: offset, count: 0, fileSize: size)
        }
        return UnsafeRawPointer(mappedPointer.advanced(by: offset))
    }

    // MARK: - Typed Reading

    /// Read a value of the specified type at the given offset.
    ///
    /// - Parameters:
    ///   - type: The type to read.
    ///   - offset: The byte offset to read from.
    /// - Returns: The value read from the file.
    /// - Throws: `Error.invalidRange` if there isn't enough data.
    public func read<T>(_ type: T.Type, at offset: Int) throws -> T {
        let typeSize = MemoryLayout<T>.size
        guard offset >= 0, offset + typeSize <= size else {
            throw Error.invalidRange(offset: offset, count: typeSize, fileSize: size)
        }
        return mappedPointer.advanced(by: offset).loadUnaligned(as: T.self)
    }

    /// Read an array of values at the given offset.
    ///
    /// - Parameters:
    ///   - type: The element type.
    ///   - offset: The byte offset to read from.
    ///   - count: The number of elements to read.
    /// - Returns: An array of values.
    /// - Throws: `Error.invalidRange` if there isn't enough data.
    public func readArray<T>(_ type: T.Type, at offset: Int, count: Int) throws -> [T] {
        let typeSize = MemoryLayout<T>.stride
        let totalSize = typeSize * count
        guard offset >= 0, offset + totalSize <= size else {
            throw Error.invalidRange(offset: offset, count: totalSize, fileSize: size)
        }

        var result: [T] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let value = mappedPointer.advanced(by: offset + i * typeSize).loadUnaligned(as: T.self)
            result.append(value)
        }

        return result
    }

    /// Read a null-terminated C string at the given offset.
    ///
    /// - Parameter offset: The byte offset to read from.
    /// - Returns: The string, or `nil` if invalid.
    public func readCString(at offset: Int) -> String? {
        guard offset >= 0, offset < size else { return nil }

        let ptr = mappedPointer.advanced(by: offset).assumingMemoryBound(to: CChar.self)

        // Find null terminator within bounds
        var length = 0
        while offset + length < size && ptr[length] != 0 {
            length += 1
        }

        guard offset + length < size else { return nil }

        return String(cString: ptr)
    }
}

// MARK: - DataCursor Integration

extension MemoryMappedFile {
    /// Create a DataCursor for reading from a specific region.
    ///
    /// - Parameters:
    ///   - offset: The starting offset.
    ///   - count: The number of bytes to include.
    /// - Returns: A DataCursor for the specified region.
    /// - Throws: `Error.invalidRange` if the range is invalid.
    public func cursor(at offset: Int, count: Int) throws -> DataCursor {
        let data = try self.data(at: offset, count: count)
        return try DataCursor(data: data)
    }
}
