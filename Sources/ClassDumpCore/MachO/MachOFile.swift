import Foundation
import MachO

/// Represents a parsed Mach-O file (single architecture).
public struct MachOFile: Sendable {
  public let data: Data
  public let header: MachOHeader
  public let filename: String?

  /// Parsed load commands (lazily computed).
  public let loadCommands: [LoadCommand]

  /// Segment commands extracted from load commands.
  public var segments: [SegmentCommand] {
    loadCommands.compactMap { cmd in
      if case .segment(let seg) = cmd { return seg }
      return nil
    }
  }

  /// The byte order for reading multi-byte values.
  public var byteOrder: ByteOrder {
    header.byteOrder
  }

  /// Whether this file uses 64-bit ABI.
  public var uses64BitABI: Bool {
    header.uses64BitABI
  }

  /// The pointer size for this architecture.
  public var ptrSize: Int {
    uses64BitABI ? 8 : 4
  }

  /// The architecture of this file.
  public var arch: Arch {
    header.arch
  }

  /// The architecture name.
  public var archName: String {
    arch.name
  }

  /// Parse a Mach-O file from data.
  public init(data: Data, filename: String? = nil) throws(MachOError) {
    self.data = data
    self.filename = filename
    self.header = try MachOHeader(data: data)

    // Parse load commands
    do {
      self.loadCommands = try LoadCommand.parseAll(
        from: data,
        headerSize: header.headerSize,
        ncmds: header.ncmds,
        sizeofcmds: header.sizeofcmds,
        byteOrder: header.byteOrder,
        is64Bit: header.uses64BitABI
      )
    } catch {
      // Convert LoadCommandError to MachOError
      throw .invalidLoadCommand
    }
  }

  /// Get the segment containing the given virtual address.
  public func segment(containing address: UInt64) -> SegmentCommand? {
    segments.first { $0.contains(address: address) }
  }

  /// Get the data offset for a virtual address.
  public func dataOffset(for address: UInt64) -> UInt64? {
    guard let segment = segment(containing: address) else { return nil }
    return segment.fileoff + (address - segment.vmaddr)
  }

  /// Get the section for the given name in the given segment.
  public func section(named sectionName: String, inSegment segmentName: String) -> Section? {
    for segment in segments where segment.name == segmentName {
      for section in segment.sections where section.sectionName == sectionName {
        return section
      }
    }
    return nil
  }

  /// Read data at a virtual address.
  public func readData(at address: UInt64, size: Int) -> Data? {
    guard let offset = dataOffset(for: address),
          Int(offset) + size <= data.count else { return nil }
    return data.subdata(in: Int(offset)..<(Int(offset) + size))
  }
}

extension MachOFile: CustomStringConvertible {
  public var description: String {
    var desc = "MachOFile(\(header.magicDescription), \(archName), \(header.filetypeDescription)"
    if let filename = filename {
      desc += ", \(filename)"
    }
    desc += ")"
    return desc
  }
}

// MARK: - Universal Binary Support

/// Represents either a fat (universal) binary or a single Mach-O file.
public enum MachOBinary: Sendable {
  case fat(FatFile, Data)
  case thin(MachOFile)

  /// Load a Mach-O binary from data (auto-detects fat vs thin).
  public init(data: Data, filename: String? = nil) throws(MachOError) {
    guard data.count >= 4 else {
      throw .dataTooSmall(expected: 4, actual: data.count)
    }

    // Check magic
    let magic = data.withUnsafeBytes { ptr -> UInt32 in
      UInt32(bigEndian: ptr.loadUnaligned(as: UInt32.self))
    }

    switch magic {
    case FAT_MAGIC, FAT_MAGIC_64:
      let fatFile = try FatFile(data: data)
      self = .fat(fatFile, data)
    case MH_MAGIC, MH_CIGAM, MH_MAGIC_64, MH_CIGAM_64:
      let machOFile = try MachOFile(data: data, filename: filename)
      self = .thin(machOFile)
    default:
      throw .invalidMagic(magic)
    }
  }

  /// Load a Mach-O binary from a file path.
  public init(contentsOf url: URL) throws {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    try self.init(data: data, filename: url.path)
  }

  /// Whether this is a fat (universal) binary.
  public var isFat: Bool {
    if case .fat = self { return true }
    return false
  }

  /// The available architectures.
  public var architectures: [Arch] {
    switch self {
    case .fat(let fatFile, _):
      return fatFile.arches.map(\.arch)
    case .thin(let machOFile):
      return [machOFile.arch]
    }
  }

  /// The architecture names.
  public var archNames: [String] {
    architectures.map(\.name)
  }

  /// Get the best matching Mach-O file for the local architecture.
  public func bestMatchForLocal() throws(MachOError) -> MachOFile {
    guard let localArch = Arch.local else {
      // Fall back to first available
      return try machOFile(for: architectures.first ?? .arm64)
    }
    return try bestMatch(for: localArch)
  }

  /// Get the best matching Mach-O file for the given architecture.
  public func bestMatch(for arch: Arch) throws(MachOError) -> MachOFile {
    switch self {
    case .fat(let fatFile, let data):
      guard let fatArch = fatFile.bestMatch(for: arch) else {
        throw .architectureNotFound(arch)
      }
      let start = Int(fatArch.offset)
      let end = start + Int(fatArch.size)
      guard end <= data.count else {
        throw .dataTooSmall(expected: end, actual: data.count)
      }
      let sliceData = data[start..<end]
      return try MachOFile(data: Data(sliceData))

    case .thin(let machOFile):
      return machOFile
    }
  }

  /// Get a Mach-O file for a specific architecture.
  public func machOFile(for arch: Arch) throws(MachOError) -> MachOFile {
    switch self {
    case .fat(let fatFile, let data):
      guard let fatArch = fatFile.arch(matching: arch) else {
        throw .architectureNotFound(arch)
      }
      let start = Int(fatArch.offset)
      let end = start + Int(fatArch.size)
      guard end <= data.count else {
        throw .dataTooSmall(expected: end, actual: data.count)
      }
      let sliceData = data[start..<end]
      return try MachOFile(data: Data(sliceData))

    case .thin(let machOFile):
      if machOFile.arch.matches(arch) {
        return machOFile
      }
      throw .architectureNotFound(arch)
    }
  }
}

extension MachOBinary: CustomStringConvertible {
  public var description: String {
    switch self {
    case .fat(let fatFile, _):
      return "MachOBinary(fat: \(fatFile.archNames.joined(separator: ", ")))"
    case .thin(let machOFile):
      return "MachOBinary(thin: \(machOFile.archName))"
    }
  }
}
