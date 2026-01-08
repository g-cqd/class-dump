import Foundation
import MachO

/// Errors that can occur when parsing load commands.
public enum LoadCommandError: Error, Equatable {
  case dataTooSmall(expected: Int, actual: Int)
  case invalidCommand(UInt32)
  case invalidOffset(UInt64)
  case stringDecodingFailed
}

/// Protocol for all load command types.
public protocol LoadCommandProtocol: Sendable {
  /// The raw command type value.
  var cmd: UInt32 { get }

  /// The size of this load command in bytes.
  var cmdsize: UInt32 { get }

  /// The command type enum value, if recognized.
  var commandType: LoadCommandType? { get }

  /// Human-readable name of this command.
  var commandName: String { get }

  /// Whether this command must be understood to execute.
  var mustUnderstandToExecute: Bool { get }
}

extension LoadCommandProtocol {
  public var commandType: LoadCommandType? {
    LoadCommandType(rawValue: cmd)
  }

  public var commandName: String {
    LoadCommandType.name(for: cmd)
  }

  public var mustUnderstandToExecute: Bool {
    (cmd & UInt32(LC_REQ_DYLD)) != 0
  }
}

/// Base load command header structure.
public struct LoadCommandHeader: Sendable {
  public let cmd: UInt32
  public let cmdsize: UInt32

  /// Parse a load command header from data.
  public init(cursor: inout DataCursor, byteOrder: ByteOrder) throws(DataCursorError) {
    if byteOrder == .little {
      self.cmd = try cursor.readLittleInt32()
      self.cmdsize = try cursor.readLittleInt32()
    } else {
      self.cmd = try cursor.readBigInt32()
      self.cmdsize = try cursor.readBigInt32()
    }
  }

  /// Parse a load command header directly from data at offset.
  public init(data: Data, offset: Int, byteOrder: ByteOrder) throws(DataCursorError) {
    var cursor = try DataCursor(data: data, offset: offset)
    self = try LoadCommandHeader(cursor: &cursor, byteOrder: byteOrder)
  }
}

/// A generic load command that stores the raw data.
public struct GenericLoadCommand: LoadCommandProtocol, Sendable {
  public let cmd: UInt32
  public let cmdsize: UInt32
  public let data: Data

  public init(cmd: UInt32, cmdsize: UInt32, data: Data) {
    self.cmd = cmd
    self.cmdsize = cmdsize
    self.data = data
  }
}

/// Parsed load command - an enum over all known load command types.
public enum LoadCommand: Sendable {
  case segment(SegmentCommand)
  case symtab(SymtabCommand)
  case dysymtab(DysymtabCommand)
  case dylib(DylibCommand)
  case dylinker(DylinkerCommand)
  case uuid(UUIDCommand)
  case version(VersionCommand)
  case buildVersion(BuildVersionCommand)
  case main(MainCommand)
  case sourceVersion(SourceVersionCommand)
  case encryptionInfo(EncryptionInfoCommand)
  case linkeditData(LinkeditDataCommand)
  case rpath(RpathCommand)
  case dyldInfo(DyldInfoCommand)
  case unknown(GenericLoadCommand)

  /// The raw command type value.
  public var cmd: UInt32 {
    switch self {
    case .segment(let cmd): return cmd.cmd
    case .symtab(let cmd): return cmd.cmd
    case .dysymtab(let cmd): return cmd.cmd
    case .dylib(let cmd): return cmd.cmd
    case .dylinker(let cmd): return cmd.cmd
    case .uuid(let cmd): return cmd.cmd
    case .version(let cmd): return cmd.cmd
    case .buildVersion(let cmd): return cmd.cmd
    case .main(let cmd): return cmd.cmd
    case .sourceVersion(let cmd): return cmd.cmd
    case .encryptionInfo(let cmd): return cmd.cmd
    case .linkeditData(let cmd): return cmd.cmd
    case .rpath(let cmd): return cmd.cmd
    case .dyldInfo(let cmd): return cmd.cmd
    case .unknown(let cmd): return cmd.cmd
    }
  }

  /// The size of this load command in bytes.
  public var cmdsize: UInt32 {
    switch self {
    case .segment(let cmd): return cmd.cmdsize
    case .symtab(let cmd): return cmd.cmdsize
    case .dysymtab(let cmd): return cmd.cmdsize
    case .dylib(let cmd): return cmd.cmdsize
    case .dylinker(let cmd): return cmd.cmdsize
    case .uuid(let cmd): return cmd.cmdsize
    case .version(let cmd): return cmd.cmdsize
    case .buildVersion(let cmd): return cmd.cmdsize
    case .main(let cmd): return cmd.cmdsize
    case .sourceVersion(let cmd): return cmd.cmdsize
    case .encryptionInfo(let cmd): return cmd.cmdsize
    case .linkeditData(let cmd): return cmd.cmdsize
    case .rpath(let cmd): return cmd.cmdsize
    case .dyldInfo(let cmd): return cmd.cmdsize
    case .unknown(let cmd): return cmd.cmdsize
    }
  }

  /// Human-readable name of this command.
  public var commandName: String {
    LoadCommandType.name(for: cmd)
  }

  /// The command type enum value, if recognized.
  public var commandType: LoadCommandType? {
    LoadCommandType(rawValue: cmd)
  }

  /// Whether this command must be understood to execute.
  public var mustUnderstandToExecute: Bool {
    (cmd & UInt32(LC_REQ_DYLD)) != 0
  }
}

// MARK: - Load Command Parsing

extension LoadCommand {
  /// Parse all load commands from a Mach-O file.
  public static func parseAll(
    from data: Data,
    headerSize: Int,
    ncmds: UInt32,
    sizeofcmds: UInt32,
    byteOrder: ByteOrder,
    is64Bit: Bool
  ) throws -> [LoadCommand] {
    var commands: [LoadCommand] = []
    commands.reserveCapacity(Int(ncmds))

    var offset = headerSize
    let endOffset = headerSize + Int(sizeofcmds)

    for _ in 0..<ncmds {
      guard offset + 8 <= data.count else {
        throw LoadCommandError.dataTooSmall(expected: offset + 8, actual: data.count)
      }

      let command = try parse(from: data, at: offset, byteOrder: byteOrder, is64Bit: is64Bit)
      commands.append(command)

      offset += Int(command.cmdsize)
      guard offset <= endOffset else {
        throw LoadCommandError.invalidOffset(UInt64(offset))
      }
    }

    return commands
  }

  /// Parse a single load command from data at the given offset.
  public static func parse(
    from data: Data,
    at offset: Int,
    byteOrder: ByteOrder,
    is64Bit: Bool
  ) throws -> LoadCommand {
    do {
      var cursor = try DataCursor(data: data, offset: offset)
      let header = try LoadCommandHeader(cursor: &cursor, byteOrder: byteOrder)

      // Reset cursor to start of command for individual parsers
      cursor = try DataCursor(data: data, offset: offset)

      let cmdData = data.subdata(in: offset..<(offset + Int(header.cmdsize)))

      switch header.cmd {
      case UInt32(LC_SEGMENT), UInt32(LC_SEGMENT_64):
        return .segment(try SegmentCommand(data: cmdData, byteOrder: byteOrder, is64Bit: header.cmd == UInt32(LC_SEGMENT_64)))

      case UInt32(LC_SYMTAB):
        return .symtab(try SymtabCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_DYSYMTAB):
        return .dysymtab(try DysymtabCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_LOAD_DYLIB), UInt32(LC_ID_DYLIB), UInt32(LC_LOAD_WEAK_DYLIB),
           UInt32(LC_REEXPORT_DYLIB), UInt32(LC_LAZY_LOAD_DYLIB), UInt32(LC_LOAD_UPWARD_DYLIB):
        return .dylib(try DylibCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_LOAD_DYLINKER), UInt32(LC_ID_DYLINKER), UInt32(LC_DYLD_ENVIRONMENT):
        return .dylinker(try DylinkerCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_UUID):
        return .uuid(try UUIDCommand(data: cmdData))

      case UInt32(LC_VERSION_MIN_MACOSX), UInt32(LC_VERSION_MIN_IPHONEOS),
           UInt32(LC_VERSION_MIN_TVOS), UInt32(LC_VERSION_MIN_WATCHOS):
        return .version(try VersionCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_BUILD_VERSION):
        return .buildVersion(try BuildVersionCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_MAIN):
        return .main(try MainCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_SOURCE_VERSION):
        return .sourceVersion(try SourceVersionCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_ENCRYPTION_INFO), UInt32(LC_ENCRYPTION_INFO_64):
        return .encryptionInfo(try EncryptionInfoCommand(data: cmdData, byteOrder: byteOrder, is64Bit: header.cmd == UInt32(LC_ENCRYPTION_INFO_64)))

      case UInt32(LC_CODE_SIGNATURE), UInt32(LC_SEGMENT_SPLIT_INFO), UInt32(LC_FUNCTION_STARTS),
           UInt32(LC_DATA_IN_CODE), UInt32(LC_DYLIB_CODE_SIGN_DRS), UInt32(LC_LINKER_OPTIMIZATION_HINT),
           UInt32(LC_DYLD_EXPORTS_TRIE), UInt32(LC_DYLD_CHAINED_FIXUPS):
        return .linkeditData(try LinkeditDataCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_RPATH):
        return .rpath(try RpathCommand(data: cmdData, byteOrder: byteOrder))

      case UInt32(LC_DYLD_INFO), UInt32(LC_DYLD_INFO_ONLY):
        return .dyldInfo(try DyldInfoCommand(data: cmdData, byteOrder: byteOrder))

      default:
        return .unknown(GenericLoadCommand(cmd: header.cmd, cmdsize: header.cmdsize, data: cmdData))
      }
    } catch _ as DataCursorError {
      throw LoadCommandError.dataTooSmall(expected: 0, actual: data.count)
    }
  }
}

// MARK: - CustomStringConvertible

extension LoadCommand: CustomStringConvertible {
  public var description: String {
    "\(commandName) (size: \(cmdsize))"
  }
}
