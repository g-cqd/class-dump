import Foundation
import MachO

/// Dylib load command (LC_LOAD_DYLIB, LC_ID_DYLIB, etc.).
public struct DylibCommand: LoadCommandProtocol, Sendable {
  public let cmd: UInt32
  public let cmdsize: UInt32
  public let name: String
  public let timestamp: UInt32
  public let currentVersion: Version
  public let compatibilityVersion: Version

  /// Parse version from packed format (major.minor.patch in 32 bits).
  public struct Version: Sendable, CustomStringConvertible {
    public let major: UInt16
    public let minor: UInt8
    public let patch: UInt8

    public init(packed: UInt32) {
      self.major = UInt16((packed >> 16) & 0xFFFF)
      self.minor = UInt8((packed >> 8) & 0xFF)
      self.patch = UInt8(packed & 0xFF)
    }

    public var description: String {
      if patch == 0 {
        return "\(major).\(minor)"
      }
      return "\(major).\(minor).\(patch)"
    }
  }

  /// The type of dylib command.
  public var dylibType: DylibType {
    switch cmd {
    case UInt32(LC_LOAD_DYLIB): return .load
    case UInt32(LC_ID_DYLIB): return .id
    case UInt32(LC_LOAD_WEAK_DYLIB): return .loadWeak
    case UInt32(LC_REEXPORT_DYLIB): return .reexport
    case UInt32(LC_LAZY_LOAD_DYLIB): return .lazyLoad
    case UInt32(LC_LOAD_UPWARD_DYLIB): return .loadUpward
    default: return .unknown
    }
  }

  public enum DylibType: Sendable {
    case load
    case id
    case loadWeak
    case reexport
    case lazyLoad
    case loadUpward
    case unknown
  }

  public init(data: Data, byteOrder: ByteOrder) throws {
    do {
      var cursor = try DataCursor(data: data, offset: 0)

      if byteOrder == .little {
        self.cmd = try cursor.readLittleInt32()
        self.cmdsize = try cursor.readLittleInt32()
        let nameOffset = try cursor.readLittleInt32()
        self.timestamp = try cursor.readLittleInt32()
        self.currentVersion = Version(packed: try cursor.readLittleInt32())
        self.compatibilityVersion = Version(packed: try cursor.readLittleInt32())

        // Read name string starting at nameOffset
        cursor = try DataCursor(data: data, offset: Int(nameOffset))
        self.name = try cursor.readCString()
      } else {
        self.cmd = try cursor.readBigInt32()
        self.cmdsize = try cursor.readBigInt32()
        let nameOffset = try cursor.readBigInt32()
        self.timestamp = try cursor.readBigInt32()
        self.currentVersion = Version(packed: try cursor.readBigInt32())
        self.compatibilityVersion = Version(packed: try cursor.readBigInt32())

        cursor = try DataCursor(data: data, offset: Int(nameOffset))
        self.name = try cursor.readCString()
      }
    } catch {
      throw LoadCommandError.dataTooSmall(expected: 24, actual: data.count)
    }
  }
}

extension DylibCommand: CustomStringConvertible {
  public var description: String {
    "DylibCommand(\(dylibType), \(name), version: \(currentVersion), compat: \(compatibilityVersion))"
  }
}
