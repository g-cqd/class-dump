import Foundation
import MachO

/// Dylib load command (LC_LOAD_DYLIB, LC_ID_DYLIB, etc.).
public struct DylibCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The path name of the library.
    public let name: String

    /// The timestamp when the library was built.
    public let timestamp: UInt32

    /// The current version of the library.
    public let currentVersion: Version

    /// The compatibility version of the library.
    public let compatibilityVersion: Version

    /// Parse version from packed format (major.minor.patch in 32 bits).
    public struct Version: Sendable, CustomStringConvertible {
        /// The major version component.
        public let major: UInt16

        /// The minor version component.
        public let minor: UInt8

        /// The patch version component.
        public let patch: UInt8

        /// Initialize from a packed 32-bit integer.
        public init(packed: UInt32) {
            self.major = UInt16((packed >> 16) & 0xFFFF)
            self.minor = UInt8((packed >> 8) & 0xFF)
            self.patch = UInt8(packed & 0xFF)
        }

        /// A textual description of the version.
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

    /// Dylib load command types.
    public enum DylibType: Sendable {
        case load
        case id
        case loadWeak
        case reexport
        case lazyLoad
        case loadUpward
        case unknown
    }

    /// Parse a dylib command from data.
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
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                let nameOffset = try cursor.readBigInt32()
                self.timestamp = try cursor.readBigInt32()
                self.currentVersion = Version(packed: try cursor.readBigInt32())
                self.compatibilityVersion = Version(packed: try cursor.readBigInt32())

                cursor = try DataCursor(data: data, offset: Int(nameOffset))
                self.name = try cursor.readCString()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 24, actual: data.count)
        }
    }
}

extension DylibCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "DylibCommand(\(dylibType), \(name), version: \(currentVersion), compat: \(compatibilityVersion))"
    }
}
