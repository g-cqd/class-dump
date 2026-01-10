// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// A parsed dyld_shared_cache file.
///
/// The dyld_shared_cache is a pre-linked cache of system dylibs used by dyld
/// on iOS, macOS, watchOS, and tvOS. This class provides access to the cache
/// structure, embedded images, and address translation.
///
/// ## Usage
///
/// ```swift
/// // Open a cache file
/// let cache = try DyldSharedCache(path: "/System/Volumes/Preboot/.../dyld_shared_cache_arm64e")
///
/// // List all images
/// for image in cache.images {
///     print(image.path)
/// }
///
/// // Find a specific framework
/// if let foundation = cache.image(named: "Foundation") {
///     let data = try cache.imageData(for: foundation)
/// }
///
/// // Translate addresses
/// if let offset = cache.translator.fileOffset(for: 0x1800a0000) {
///     let data = try cache.file.data(at: Int(offset), count: 64)
/// }
/// ```
///
/// ## Split Caches
///
/// Modern caches (iOS 16+, macOS 13+) are split into multiple files:
/// - `dyld_shared_cache_arm64e` (main file)
/// - `dyld_shared_cache_arm64e.01` (sub-cache)
/// - `dyld_shared_cache_arm64e.02` (sub-cache)
/// - `dyld_shared_cache_arm64e.symbols` (symbols)
///
/// Use `DyldSharedCache(path:loadSubCaches:)` with `loadSubCaches: true`
/// to automatically discover and load all related files.
///
public final class DyldSharedCache: @unchecked Sendable {
    /// The memory-mapped main cache file.
    public let file: MemoryMappedFile

    /// The parsed header.
    public let header: DyldCacheHeader

    /// Memory mappings describing regions in the cache.
    public let mappings: [DyldCacheMappingInfo]

    /// List of images (dylibs) in the cache.
    public let images: [DyldCacheImageInfo]

    /// Address translator for this cache.
    public let translator: DyldCacheTranslator

    /// Sub-cache files (if loaded).
    public private(set) var subCaches: [DyldSharedCache] = []

    /// Multi-file translator (if sub-caches are loaded).
    public private(set) var multiFileTranslator: MultiFileTranslator?

    /// The cache file path.
    public var path: String {
        file.path
    }

    /// The architecture of this cache.
    public var architecture: String {
        header.magic.architecture
    }

    /// Whether this is a 64-bit cache.
    public var is64Bit: Bool {
        header.magic.is64Bit
    }

    // MARK: - Initialization

    /// Open a dyld_shared_cache file.
    ///
    /// - Parameters:
    ///   - path: Path to the cache file.
    ///   - loadSubCaches: Whether to automatically load .01, .02, etc. files.
    /// - Throws: Error if the file cannot be opened or parsed.
    public init(path: String, loadSubCaches: Bool = false) throws {
        // Memory map the file
        self.file = try MemoryMappedFile(path: path)

        // Parse the header
        self.header = try DyldCacheHeader(from: file)

        // Parse mappings
        self.mappings = try DyldCacheMappingInfo.parseAll(from: file, header: header)

        // Parse images
        self.images = try DyldCacheImageInfo.parseAll(from: file, header: header)

        // Create translator
        self.translator = DyldCacheTranslator(mappings: mappings)

        // Load sub-caches if requested
        if loadSubCaches && header.hasSubCaches {
            try loadSubCacheFiles(basePath: path)
        }
    }

    /// Load sub-cache files (.01, .02, etc.).
    private func loadSubCacheFiles(basePath: String) throws {
        var allFiles: [(file: MemoryMappedFile, mappings: [DyldCacheMappingInfo])] = [
            (file, mappings)
        ]

        // Try loading numbered sub-caches
        for i in 1...99 {
            let suffix = String(format: ".%02d", i)
            let subPath = basePath + suffix

            guard FileManager.default.fileExists(atPath: subPath) else {
                break
            }

            do {
                let subFile = try MemoryMappedFile(path: subPath)
                let subHeader = try DyldCacheHeader(from: subFile)
                let subMappings = try DyldCacheMappingInfo.parseAll(from: subFile, header: subHeader)

                // Create sub-cache (without recursive sub-cache loading)
                let subCache = try DyldSharedCache(path: subPath, loadSubCaches: false)
                subCaches.append(subCache)

                allFiles.append((subFile, subMappings))
            }
            catch {
                // Stop on first failed sub-cache
                break
            }
        }

        // Try loading .symbols file
        let symbolsPath = basePath + ".symbols"
        if FileManager.default.fileExists(atPath: symbolsPath) {
            do {
                let symbolsFile = try MemoryMappedFile(path: symbolsPath)
                let symbolsHeader = try DyldCacheHeader(from: symbolsFile)
                let symbolsMappings = try DyldCacheMappingInfo.parseAll(from: symbolsFile, header: symbolsHeader)
                allFiles.append((symbolsFile, symbolsMappings))
            }
            catch {
                // Symbols file is optional
            }
        }

        // Create multi-file translator if we have sub-caches
        if allFiles.count > 1 {
            self.multiFileTranslator = MultiFileTranslator(files: allFiles)
        }
    }

    // MARK: - Image Access

    /// Find an image by name (framework or library name).
    ///
    /// - Parameter name: The framework or library name (e.g., "Foundation").
    /// - Returns: The image info, or `nil` if not found.
    public func image(named name: String) -> DyldCacheImageInfo? {
        // Try framework match first
        if let framework = images.framework(named: name) {
            return framework
        }

        // Try library name match
        return images.first { $0.name == name || $0.name == "lib\(name).dylib" }
    }

    /// Find an image by exact path.
    ///
    /// - Parameter path: The full path (e.g., "/System/Library/Frameworks/Foundation.framework/Foundation").
    /// - Returns: The image info, or `nil` if not found.
    public func image(atPath path: String) -> DyldCacheImageInfo? {
        images.image(withPath: path)
    }

    /// Get the raw Mach-O data for an image.
    ///
    /// This extracts the Mach-O binary data for the specified image,
    /// which can then be parsed by `MachOFile`.
    ///
    /// - Parameter image: The image to extract.
    /// - Returns: The Mach-O data.
    /// - Throws: Error if the data cannot be read.
    public func imageData(for image: DyldCacheImageInfo) throws -> Data {
        guard let offset = translator.fileOffsetInt(for: image.address) else {
            throw ImageError.addressNotInCache(image.address)
        }

        // Read the Mach-O header to determine size
        let headerData = try file.data(at: offset, count: 32)
        var cursor = try DataCursor(data: headerData)

        let magic = try cursor.readLittleInt32()

        // Determine header size
        let headerSize: Int
        switch magic {
            case 0xFEED_FACE:  // MH_MAGIC
                headerSize = 28
            case 0xFEED_FACF:  // MH_MAGIC_64
                headerSize = 32
            case 0xCEFA_EDFE:  // MH_CIGAM (byte-swapped)
                headerSize = 28
            case 0xCFFA_EDFE:  // MH_CIGAM_64 (byte-swapped)
                headerSize = 32
            default:
                throw ImageError.invalidMachOHeader(magic)
        }

        // Read full header to get load commands size
        let fullHeaderData = try file.data(at: offset, count: headerSize)
        var fullCursor = try DataCursor(data: fullHeaderData)
        _ = try fullCursor.readLittleInt32()  // magic
        _ = try fullCursor.readLittleInt32()  // cputype
        _ = try fullCursor.readLittleInt32()  // cpusubtype
        _ = try fullCursor.readLittleInt32()  // filetype
        _ = try fullCursor.readLittleInt32()  // ncmds
        let sizeofcmds = try fullCursor.readLittleInt32()

        // Total size is header + load commands
        // In DSC, the actual segments are scattered, so we return header + commands
        let totalSize = headerSize + Int(sizeofcmds)

        return try file.data(at: offset, count: totalSize)
    }

    // MARK: - Address Translation

    /// Translate a virtual address to file offset.
    ///
    /// If sub-caches are loaded, this checks all files.
    ///
    /// - Parameter address: The virtual address.
    /// - Returns: The file offset, or `nil` if not found.
    public func fileOffset(for address: UInt64) -> UInt64? {
        // Try main cache first
        if let offset = translator.fileOffset(for: address) {
            return offset
        }

        // Try sub-caches
        for subCache in subCaches {
            if let offset = subCache.translator.fileOffset(for: address) {
                return offset
            }
        }

        return nil
    }

    /// Read data at a virtual address.
    ///
    /// - Parameters:
    ///   - address: The virtual address.
    ///   - count: Number of bytes to read.
    /// - Returns: The data.
    /// - Throws: Error if the address is invalid.
    public func readData(at address: UInt64, count: Int) throws -> Data {
        // Use multi-file translator if available
        if let mft = multiFileTranslator {
            if let data = mft.readData(at: address, count: count) {
                return data
            }
            throw ImageError.addressNotInCache(address)
        }

        // Single file
        guard let offset = translator.fileOffsetInt(for: address) else {
            throw ImageError.addressNotInCache(address)
        }
        return try file.data(at: offset, count: count)
    }

    /// Read a C string at a virtual address.
    ///
    /// - Parameter address: The virtual address.
    /// - Returns: The string, or `nil` if invalid.
    public func readCString(at address: UInt64) -> String? {
        // Use multi-file translator if available
        if let mft = multiFileTranslator {
            return mft.readCString(at: address)
        }

        // Single file
        guard let offset = translator.fileOffsetInt(for: address) else {
            return nil
        }
        return file.readCString(at: offset)
    }

    // MARK: - Errors

    public enum ImageError: Error, CustomStringConvertible {
        case addressNotInCache(UInt64)
        case invalidMachOHeader(UInt32)

        public var description: String {
            switch self {
                case .addressNotInCache(let addr):
                    return "Address 0x\(String(addr, radix: 16)) not in cache mappings"
                case .invalidMachOHeader(let magic):
                    return "Invalid Mach-O magic: 0x\(String(magic, radix: 16))"
            }
        }
    }
}

// MARK: - Cache Discovery

extension DyldSharedCache {
    /// Find the system dyld_shared_cache path.
    ///
    /// - Parameter architecture: The architecture to find (default: current system).
    /// - Returns: The path to the cache file, or `nil` if not found.
    public static func systemCachePath(architecture: String? = nil) -> String? {
        // Build list of architectures to try
        let architectures: [String]
        if let arch = architecture {
            architectures = [arch]
        }
        else {
            architectures = preferredArchitectures()
        }

        // Base paths to search
        let basePaths = [
            "/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld",
            "/System/Library/dyld",
            "/var/db/dyld",
        ]

        // Try each architecture in order of preference
        for arch in architectures {
            for basePath in basePaths {
                let path = "\(basePath)/dyld_shared_cache_\(arch)"
                if FileManager.default.fileExists(atPath: path) {
                    return path
                }
            }
        }

        return nil
    }

    /// Get preferred architectures in order of preference.
    private static func preferredArchitectures() -> [String] {
        #if arch(arm64)
            // On arm64, try arm64e first (most Apple Silicon Macs use arm64e),
            // then fall back to arm64
            return ["arm64e", "arm64"]
        #elseif arch(x86_64)
            // On x86_64, try x86_64h (Haswell) first, then x86_64
            return ["x86_64h", "x86_64"]
        #else
            return ["arm64e", "arm64", "x86_64"]
        #endif
    }

    /// List available cache files in a directory.
    ///
    /// - Parameter directory: The directory to search.
    /// - Returns: Array of cache file paths.
    public static func cacheFiles(in directory: String) -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else {
            return []
        }

        return
            contents
            .filter { $0.hasPrefix("dyld_shared_cache_") && !$0.contains(".") }
            .map { (directory as NSString).appendingPathComponent($0) }
            .sorted()
    }
}

// MARK: - Debug Description

extension DyldSharedCache: CustomStringConvertible {
    public var description: String {
        """
        DyldSharedCache {
          path: \(path)
          architecture: \(architecture)
          fileSize: \(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))
          mappings: \(mappings.count)
          images: \(images.count)
          subCaches: \(subCaches.count)
          uuid: \(header.uuid)
        }
        """
    }
}
