import Foundation
import MachO

/// Represents a CPU architecture (cputype + cpusubtype pair).
public struct Arch: Equatable, Hashable, Sendable {
    public var cputype: cpu_type_t
    public var cpusubtype: cpu_subtype_t

    public init(cputype: cpu_type_t = CPU_TYPE_ANY, cpusubtype: cpu_subtype_t = 0) {
        self.cputype = cputype
        self.cpusubtype = cpusubtype
    }

    /// CPU type with architecture mask removed.
    public var maskedCPUType: cpu_type_t {
        // Use bitPattern to safely convert UInt32 mask to Int32 without overflow
        cputype & ~Int32(bitPattern: CPU_ARCH_MASK)
    }

    /// CPU subtype with mask removed.
    public var maskedCPUSubtype: cpu_subtype_t {
        // Use bitPattern to safely convert UInt32 mask to Int32 without overflow
        cpusubtype & ~Int32(bitPattern: CPU_SUBTYPE_MASK)
    }

    /// Whether this architecture uses the 64-bit ABI.
    public var uses64BitABI: Bool {
        (cputype & cpu_type_t(CPU_ARCH_ABI64)) == cpu_type_t(CPU_ARCH_ABI64)
    }

    /// Whether this architecture uses 64-bit libraries.
    public var uses64BitLibraries: Bool {
        // Use bitPattern to safely convert UInt32 constant to Int32 without overflow
        let lib64Mask = Int32(bitPattern: CPU_SUBTYPE_LIB64)
        return (cpusubtype & lib64Mask) == lib64Mask
    }

    /// Returns the architecture name string.
    public var name: String {
        // First try our built-in table for common architectures (avoids deprecated API)
        if let knownName = Self.nameForCPUType(cputype, cpusubtype) {
            return knownName
        }

        // Fall back to system function for less common architectures
        // Note: NXGetArchInfoFromCpuType is deprecated in macOS 13+ but the Swift
        // MachO module doesn't expose the modern replacement (macho_arch_name_for_cpu_type)
        if let archInfo = NXGetArchInfoFromCpuType(cputype, cpusubtype),
            let cName = archInfo.pointee.name
        {
            return String(cString: cName)
        }

        return String(format: "0x%x:0x%x", cputype, cpusubtype)
    }

    /// Creates an Arch from an architecture name string.
    public init?(name: String) {
        guard !name.isEmpty else { return nil }

        // First try our built-in table (avoids deprecated API)
        if let arch = Self.cpuTypeForName(name) {
            self = arch
            return
        }

        // Fall back to system function for less common architectures
        // Note: NXGetArchInfoFromName is deprecated in macOS 13+ but the Swift
        // MachO module doesn't expose the modern replacement (macho_cpu_type_for_arch_name)
        if let archInfo = NXGetArchInfoFromName(name) {
            self.cputype = archInfo.pointee.cputype
            self.cpusubtype = archInfo.pointee.cpusubtype
            return
        }

        // Try parsing "0x...:0x..." format
        let parts = name.split(separator: ":")
        guard parts.count == 2,
            let cpu = cpu_type_t(parts[0].dropFirst(2), radix: 16),
            let sub = cpu_subtype_t(parts[1].dropFirst(2), radix: 16)
        else {
            return nil
        }
        self.cputype = cpu
        self.cpusubtype = sub
    }

    /// The local (host) architecture.
    public static var local: Arch? {
        // Use compile-time known architecture to avoid deprecated API
        #if arch(arm64)
            return .arm64
        #elseif arch(x86_64)
            return .x86_64
        #elseif arch(i386)
            return .i386
        #else
            // Fall back to deprecated API for unknown architectures
            guard let archInfo = NXGetLocalArchInfo() else { return nil }
            return Arch(cputype: archInfo.pointee.cputype, cpusubtype: archInfo.pointee.cpusubtype)
        #endif
    }

    // MARK: - Built-in Architecture Tables

    /// Built-in table mapping CPU type/subtype to names.
    /// This avoids using deprecated NXGetArchInfoFromCpuType for common architectures.
    private static func nameForCPUType(_ cputype: cpu_type_t, _ cpusubtype: cpu_subtype_t) -> String? {
        let masked = cpusubtype & ~Int32(bitPattern: CPU_SUBTYPE_MASK)

        switch cputype {
        case CPU_TYPE_I386:
            return "i386"
        case CPU_TYPE_X86_64:
            if (cpusubtype & Int32(bitPattern: CPU_SUBTYPE_LIB64)) != 0 {
                return "x86_64"
            }
            return "x86_64"
        case CPU_TYPE_ARM:
            switch masked {
            case CPU_SUBTYPE_ARM_V6: return "armv6"
            case CPU_SUBTYPE_ARM_V7: return "armv7"
            case 11: return "armv7s"
            default: return nil
            }
        case CPU_TYPE_ARM64:
            switch masked {
            case CPU_SUBTYPE_ARM_ALL: return "arm64"
            case 2: return "arm64e"
            default: return nil
            }
        default:
            return nil
        }
    }

    /// Built-in table mapping names to CPU type/subtype.
    /// This avoids using deprecated NXGetArchInfoFromName for common architectures.
    private static func cpuTypeForName(_ name: String) -> Arch? {
        switch name {
        case "i386": return .i386
        case "x86_64": return .x86_64
        case "armv6": return Arch(cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V6)
        case "armv7": return .armv7
        case "armv7s": return .armv7s
        case "arm64": return .arm64
        case "arm64e": return .arm64e
        default: return nil
        }
    }

    /// Checks if this arch matches the target arch (ignoring subtype masks).
    public func matches(_ target: Arch) -> Bool {
        cputype == target.cputype && maskedCPUSubtype == target.maskedCPUSubtype
    }
}

extension Arch: CustomStringConvertible {
    public var description: String {
        name
    }
}

// MARK: - Common Architectures

extension Arch {
    // CPU_SUBTYPE_I386_ALL = CPU_SUBTYPE_INTEL(3, 0) = 3
    public static let i386 = Arch(cputype: CPU_TYPE_I386, cpusubtype: 3)
    // CPU_SUBTYPE_X86_64_ALL = 3
    // swift-format-ignore: AlwaysUseLowerCamelCase
    public static let x86_64 = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
    public static let arm64 = Arch(cputype: CPU_TYPE_ARM64, cpusubtype: CPU_SUBTYPE_ARM_ALL)
    public static let arm64e = Arch(cputype: CPU_TYPE_ARM64, cpusubtype: 2)
    public static let armv7 = Arch(cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V7)
    public static let armv7s = Arch(cputype: CPU_TYPE_ARM, cpusubtype: 11)
}
