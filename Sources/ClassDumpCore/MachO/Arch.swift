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
    // Try the system function (deprecated but still works)
    if let archInfo = NXGetArchInfoFromCpuType(cputype, cpusubtype),
       let cName = archInfo.pointee.name {
      return String(cString: cName)
    }

    // Fall back to special cases not recognized by the system
    switch cputype {
    case CPU_TYPE_ARM:
      switch cpusubtype {
      case 11: return "armv7s"
      default: break
      }
    case CPU_TYPE_ARM | cpu_type_t(CPU_ARCH_ABI64):
      let masked = cpusubtype & ~Int32(bitPattern: CPU_SUBTYPE_MASK)
      switch masked {
      case CPU_SUBTYPE_ARM_ALL: return "arm64"
      case 2: return "arm64e"
      default: break
      }
    default:
      break
    }

    return String(format: "0x%x:0x%x", cputype, cpusubtype)
  }

  /// Creates an Arch from an architecture name string.
  public init?(name: String) {
    guard !name.isEmpty else { return nil }

    // Try the system function first (deprecated but still works)
    if let archInfo = NXGetArchInfoFromName(name) {
      self.cputype = archInfo.pointee.cputype
      self.cpusubtype = archInfo.pointee.cpusubtype
      return
    }

    // Handle special cases
    switch name {
    case "armv7s":
      self.cputype = CPU_TYPE_ARM
      self.cpusubtype = 11
    case "arm64":
      self.cputype = CPU_TYPE_ARM | cpu_type_t(CPU_ARCH_ABI64)
      self.cpusubtype = CPU_SUBTYPE_ARM_ALL
    case "arm64e":
      self.cputype = CPU_TYPE_ARM | cpu_type_t(CPU_ARCH_ABI64)
      self.cpusubtype = 2
    default:
      // Try parsing "0x...:0x..." format
      let parts = name.split(separator: ":")
      guard parts.count == 2,
            let cpu = cpu_type_t(parts[0].dropFirst(2), radix: 16),
            let sub = cpu_subtype_t(parts[1].dropFirst(2), radix: 16) else {
        return nil
      }
      self.cputype = cpu
      self.cpusubtype = sub
    }
  }

  /// The local (host) architecture.
  @available(macOS, deprecated: 13.0)
  public static var local: Arch? {
    guard let archInfo = NXGetLocalArchInfo() else { return nil }
    return Arch(cputype: archInfo.pointee.cputype, cpusubtype: archInfo.pointee.cpusubtype)
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
  public static let x86_64 = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
  public static let arm64 = Arch(cputype: CPU_TYPE_ARM64, cpusubtype: CPU_SUBTYPE_ARM_ALL)
  public static let arm64e = Arch(cputype: CPU_TYPE_ARM64, cpusubtype: 2)
  public static let armv7 = Arch(cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V7)
  public static let armv7s = Arch(cputype: CPU_TYPE_ARM, cpusubtype: 11)
}
