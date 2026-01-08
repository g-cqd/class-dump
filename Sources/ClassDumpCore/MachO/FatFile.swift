import Foundation
import MachO

/// Represents a single architecture slice within a fat (universal) binary.
public struct FatArch: Sendable {
    public let cputype: cpu_type_t
    public let cpusubtype: cpu_subtype_t
    public let offset: UInt64
    public let size: UInt64
    public let align: UInt32

    /// The architecture represented by this slice.
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

    /// Whether this architecture uses 64-bit ABI.
    public var uses64BitABI: Bool {
        arch.uses64BitABI
    }

    /// Whether this architecture uses 64-bit libraries.
    public var uses64BitLibraries: Bool {
        arch.uses64BitLibraries
    }

    /// The architecture name.
    public var archName: String {
        arch.name
    }

    /// Parse a fat_arch structure (32-bit offsets).
    init(cursor: inout DataCursor) throws(DataCursorError) {
        self.cputype = cpu_type_t(bitPattern: try cursor.readBigInt32())
        self.cpusubtype = cpu_subtype_t(bitPattern: try cursor.readBigInt32())
        self.offset = UInt64(try cursor.readBigInt32())
        self.size = UInt64(try cursor.readBigInt32())
        self.align = try cursor.readBigInt32()
    }

    /// Parse a fat_arch_64 structure (64-bit offsets).
    init(cursor64: inout DataCursor) throws(DataCursorError) {
        self.cputype = cpu_type_t(bitPattern: try cursor64.readBigInt32())
        self.cpusubtype = cpu_subtype_t(bitPattern: try cursor64.readBigInt32())
        self.offset = try cursor64.readBigInt64()
        self.size = try cursor64.readBigInt64()
        self.align = try cursor64.readBigInt32()
        _ = try cursor64.readBigInt32()  // reserved
    }
}

extension FatArch: CustomStringConvertible {
    public var description: String {
        "FatArch(\(archName), offset: 0x\(String(offset, radix: 16)), size: \(size), align: 2^\(align))"
    }
}

/// Represents a fat (universal) binary containing multiple architecture slices.
public struct FatFile: Sendable {
    public let arches: [FatArch]
    public let is64Bit: Bool

    /// The architecture names contained in this fat file.
    public var archNames: [String] {
        arches.map(\.archName)
    }

    /// Parse a fat binary from data.
    public init(data: Data) throws(MachOError) {
        guard data.count >= 8 else {
            throw .dataTooSmall(expected: 8, actual: data.count)
        }

        // Read magic as big endian (fat headers are always big endian)
        let magic = data.withUnsafeBytes { ptr -> UInt32 in
            UInt32(bigEndian: ptr.loadUnaligned(as: UInt32.self))
        }

        switch magic {
        case FAT_MAGIC:
            self.is64Bit = false
        case FAT_MAGIC_64:
            self.is64Bit = true
        default:
            throw .invalidFatMagic(magic)
        }

        do {
            var cursor = try DataCursor(data: data, offset: 4)
            let nfatArch = try cursor.readBigInt32()

            var arches: [FatArch] = []
            arches.reserveCapacity(Int(nfatArch))

            for _ in 0..<nfatArch {
                if is64Bit {
                    arches.append(try FatArch(cursor64: &cursor))
                } else {
                    arches.append(try FatArch(cursor: &cursor))
                }
            }

            self.arches = arches
        } catch {
            throw .dataTooSmall(expected: 8, actual: data.count)
        }
    }

    /// Find the best matching architecture for the given target.
    ///
    /// The priority order is:
    /// 1. Target architecture, 64-bit
    /// 2. Target architecture, 32-bit
    /// 3. Any architecture, 64-bit
    /// 4. Any architecture, 32-bit
    /// 5. First available architecture
    public func bestMatch(for target: Arch) -> FatArch? {
        let targetType = target.maskedCPUType

        // Target architecture, 64-bit
        if let arch = arches.first(where: { $0.maskedCPUType == targetType && $0.uses64BitABI }) {
            return arch
        }

        // Target architecture, 32-bit
        if let arch = arches.first(where: { $0.maskedCPUType == targetType && !$0.uses64BitABI }) {
            return arch
        }

        // Any architecture, 64-bit
        if let arch = arches.first(where: { $0.uses64BitABI }) {
            return arch
        }

        // Any architecture, 32-bit
        if let arch = arches.first(where: { !$0.uses64BitABI }) {
            return arch
        }

        // First available
        return arches.first
    }

    /// Find an architecture matching the given arch.
    public func arch(matching target: Arch) -> FatArch? {
        arches.first { fatArch in
            fatArch.cputype == target.cputype && fatArch.maskedCPUSubtype == target.maskedCPUSubtype
        }
    }

    /// Check if this fat file contains the given architecture.
    public func contains(_ arch: Arch) -> Bool {
        self.arch(matching: arch) != nil
    }
}

extension FatFile: CustomStringConvertible {
    public var description: String {
        "FatFile(\(arches.count) arches: \(archNames.joined(separator: ", ")))"
    }
}
