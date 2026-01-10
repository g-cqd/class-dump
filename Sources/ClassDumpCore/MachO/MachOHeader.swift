import Foundation
import MachO

/// Errors that can occur when parsing Mach-O files.
public enum MachOError: Error, Equatable {
    case invalidMagic(UInt32)
    case dataTooSmall(expected: Int, actual: Int)
    case invalidFatMagic(UInt32)
    case architectureNotFound(Arch)
    case unsupportedFormat
    case invalidLoadCommand
}

/// Parsed Mach-O header information.
public struct MachOHeader: Sendable {
    /// The magic number identifying the file format.
    public let magic: UInt32

    /// The CPU type.
    public let cputype: cpu_type_t

    /// The CPU subtype.
    public let cpusubtype: cpu_subtype_t

    /// The file type (executable, dylib, etc.).
    public let filetype: UInt32

    /// The number of load commands.
    public let ncmds: UInt32

    /// The size of all load commands in bytes.
    public let sizeofcmds: UInt32

    /// Flags describing the file.
    public let flags: UInt32

    /// Reserved field (64-bit only).
    public let reserved: UInt32  // Only used in 64-bit

    /// The byte order of the file.
    public let byteOrder: ByteOrder

    /// Whether this file uses the 64-bit ABI.
    public let uses64BitABI: Bool

    /// The size of the header in bytes.
    public var headerSize: Int {
        uses64BitABI ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size
    }

    /// The architecture represented by this header.
    public var arch: Arch {
        Arch(cputype: cputype, cpusubtype: cpusubtype)
    }

    /// Masked CPU type (architecture mask removed).
    public var maskedCPUType: cpu_type_t {
        // Use bitPattern to safely convert UInt32 mask to Int32 without overflow
        cputype & ~Int32(bitPattern: CPU_ARCH_MASK)
    }

    /// Masked CPU subtype (subtype mask removed).
    public var maskedCPUSubtype: cpu_subtype_t {
        // Use bitPattern to safely convert UInt32 mask to Int32 without overflow
        cpusubtype & ~Int32(bitPattern: CPU_SUBTYPE_MASK)
    }

    /// Parse a Mach-O header from data.
    public init(data: Data) throws(MachOError) {
        guard data.count >= 4 else {
            throw .dataTooSmall(expected: 4, actual: data.count)
        }

        // Read magic as big endian to determine byte order
        let rawMagic = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        let magicBE = UInt32(bigEndian: rawMagic)

        let parsedByteOrder: ByteOrder
        let parsedMagic: UInt32

        switch magicBE {
            case MH_MAGIC, MH_MAGIC_64:
                parsedByteOrder = .big
                parsedMagic = magicBE
            case MH_CIGAM, MH_CIGAM_64:
                parsedByteOrder = .little
                parsedMagic = magicBE.byteSwapped
            default:
                throw .invalidMagic(magicBE)
        }

        let is64Bit = (parsedMagic == MH_MAGIC_64)
        let headerSize = is64Bit ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size

        guard data.count >= headerSize else {
            throw .dataTooSmall(expected: headerSize, actual: data.count)
        }

        // Parse header fields using direct memory access for efficiency
        let parsed = data.withUnsafeBytes {
            buffer -> (
                cpu: cpu_type_t, sub: cpu_subtype_t, ftype: UInt32, ncmds: UInt32, sizeofcmds: UInt32, flags: UInt32,
                reserved: UInt32
            ) in
            guard is64Bit else {
                let header = buffer.loadUnaligned(as: mach_header.self)
                guard parsedByteOrder == .little else {
                    return (
                        cpu_type_t(bigEndian: header.cputype),
                        cpu_subtype_t(bigEndian: header.cpusubtype),
                        UInt32(bigEndian: header.filetype),
                        UInt32(bigEndian: header.ncmds),
                        UInt32(bigEndian: header.sizeofcmds),
                        UInt32(bigEndian: header.flags),
                        0
                    )
                }
                return (
                    cpu_type_t(littleEndian: header.cputype),
                    cpu_subtype_t(littleEndian: header.cpusubtype),
                    UInt32(littleEndian: header.filetype),
                    UInt32(littleEndian: header.ncmds),
                    UInt32(littleEndian: header.sizeofcmds),
                    UInt32(littleEndian: header.flags),
                    0
                )
            }
            let header = buffer.loadUnaligned(as: mach_header_64.self)
            guard parsedByteOrder == .little else {
                return (
                    cpu_type_t(bigEndian: header.cputype),
                    cpu_subtype_t(bigEndian: header.cpusubtype),
                    UInt32(bigEndian: header.filetype),
                    UInt32(bigEndian: header.ncmds),
                    UInt32(bigEndian: header.sizeofcmds),
                    UInt32(bigEndian: header.flags),
                    UInt32(bigEndian: header.reserved)
                )
            }
            return (
                cpu_type_t(littleEndian: header.cputype),
                cpu_subtype_t(littleEndian: header.cpusubtype),
                UInt32(littleEndian: header.filetype),
                UInt32(littleEndian: header.ncmds),
                UInt32(littleEndian: header.sizeofcmds),
                UInt32(littleEndian: header.flags),
                UInt32(littleEndian: header.reserved)
            )
        }

        self.magic = parsedMagic
        self.byteOrder = parsedByteOrder
        self.uses64BitABI = is64Bit
        self.cputype = parsed.cpu
        self.cpusubtype = parsed.sub
        self.filetype = parsed.ftype
        self.ncmds = parsed.ncmds
        self.sizeofcmds = parsed.sizeofcmds
        self.flags = parsed.flags
        self.reserved = parsed.reserved
    }
}

// MARK: - File Type Descriptions

extension MachOHeader {
    /// Human-readable description of the file type.
    public var filetypeDescription: String {
        switch filetype {
            case UInt32(MH_OBJECT): return "OBJECT"
            case UInt32(MH_EXECUTE): return "EXECUTE"
            case UInt32(MH_FVMLIB): return "FVMLIB"
            case UInt32(MH_CORE): return "CORE"
            case UInt32(MH_PRELOAD): return "PRELOAD"
            case UInt32(MH_DYLIB): return "DYLIB"
            case UInt32(MH_DYLINKER): return "DYLINKER"
            case UInt32(MH_BUNDLE): return "BUNDLE"
            case UInt32(MH_DYLIB_STUB): return "DYLIB_STUB"
            case UInt32(MH_DSYM): return "DSYM"
            case UInt32(MH_KEXT_BUNDLE): return "KEXT_BUNDLE"
            default: return "UNKNOWN(\(filetype))"
        }
    }

    /// Human-readable description of the flags.
    public var flagDescription: String {
        var flagNames: [String] = []
        if flags & UInt32(MH_NOUNDEFS) != 0 { flagNames.append("NOUNDEFS") }
        if flags & UInt32(MH_INCRLINK) != 0 { flagNames.append("INCRLINK") }
        if flags & UInt32(MH_DYLDLINK) != 0 { flagNames.append("DYLDLINK") }
        if flags & UInt32(MH_BINDATLOAD) != 0 { flagNames.append("BINDATLOAD") }
        if flags & UInt32(MH_PREBOUND) != 0 { flagNames.append("PREBOUND") }
        if flags & UInt32(MH_SPLIT_SEGS) != 0 { flagNames.append("SPLIT_SEGS") }
        if flags & UInt32(MH_TWOLEVEL) != 0 { flagNames.append("TWOLEVEL") }
        if flags & UInt32(MH_FORCE_FLAT) != 0 { flagNames.append("FORCE_FLAT") }
        if flags & UInt32(MH_NOMULTIDEFS) != 0 { flagNames.append("NOMULTIDEFS") }
        if flags & UInt32(MH_NOFIXPREBINDING) != 0 { flagNames.append("NOFIXPREBINDING") }
        if flags & UInt32(MH_PREBINDABLE) != 0 { flagNames.append("PREBINDABLE") }
        if flags & UInt32(MH_ALLMODSBOUND) != 0 { flagNames.append("ALLMODSBOUND") }
        if flags & UInt32(MH_SUBSECTIONS_VIA_SYMBOLS) != 0 { flagNames.append("SUBSECTIONS_VIA_SYMBOLS") }
        if flags & UInt32(MH_CANONICAL) != 0 { flagNames.append("CANONICAL") }
        if flags & UInt32(MH_WEAK_DEFINES) != 0 { flagNames.append("WEAK_DEFINES") }
        if flags & UInt32(MH_BINDS_TO_WEAK) != 0 { flagNames.append("BINDS_TO_WEAK") }
        if flags & UInt32(MH_ALLOW_STACK_EXECUTION) != 0 { flagNames.append("ALLOW_STACK_EXECUTION") }
        if flags & UInt32(MH_ROOT_SAFE) != 0 { flagNames.append("ROOT_SAFE") }
        if flags & UInt32(MH_SETUID_SAFE) != 0 { flagNames.append("SETUID_SAFE") }
        if flags & UInt32(MH_NO_REEXPORTED_DYLIBS) != 0 { flagNames.append("NO_REEXPORTED_DYLIBS") }
        if flags & UInt32(MH_PIE) != 0 { flagNames.append("PIE") }
        return flagNames.joined(separator: " ")
    }

    /// Magic number description.
    public var magicDescription: String {
        switch magic {
            case MH_MAGIC: return "MH_MAGIC"
            case MH_MAGIC_64: return "MH_MAGIC_64"
            default: return String(format: "0x%08x", magic)
        }
    }
}

extension MachOHeader: CustomStringConvertible {
    /// A textual description of the header.
    public var description: String {
        "MachOHeader(magic: \(magicDescription), arch: \(arch.name), filetype: \(filetypeDescription), ncmds: \(ncmds), flags: \(flagDescription))"
    }
}
