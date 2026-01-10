// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Image Info

/// Information about a single image (dylib) in the dyld_shared_cache.
///
/// Each entry describes a dylib embedded in the cache, including its
/// load address and path.
///
/// ## Structure (32 bytes)
///
/// ```c
/// struct dyld_cache_image_info {
///     uint64_t    address;
///     uint64_t    modTime;
///     uint64_t    inode;
///     uint32_t    pathFileOffset;
///     uint32_t    pad;
/// };
/// ```
///
public struct DyldCacheImageInfo: Sendable {
    /// The virtual address where this image is loaded.
    public let address: UInt64

    /// Modification time (st_mtime from stat).
    public let modificationTime: UInt64

    /// Inode number (st_ino from stat).
    public let inode: UInt64

    /// File offset to the path string.
    public let pathFileOffset: UInt32

    /// Reserved padding.
    public let padding: UInt32

    /// The image path (e.g., "/usr/lib/libobjc.A.dylib").
    public let path: String

    /// Size of the raw structure in bytes.
    public static let structureSize = 32

    // MARK: - Computed Properties

    /// The library name (filename without directory).
    public var name: String {
        (path as NSString).lastPathComponent
    }

    /// The framework name if this is a framework, otherwise nil.
    public var frameworkName: String? {
        guard path.contains(".framework/") else { return nil }
        let components = path.components(separatedBy: "/")
        guard let frameworkDir = components.first(where: { $0.hasSuffix(".framework") }) else {
            return nil
        }
        return String(frameworkDir.dropLast(10))  // Remove ".framework"
    }

    /// Whether this is a system framework.
    public var isSystemFramework: Bool {
        path.hasPrefix("/System/Library/Frameworks/") || path.hasPrefix("/System/Library/PrivateFrameworks/")
    }

    /// Whether this is a public framework.
    public var isPublicFramework: Bool {
        path.hasPrefix("/System/Library/Frameworks/")
    }

    /// Whether this is a private framework.
    public var isPrivateFramework: Bool {
        path.hasPrefix("/System/Library/PrivateFrameworks/")
    }

    // MARK: - Parsing

    /// Parse an image info structure from a memory-mapped file.
    ///
    /// - Parameters:
    ///   - file: The memory-mapped file.
    ///   - offset: The offset to read from.
    /// - Returns: The parsed image info.
    public static func parse(from file: MemoryMappedFile, at offset: Int) throws -> DyldCacheImageInfo {
        let address = try file.read(UInt64.self, at: offset)
        let modTime = try file.read(UInt64.self, at: offset + 8)
        let inode = try file.read(UInt64.self, at: offset + 16)
        let pathOffset = try file.read(UInt32.self, at: offset + 24)
        let pad = try file.read(UInt32.self, at: offset + 28)

        // Read the path string
        let path = file.readCString(at: Int(pathOffset)) ?? "<unknown>"

        return DyldCacheImageInfo(
            address: address,
            modificationTime: modTime,
            inode: inode,
            pathFileOffset: pathOffset,
            padding: pad,
            path: path
        )
    }

    /// Parse all image info structures from a cache header.
    ///
    /// - Parameters:
    ///   - file: The memory-mapped file.
    ///   - header: The cache header containing offset and count.
    /// - Returns: An array of image info structures.
    public static func parseAll(
        from file: MemoryMappedFile,
        header: DyldCacheHeader
    ) throws -> [DyldCacheImageInfo] {
        // Modern caches (iOS 16+, macOS 13+) may use imagesText instead of images
        if header.imagesCount > 0 {
            return try parseLegacyImages(from: file, header: header)
        }
        else if header.imagesTextCount > 0 {
            return try parseTextImages(from: file, header: header)
        }
        return []
    }

    /// Parse legacy dyld_cache_image_info structures.
    private static func parseLegacyImages(
        from file: MemoryMappedFile,
        header: DyldCacheHeader
    ) throws -> [DyldCacheImageInfo] {
        var images: [DyldCacheImageInfo] = []
        images.reserveCapacity(Int(header.imagesCount))

        var offset = Int(header.imagesOffset)
        for _ in 0..<header.imagesCount {
            let image = try parse(from: file, at: offset)
            images.append(image)
            offset += structureSize
        }

        return images
    }

    /// Parse modern dyld_cache_image_text_info structures.
    ///
    /// Structure (32 bytes):
    /// ```c
    /// struct dyld_cache_image_text_info {
    ///     uuid_t uuid;           // 16 bytes
    ///     uint64_t loadAddress;  // 8 bytes
    ///     uint32_t textSegmentSize;
    ///     uint32_t pathOffset;
    /// };
    /// ```
    private static func parseTextImages(
        from file: MemoryMappedFile,
        header: DyldCacheHeader
    ) throws -> [DyldCacheImageInfo] {
        var images: [DyldCacheImageInfo] = []
        images.reserveCapacity(Int(header.imagesTextCount))

        let textInfoSize = 32  // sizeof(dyld_cache_image_text_info)
        var offset = Int(header.imagesTextOffset)

        for _ in 0..<header.imagesTextCount {
            // Skip UUID (16 bytes)
            let address = try file.read(UInt64.self, at: offset + 16)
            // Skip textSegmentSize (4 bytes)
            let pathOffset = try file.read(UInt32.self, at: offset + 28)

            // Read the path string
            let path = file.readCString(at: Int(pathOffset)) ?? "<unknown>"

            let image = DyldCacheImageInfo(
                address: address,
                modificationTime: 0,
                inode: 0,
                pathFileOffset: pathOffset,
                padding: 0,
                path: path
            )
            images.append(image)
            offset += textInfoSize
        }

        return images
    }
}

// MARK: - Debug Description

extension DyldCacheImageInfo: CustomStringConvertible {
    public var description: String {
        let addr = String(address, radix: 16, uppercase: true)
        return "0x\(addr.padding(toLength: 16, withPad: "0", startingAt: 0)) \(path)"
    }
}

// MARK: - Sorting and Filtering

extension Array where Element == DyldCacheImageInfo {
    /// Filter to only public frameworks.
    public var publicFrameworks: [DyldCacheImageInfo] {
        filter { $0.isPublicFramework }
    }

    /// Filter to only private frameworks.
    public var privateFrameworks: [DyldCacheImageInfo] {
        filter { $0.isPrivateFramework }
    }

    /// Find an image by exact path.
    public func image(withPath path: String) -> DyldCacheImageInfo? {
        first { $0.path == path }
    }

    /// Find images matching a path suffix (e.g., "Foundation.framework/Foundation").
    public func images(matching suffix: String) -> [DyldCacheImageInfo] {
        filter { $0.path.hasSuffix(suffix) }
    }

    /// Find a framework by name.
    public func framework(named name: String) -> DyldCacheImageInfo? {
        first { $0.frameworkName == name }
    }
}
