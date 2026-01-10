import Foundation
import MachO

/// Segment protection flags.
public struct SegmentFlags: OptionSet, Sendable {
    /// The raw integer value of the flags.
    public let rawValue: UInt32

    /// Create a new set of flags from a raw value.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// The segment is located at the high end of the virtual memory space.
    public static let highVM = SegmentFlags(rawValue: UInt32(SG_HIGHVM))

    /// The segment is mapped from a fixed virtual memory library.
    public static let fvmLib = SegmentFlags(rawValue: UInt32(SG_FVMLIB))

    /// The segment cannot be relocated.
    public static let noReloc = SegmentFlags(rawValue: UInt32(SG_NORELOC))

    /// The segment is protected (encrypted) - version 1.
    public static let protectedVersion1 = SegmentFlags(rawValue: UInt32(SG_PROTECTED_VERSION_1))

    /// A textual description of the flags.
    public var description: String {
        var flags: [String] = []
        if contains(.highVM) { flags.append("HIGHVM") }
        if contains(.fvmLib) { flags.append("FVMLIB") }
        if contains(.noReloc) { flags.append("NORELOC") }
        if contains(.protectedVersion1) { flags.append("PROTECTED_VERSION_1") }
        return flags.isEmpty ? "none" : flags.joined(separator: " ")
    }
}

/// Segment encryption type (for protected segments).
public enum SegmentEncryptionType: Sendable, Equatable {
    case none
    case aes  // 10.5 and earlier
    case blowfish  // 10.6
    case unknown(UInt32)

    /// Check if two encryption types are equal.
    public static func == (lhs: SegmentEncryptionType, rhs: SegmentEncryptionType) -> Bool {
        switch (lhs, rhs) {
            case (.none, .none): return true
            case (.aes, .aes): return true
            case (.blowfish, .blowfish): return true
            case (.unknown(let l), .unknown(let r)): return l == r
            default: return false
        }
    }

    /// Magic values used to identify encryption type.
    public static let magicNone: UInt32 = 0

    /// Magic value for AES encryption.
    public static let magicAES: UInt32 = 0xc228_6295

    /// Magic value for Blowfish encryption.
    public static let magicBlowfish: UInt32 = 0x2e69_cf40

    /// Initialize from a magic value.
    public init(magic: UInt32) {
        switch magic {
            case Self.magicNone: self = .none
            case Self.magicAES: self = .aes
            case Self.magicBlowfish: self = .blowfish
            default: self = .unknown(magic)
        }
    }

    /// The human-readable name of the encryption type.
    public var name: String {
        switch self {
            case .none: return "None"
            case .aes: return "Protected Segment Type 1 (prior to 10.6)"
            case .blowfish: return "Protected Segment Type 2 (10.6)"
            case .unknown(let magic): return String(format: "Unknown (0x%08x)", magic)
        }
    }

    /// Whether this encryption type can be decrypted by this tool.
    public var canDecrypt: Bool {
        switch self {
            case .none, .aes, .blowfish: return true
            case .unknown: return false
        }
    }
}

/// A segment load command (LC_SEGMENT or LC_SEGMENT_64).
public struct SegmentCommand: LoadCommandProtocol, Sendable {
    /// The command type (LC_SEGMENT or LC_SEGMENT_64).
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The name of the segment (e.g., "__TEXT").
    public let name: String

    /// The virtual memory address of the segment.
    public let vmaddr: UInt64

    /// The virtual memory size of the segment.
    public let vmsize: UInt64

    /// The file offset of the segment data.
    public let fileoff: UInt64

    /// The size of the segment data in the file.
    public let filesize: UInt64

    /// The maximum virtual memory protection.
    public let maxprot: Int32

    /// The initial virtual memory protection.
    public let initprot: Int32

    /// The number of sections in this segment.
    public let nsects: UInt32

    /// Segment flags.
    public let flags: SegmentFlags

    /// The sections contained in this segment.
    public let sections: [Section]

    /// Whether this is a 64-bit segment.
    public let is64Bit: Bool

    /// Whether this segment is protected (encrypted).
    public var isProtected: Bool {
        flags.contains(.protectedVersion1)
    }

    /// Whether this segment contains the given virtual address.
    public func contains(address: UInt64) -> Bool {
        address >= vmaddr && address < vmaddr + vmsize
    }

    /// Find a section containing the given virtual address.
    public func section(containing address: UInt64) -> Section? {
        sections.first { $0.contains(address: address) }
    }

    /// Find a section by name.
    public func section(named name: String) -> Section? {
        sections.first { $0.sectionName == name }
    }

    /// Calculate file offset for a virtual address.
    public func fileOffset(for address: UInt64) -> UInt64? {
        guard let section = section(containing: address) else { return nil }
        return section.fileOffset(for: address)
    }

    /// Calculate segment offset (relative to segment start) for a virtual address.
    public func segmentOffset(for address: UInt64) -> UInt64? {
        guard let fileOff = fileOffset(for: address) else { return nil }
        return fileOff - fileoff
    }

    /// Parse a segment command from data.
    public init(data: Data, byteOrder: ByteOrder, is64Bit: Bool) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
            }

            // Read segment name (16 bytes, null-terminated)
            self.name = try cursor.readString(length: 16, encoding: .ascii)

            if is64Bit {
                if byteOrder == .little {
                    self.vmaddr = try cursor.readLittleInt64()
                    self.vmsize = try cursor.readLittleInt64()
                    self.fileoff = try cursor.readLittleInt64()
                    self.filesize = try cursor.readLittleInt64()
                    self.maxprot = Int32(bitPattern: try cursor.readLittleInt32())
                    self.initprot = Int32(bitPattern: try cursor.readLittleInt32())
                    self.nsects = try cursor.readLittleInt32()
                    self.flags = SegmentFlags(rawValue: try cursor.readLittleInt32())
                }
                else {
                    self.vmaddr = try cursor.readBigInt64()
                    self.vmsize = try cursor.readBigInt64()
                    self.fileoff = try cursor.readBigInt64()
                    self.filesize = try cursor.readBigInt64()
                    self.maxprot = Int32(bitPattern: try cursor.readBigInt32())
                    self.initprot = Int32(bitPattern: try cursor.readBigInt32())
                    self.nsects = try cursor.readBigInt32()
                    self.flags = SegmentFlags(rawValue: try cursor.readBigInt32())
                }
            }
            else {
                if byteOrder == .little {
                    self.vmaddr = UInt64(try cursor.readLittleInt32())
                    self.vmsize = UInt64(try cursor.readLittleInt32())
                    self.fileoff = UInt64(try cursor.readLittleInt32())
                    self.filesize = UInt64(try cursor.readLittleInt32())
                    self.maxprot = Int32(bitPattern: try cursor.readLittleInt32())
                    self.initprot = Int32(bitPattern: try cursor.readLittleInt32())
                    self.nsects = try cursor.readLittleInt32()
                    self.flags = SegmentFlags(rawValue: try cursor.readLittleInt32())
                }
                else {
                    self.vmaddr = UInt64(try cursor.readBigInt32())
                    self.vmsize = UInt64(try cursor.readBigInt32())
                    self.fileoff = UInt64(try cursor.readBigInt32())
                    self.filesize = UInt64(try cursor.readBigInt32())
                    self.maxprot = Int32(bitPattern: try cursor.readBigInt32())
                    self.initprot = Int32(bitPattern: try cursor.readBigInt32())
                    self.nsects = try cursor.readBigInt32()
                    self.flags = SegmentFlags(rawValue: try cursor.readBigInt32())
                }
            }

            self.is64Bit = is64Bit

            // Parse sections
            var sections: [Section] = []
            sections.reserveCapacity(Int(nsects))

            for _ in 0..<nsects {
                let section = try Section(
                    cursor: &cursor,
                    byteOrder: byteOrder,
                    is64Bit: is64Bit,
                    segmentVMAddr: vmaddr,
                    segmentFileOff: fileoff
                )
                sections.append(section)
            }

            self.sections = sections
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: is64Bit ? 72 : 56, actual: data.count)
        }
    }
}

extension SegmentCommand: CustomStringConvertible {
    /// A textual description of the segment command.
    public var description: String {
        let ptrWidth = is64Bit ? 16 : 8
        return String(
            format: "SegmentCommand(%@, vmaddr: 0x%0*llx, vmsize: 0x%llx, fileoff: %llu, flags: %@, nsects: %u)",
            name,
            ptrWidth,
            vmaddr,
            vmsize,
            fileoff,
            flags.description,
            nsects
        )
    }
}
