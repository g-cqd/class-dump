import Foundation
import MachO

// MARK: - Dylinker Command

/// Dylinker load command (LC_LOAD_DYLINKER, LC_ID_DYLINKER, LC_DYLD_ENVIRONMENT).
public struct DylinkerCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The dynamic linker path name.
    public let name: String

    /// Parse a dylinker command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                let nameOffset = try cursor.readLittleInt32()
                cursor = try DataCursor(data: data, offset: Int(nameOffset))
                self.name = try cursor.readCString()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                let nameOffset = try cursor.readBigInt32()
                cursor = try DataCursor(data: data, offset: Int(nameOffset))
                self.name = try cursor.readCString()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 12, actual: data.count)
        }
    }
}

extension DylinkerCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "DylinkerCommand(\(commandName), \(name))"
    }
}

// MARK: - UUID Command

/// UUID load command (LC_UUID).
public struct UUIDCommand: LoadCommandProtocol, Sendable {
    /// The command type (LC_UUID).
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The UUID value.
    public let uuid: UUID

    /// Parse a UUID command from data.
    public init(data: Data) throws {
        guard data.count >= 24 else {
            throw LoadCommandError.dataTooSmall(expected: 24, actual: data.count)
        }

        self.cmd = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }
        self.cmdsize = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) }

        // Read 16-byte UUID
        let uuidBytes = data.subdata(in: 8..<24)
        self.uuid = uuidBytes.withUnsafeBytes { ptr in
            UUID(uuid: ptr.loadUnaligned(as: uuid_t.self))
        }
    }

    /// The string representation of the UUID.
    public var uuidString: String {
        uuid.uuidString
    }
}

extension UUIDCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "UUIDCommand(\(uuidString))"
    }
}

// MARK: - Version Commands

/// Version minimum load command (LC_VERSION_MIN_*).
public struct VersionCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The minimum OS version.
    public let version: DylibCommand.Version

    /// The SDK version.
    public let sdk: DylibCommand.Version

    /// The platform this command targets.
    public var platform: Platform {
        switch cmd {
            case UInt32(LC_VERSION_MIN_MACOSX): return .macOS
            case UInt32(LC_VERSION_MIN_IPHONEOS): return .iOS
            case UInt32(LC_VERSION_MIN_TVOS): return .tvOS
            case UInt32(LC_VERSION_MIN_WATCHOS): return .watchOS
            default: return .unknown
        }
    }

    /// Supported platforms.
    public enum Platform: Sendable {
        case macOS
        case iOS
        case tvOS
        case watchOS
        case unknown
    }

    /// Parse a version command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.version = DylibCommand.Version(packed: try cursor.readLittleInt32())
                self.sdk = DylibCommand.Version(packed: try cursor.readLittleInt32())
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.version = DylibCommand.Version(packed: try cursor.readBigInt32())
                self.sdk = DylibCommand.Version(packed: try cursor.readBigInt32())
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 16, actual: data.count)
        }
    }
}

extension VersionCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "VersionCommand(\(platform), version: \(version), sdk: \(sdk))"
    }
}

// MARK: - Build Version Command

/// Build platform type.
public enum BuildPlatform: UInt32, Sendable {
    case macOS = 1
    case iOS = 2
    case tvOS = 3
    case watchOS = 4
    case bridgeOS = 5
    case macCatalyst = 6
    case iOSSimulator = 7
    case tvOSSimulator = 8
    case watchOSSimulator = 9
    case driverKit = 10
    case visionOS = 11
    case visionOSSimulator = 12

    /// The name of the platform.
    public var name: String {
        switch self {
            case .macOS: return "macOS"
            case .iOS: return "iOS"
            case .tvOS: return "tvOS"
            case .watchOS: return "watchOS"
            case .bridgeOS: return "bridgeOS"
            case .macCatalyst: return "macCatalyst"
            case .iOSSimulator: return "iOS Simulator"
            case .tvOSSimulator: return "tvOS Simulator"
            case .watchOSSimulator: return "watchOS Simulator"
            case .driverKit: return "DriverKit"
            case .visionOS: return "visionOS"
            case .visionOSSimulator: return "visionOS Simulator"
        }
    }
}

/// Build tool version information.
public struct BuildToolVersion: Sendable {
    /// The tool type.
    public let tool: UInt32

    /// The tool version.
    public let version: DylibCommand.Version

    /// The name of the tool.
    public var toolName: String {
        switch tool {
            case 1: return "clang"
            case 2: return "swift"
            case 3: return "ld"
            case 4: return "lld"
            default: return "unknown(\(tool))"
        }
    }
}

/// Build version load command (LC_BUILD_VERSION).
public struct BuildVersionCommand: LoadCommandProtocol, Sendable {
    /// The command type (LC_BUILD_VERSION).
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The target platform.
    public let platform: BuildPlatform?

    /// The raw platform value.
    public let platformRaw: UInt32

    /// The minimum OS version.
    public let minos: DylibCommand.Version

    /// The SDK version.
    public let sdk: DylibCommand.Version

    /// The build tools used.
    public let tools: [BuildToolVersion]

    /// Parse a build version command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.platformRaw = try cursor.readLittleInt32()
                self.minos = DylibCommand.Version(packed: try cursor.readLittleInt32())
                self.sdk = DylibCommand.Version(packed: try cursor.readLittleInt32())
                let ntools = try cursor.readLittleInt32()

                var tools: [BuildToolVersion] = []
                tools.reserveCapacity(Int(ntools))
                for _ in 0..<ntools {
                    let tool = try cursor.readLittleInt32()
                    let version = DylibCommand.Version(packed: try cursor.readLittleInt32())
                    tools.append(BuildToolVersion(tool: tool, version: version))
                }
                self.tools = tools
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.platformRaw = try cursor.readBigInt32()
                self.minos = DylibCommand.Version(packed: try cursor.readBigInt32())
                self.sdk = DylibCommand.Version(packed: try cursor.readBigInt32())
                let ntools = try cursor.readBigInt32()

                var tools: [BuildToolVersion] = []
                tools.reserveCapacity(Int(ntools))
                for _ in 0..<ntools {
                    let tool = try cursor.readBigInt32()
                    let version = DylibCommand.Version(packed: try cursor.readBigInt32())
                    tools.append(BuildToolVersion(tool: tool, version: version))
                }
                self.tools = tools
            }

            self.platform = BuildPlatform(rawValue: platformRaw)
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 24, actual: data.count)
        }
    }
}

extension BuildVersionCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        let platformName = platform?.name ?? "unknown(\(platformRaw))"
        return "BuildVersionCommand(\(platformName), minos: \(minos), sdk: \(sdk))"
    }
}

// MARK: - Main Command

/// Main entry point load command (LC_MAIN).
public struct MainCommand: LoadCommandProtocol, Sendable {
    /// The command type (LC_MAIN).
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The file offset of the entry point.
    public let entryoff: UInt64

    /// The initial stack size.
    public let stacksize: UInt64

    /// Parse a main command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.entryoff = try cursor.readLittleInt64()
                self.stacksize = try cursor.readLittleInt64()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.entryoff = try cursor.readBigInt64()
                self.stacksize = try cursor.readBigInt64()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 24, actual: data.count)
        }
    }
}

extension MainCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "MainCommand(entryoff: 0x\(String(entryoff, radix: 16)), stacksize: \(stacksize))"
    }
}

// MARK: - Source Version Command

/// Source version load command (LC_SOURCE_VERSION).
public struct SourceVersionCommand: LoadCommandProtocol, Sendable {
    /// The command type (LC_SOURCE_VERSION).
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The source version.
    public let version: UInt64

    /// Parsed version components (A.B.C.D.E).
    public var versionString: String {
        let a = (version >> 40) & 0xFFFFFF
        let b = (version >> 30) & 0x3FF
        let c = (version >> 20) & 0x3FF
        let d = (version >> 10) & 0x3FF
        let e = version & 0x3FF
        return "\(a).\(b).\(c).\(d).\(e)"
    }

    /// Parse a source version command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.version = try cursor.readLittleInt64()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.version = try cursor.readBigInt64()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 16, actual: data.count)
        }
    }
}

extension SourceVersionCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "SourceVersionCommand(\(versionString))"
    }
}

// MARK: - Encryption Info Command

/// Encryption info load command (LC_ENCRYPTION_INFO, LC_ENCRYPTION_INFO_64).
public struct EncryptionInfoCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The file offset of the encrypted range.
    public let cryptoff: UInt32

    /// The size of the encrypted range in bytes.
    public let cryptsize: UInt32

    /// The encryption system ID (0 = not encrypted).
    public let cryptid: UInt32

    /// Padding (64-bit only).
    public let pad: UInt32

    /// Whether this is a 64-bit command.
    public let is64Bit: Bool

    /// Whether the segment is encrypted.
    public var isEncrypted: Bool {
        cryptid != 0
    }

    /// Parse an encryption info command from data.
    public init(data: Data, byteOrder: ByteOrder, is64Bit: Bool) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.cryptoff = try cursor.readLittleInt32()
                self.cryptsize = try cursor.readLittleInt32()
                self.cryptid = try cursor.readLittleInt32()
                self.pad = is64Bit ? try cursor.readLittleInt32() : 0
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.cryptoff = try cursor.readBigInt32()
                self.cryptsize = try cursor.readBigInt32()
                self.cryptid = try cursor.readBigInt32()
                self.pad = is64Bit ? try cursor.readBigInt32() : 0
            }

            self.is64Bit = is64Bit
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: is64Bit ? 24 : 20, actual: data.count)
        }
    }
}

extension EncryptionInfoCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "EncryptionInfoCommand(offset: 0x\(String(cryptoff, radix: 16)), size: \(cryptsize), encrypted: \(isEncrypted))"
    }
}

// MARK: - Linkedit Data Command

/// Linkedit data load command (LC_CODE_SIGNATURE, LC_FUNCTION_STARTS, etc.).
public struct LinkeditDataCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The file offset of the data.
    public let dataoff: UInt32

    /// The size of the data in bytes.
    public let datasize: UInt32

    /// Parse a linkedit data command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.dataoff = try cursor.readLittleInt32()
                self.datasize = try cursor.readLittleInt32()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.dataoff = try cursor.readBigInt32()
                self.datasize = try cursor.readBigInt32()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 16, actual: data.count)
        }
    }
}

extension LinkeditDataCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "LinkeditDataCommand(\(commandName), offset: 0x\(String(dataoff, radix: 16)), size: \(datasize))"
    }
}

// MARK: - Rpath Command

/// Runpath load command (LC_RPATH).
public struct RpathCommand: LoadCommandProtocol, Sendable {
    /// The command type (LC_RPATH).
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The runpath string.
    public let path: String

    /// Parse an rpath command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                let pathOffset = try cursor.readLittleInt32()
                cursor = try DataCursor(data: data, offset: Int(pathOffset))
                self.path = try cursor.readCString()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                let pathOffset = try cursor.readBigInt32()
                cursor = try DataCursor(data: data, offset: Int(pathOffset))
                self.path = try cursor.readCString()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 12, actual: data.count)
        }
    }
}

extension RpathCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "RpathCommand(\(path))"
    }
}

// MARK: - Dyld Info Command

/// Dyld info load command (LC_DYLD_INFO, LC_DYLD_INFO_ONLY).
public struct DyldInfoCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    // Rebase info
    /// The file offset of the rebase info.
    public let rebaseOff: UInt32

    /// The size of the rebase info in bytes.
    public let rebaseSize: UInt32

    // Binding info
    /// The file offset of the binding info.
    public let bindOff: UInt32

    /// The size of the binding info in bytes.
    public let bindSize: UInt32

    // Weak binding info
    /// The file offset of the weak binding info.
    public let weakBindOff: UInt32

    /// The size of the weak binding info in bytes.
    public let weakBindSize: UInt32

    // Lazy binding info
    /// The file offset of the lazy binding info.
    public let lazyBindOff: UInt32

    /// The size of the lazy binding info in bytes.
    public let lazyBindSize: UInt32

    // Export info
    /// The file offset of the export info.
    public let exportOff: UInt32

    /// The size of the export info in bytes.
    public let exportSize: UInt32

    /// Parse a dyld info command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.rebaseOff = try cursor.readLittleInt32()
                self.rebaseSize = try cursor.readLittleInt32()
                self.bindOff = try cursor.readLittleInt32()
                self.bindSize = try cursor.readLittleInt32()
                self.weakBindOff = try cursor.readLittleInt32()
                self.weakBindSize = try cursor.readLittleInt32()
                self.lazyBindOff = try cursor.readLittleInt32()
                self.lazyBindSize = try cursor.readLittleInt32()
                self.exportOff = try cursor.readLittleInt32()
                self.exportSize = try cursor.readLittleInt32()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.rebaseOff = try cursor.readBigInt32()
                self.rebaseSize = try cursor.readBigInt32()
                self.bindOff = try cursor.readBigInt32()
                self.bindSize = try cursor.readBigInt32()
                self.weakBindOff = try cursor.readBigInt32()
                self.weakBindSize = try cursor.readBigInt32()
                self.lazyBindOff = try cursor.readBigInt32()
                self.lazyBindSize = try cursor.readBigInt32()
                self.exportOff = try cursor.readBigInt32()
                self.exportSize = try cursor.readBigInt32()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 48, actual: data.count)
        }
    }
}

extension DyldInfoCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "DyldInfoCommand(rebase: \(rebaseSize), bind: \(bindSize), weak: \(weakBindSize), lazy: \(lazyBindSize), export: \(exportSize))"
    }
}
