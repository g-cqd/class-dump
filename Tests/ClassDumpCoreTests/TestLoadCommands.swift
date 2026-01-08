import Foundation
import Testing
import MachO
@testable import ClassDumpCore

@Suite("LoadCommandType Tests", .serialized)
struct TestLoadCommandType {
  @Test("Load command type names")
  func testLoadCommandTypeNames() {
    #expect(LoadCommandType.segment.name == "LC_SEGMENT")
    #expect(LoadCommandType.segment64.name == "LC_SEGMENT_64")
    #expect(LoadCommandType.symtab.name == "LC_SYMTAB")
    #expect(LoadCommandType.dysymtab.name == "LC_DYSYMTAB")
    #expect(LoadCommandType.uuid.name == "LC_UUID")
    #expect(LoadCommandType.main.name == "LC_MAIN")
    #expect(LoadCommandType.buildVersion.name == "LC_BUILD_VERSION")
  }

  @Test("Must understand to execute")
  func testMustUnderstandToExecute() {
    #expect(LoadCommandType.main.mustUnderstandToExecute == true)
    #expect(LoadCommandType.dyldInfoOnly.mustUnderstandToExecute == true)
    #expect(LoadCommandType.loadWeakDylib.mustUnderstandToExecute == true)
    #expect(LoadCommandType.segment.mustUnderstandToExecute == false)
    #expect(LoadCommandType.uuid.mustUnderstandToExecute == false)
  }

  @Test("Name for unknown command")
  func testUnknownCommandName() {
    let name = LoadCommandType.name(for: 0xDEADBEEF)
    #expect(name.contains("UNKNOWN"))
    #expect(name.contains("deadbeef"))
  }
}

@Suite("SegmentCommand Tests", .serialized)
struct TestSegmentCommand {
  @Test("Parse 64-bit segment command")
  func testParse64BitSegment() throws {
    // Create a minimal LC_SEGMENT_64 command
    var data = Data()

    // cmd (LC_SEGMENT_64 = 0x19)
    var cmd: UInt32 = UInt32(LC_SEGMENT_64)
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    // cmdsize (72 bytes for 64-bit segment header with no sections)
    var cmdsize: UInt32 = 72
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    // segname (16 bytes, "__TEXT")
    var segname = "__TEXT".padding(toLength: 16, withPad: "\0", startingAt: 0)
    data.append(segname.data(using: .ascii)!)

    // vmaddr (64-bit)
    var vmaddr: UInt64 = 0x100000000
    data.append(contentsOf: withUnsafeBytes(of: &vmaddr) { Array($0) })

    // vmsize (64-bit)
    var vmsize: UInt64 = 0x10000
    data.append(contentsOf: withUnsafeBytes(of: &vmsize) { Array($0) })

    // fileoff (64-bit)
    var fileoff: UInt64 = 0
    data.append(contentsOf: withUnsafeBytes(of: &fileoff) { Array($0) })

    // filesize (64-bit)
    var filesize: UInt64 = 0x10000
    data.append(contentsOf: withUnsafeBytes(of: &filesize) { Array($0) })

    // maxprot
    var maxprot: Int32 = 7 // rwx
    data.append(contentsOf: withUnsafeBytes(of: &maxprot) { Array($0) })

    // initprot
    var initprot: Int32 = 5 // rx
    data.append(contentsOf: withUnsafeBytes(of: &initprot) { Array($0) })

    // nsects
    var nsects: UInt32 = 0
    data.append(contentsOf: withUnsafeBytes(of: &nsects) { Array($0) })

    // flags
    var flags: UInt32 = 0
    data.append(contentsOf: withUnsafeBytes(of: &flags) { Array($0) })

    let segment = try SegmentCommand(data: data, byteOrder: .little, is64Bit: true)

    #expect(segment.cmd == UInt32(LC_SEGMENT_64))
    #expect(segment.cmdsize == 72)
    #expect(segment.name == "__TEXT")
    #expect(segment.vmaddr == 0x100000000)
    #expect(segment.vmsize == 0x10000)
    #expect(segment.fileoff == 0)
    #expect(segment.filesize == 0x10000)
    #expect(segment.initprot == 5)
    #expect(segment.nsects == 0)
    #expect(segment.sections.isEmpty)
    #expect(segment.is64Bit == true)
  }

  @Test("Parse 32-bit segment command")
  func testParse32BitSegment() throws {
    var data = Data()

    // cmd (LC_SEGMENT = 0x1)
    var cmd: UInt32 = UInt32(LC_SEGMENT)
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    // cmdsize (56 bytes for 32-bit segment header with no sections)
    var cmdsize: UInt32 = 56
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    // segname (16 bytes, "__DATA")
    var segname = "__DATA".padding(toLength: 16, withPad: "\0", startingAt: 0)
    data.append(segname.data(using: .ascii)!)

    // vmaddr (32-bit)
    var vmaddr: UInt32 = 0x1000
    data.append(contentsOf: withUnsafeBytes(of: &vmaddr) { Array($0) })

    // vmsize (32-bit)
    var vmsize: UInt32 = 0x1000
    data.append(contentsOf: withUnsafeBytes(of: &vmsize) { Array($0) })

    // fileoff (32-bit)
    var fileoff: UInt32 = 0x1000
    data.append(contentsOf: withUnsafeBytes(of: &fileoff) { Array($0) })

    // filesize (32-bit)
    var filesize: UInt32 = 0x1000
    data.append(contentsOf: withUnsafeBytes(of: &filesize) { Array($0) })

    // maxprot
    var maxprot: Int32 = 7
    data.append(contentsOf: withUnsafeBytes(of: &maxprot) { Array($0) })

    // initprot
    var initprot: Int32 = 3 // rw
    data.append(contentsOf: withUnsafeBytes(of: &initprot) { Array($0) })

    // nsects
    var nsects: UInt32 = 0
    data.append(contentsOf: withUnsafeBytes(of: &nsects) { Array($0) })

    // flags
    var flags: UInt32 = 0
    data.append(contentsOf: withUnsafeBytes(of: &flags) { Array($0) })

    let segment = try SegmentCommand(data: data, byteOrder: .little, is64Bit: false)

    #expect(segment.cmd == UInt32(LC_SEGMENT))
    #expect(segment.name == "__DATA")
    #expect(segment.vmaddr == 0x1000)
    #expect(segment.is64Bit == false)
  }

  @Test("Segment contains address")
  func testSegmentContainsAddress() throws {
    var data = Data()

    var cmd: UInt32 = UInt32(LC_SEGMENT_64)
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    var cmdsize: UInt32 = 72
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    var segname = "__TEXT".padding(toLength: 16, withPad: "\0", startingAt: 0)
    data.append(segname.data(using: .ascii)!)

    var vmaddr: UInt64 = 0x1000
    data.append(contentsOf: withUnsafeBytes(of: &vmaddr) { Array($0) })

    var vmsize: UInt64 = 0x1000
    data.append(contentsOf: withUnsafeBytes(of: &vmsize) { Array($0) })

    // Fill remaining fields
    var zero64: UInt64 = 0
    data.append(contentsOf: withUnsafeBytes(of: &zero64) { Array($0) }) // fileoff
    data.append(contentsOf: withUnsafeBytes(of: &zero64) { Array($0) }) // filesize

    var zero32: UInt32 = 0
    data.append(contentsOf: withUnsafeBytes(of: &zero32) { Array($0) }) // maxprot
    data.append(contentsOf: withUnsafeBytes(of: &zero32) { Array($0) }) // initprot
    data.append(contentsOf: withUnsafeBytes(of: &zero32) { Array($0) }) // nsects
    data.append(contentsOf: withUnsafeBytes(of: &zero32) { Array($0) }) // flags

    let segment = try SegmentCommand(data: data, byteOrder: .little, is64Bit: true)

    #expect(segment.contains(address: 0x1000) == true)
    #expect(segment.contains(address: 0x1500) == true)
    #expect(segment.contains(address: 0x1FFF) == true)
    #expect(segment.contains(address: 0x2000) == false)
    #expect(segment.contains(address: 0x0FFF) == false)
  }

  @Test("Segment flags description")
  func testSegmentFlagsDescription() {
    let noFlags = SegmentFlags(rawValue: 0)
    #expect(noFlags.description == "none")

    let protected = SegmentFlags.protectedVersion1
    #expect(protected.description.contains("PROTECTED"))

    let multiple = SegmentFlags([.highVM, .noReloc])
    #expect(multiple.description.contains("HIGHVM"))
    #expect(multiple.description.contains("NORELOC"))
  }
}

@Suite("SymtabCommand Tests", .serialized)
struct TestSymtabCommand {
  @Test("Parse symtab command")
  func testParseSymtab() throws {
    var data = Data()

    var cmd: UInt32 = UInt32(LC_SYMTAB)
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    var cmdsize: UInt32 = 24
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    var symoff: UInt32 = 0x1000
    data.append(contentsOf: withUnsafeBytes(of: &symoff) { Array($0) })

    var nsyms: UInt32 = 100
    data.append(contentsOf: withUnsafeBytes(of: &nsyms) { Array($0) })

    var stroff: UInt32 = 0x2000
    data.append(contentsOf: withUnsafeBytes(of: &stroff) { Array($0) })

    var strsize: UInt32 = 5000
    data.append(contentsOf: withUnsafeBytes(of: &strsize) { Array($0) })

    let symtab = try SymtabCommand(data: data, byteOrder: .little)

    #expect(symtab.cmd == UInt32(LC_SYMTAB))
    #expect(symtab.cmdsize == 24)
    #expect(symtab.symoff == 0x1000)
    #expect(symtab.nsyms == 100)
    #expect(symtab.stroff == 0x2000)
    #expect(symtab.strsize == 5000)
  }
}

@Suite("Symbol Tests", .serialized)
struct TestSymbol {
  @Test("Symbol type flags")
  func testSymbolTypeFlags() {
    let external = SymbolTypeFlags(rawValue: UInt8(N_EXT))
    #expect(external.isExternal == true)

    let defined = SymbolTypeFlags(rawValue: UInt8(N_SECT) | UInt8(N_EXT))
    #expect(defined.isExternal == true)
    #expect(defined.isInSection == true)
    #expect(defined.isUndefined == false)
  }

  @Test("Symbol short type description")
  func testSymbolShortType() {
    var nlist = nlist_64()
    nlist.n_type = UInt8(N_SECT) | UInt8(N_EXT)
    nlist.n_value = 0x1000

    let symbol = Symbol(name: "_main", nlist64: nlist)
    #expect(symbol.shortTypeDescription == "S")  // External in section
    #expect(symbol.isDefined == true)
    #expect(symbol.isExternal == true)
  }

  @Test("ObjC class name extraction")
  func testObjCClassName() {
    let className = Symbol.className(from: "_OBJC_CLASS_$_NSObject")
    #expect(className == "NSObject")

    let nonClass = Symbol.className(from: "_some_function")
    #expect(nonClass == nil)
  }
}

@Suite("UUIDCommand Tests", .serialized)
struct TestUUIDCommand {
  @Test("Parse UUID command")
  func testParseUUID() throws {
    var data = Data()

    var cmd: UInt32 = UInt32(LC_UUID)
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    var cmdsize: UInt32 = 24
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    // Add a known UUID (16 bytes)
    let uuidBytes: [UInt8] = [
      0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
      0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF
    ]
    data.append(contentsOf: uuidBytes)

    let uuidCmd = try UUIDCommand(data: data)

    #expect(uuidCmd.cmd == UInt32(LC_UUID))
    #expect(uuidCmd.cmdsize == 24)
    #expect(uuidCmd.uuidString.count == 36) // UUID string format
  }
}

@Suite("BuildVersionCommand Tests", .serialized)
struct TestBuildVersionCommand {
  @Test("Parse build version command")
  func testParseBuildVersion() throws {
    var data = Data()

    var cmd: UInt32 = UInt32(LC_BUILD_VERSION)
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    var cmdsize: UInt32 = 24
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    var platform: UInt32 = 1 // macOS
    data.append(contentsOf: withUnsafeBytes(of: &platform) { Array($0) })

    // minos = 14.0.0 (packed as 0x000E0000)
    var minos: UInt32 = 0x000E0000
    data.append(contentsOf: withUnsafeBytes(of: &minos) { Array($0) })

    // sdk = 14.0.0
    var sdk: UInt32 = 0x000E0000
    data.append(contentsOf: withUnsafeBytes(of: &sdk) { Array($0) })

    var ntools: UInt32 = 0
    data.append(contentsOf: withUnsafeBytes(of: &ntools) { Array($0) })

    let buildVersion = try BuildVersionCommand(data: data, byteOrder: .little)

    #expect(buildVersion.cmd == UInt32(LC_BUILD_VERSION))
    #expect(buildVersion.platform == .macOS)
    #expect(buildVersion.minos.major == 14)
    #expect(buildVersion.tools.isEmpty)
  }

  @Test("Build platform names")
  func testBuildPlatformNames() {
    #expect(BuildPlatform.macOS.name == "macOS")
    #expect(BuildPlatform.iOS.name == "iOS")
    #expect(BuildPlatform.visionOS.name == "visionOS")
  }
}

@Suite("DylibCommand Tests", .serialized)
struct TestDylibCommand {
  @Test("Parse dylib command")
  func testParseDylib() throws {
    var data = Data()

    var cmd: UInt32 = UInt32(LC_LOAD_DYLIB)
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    var cmdsize: UInt32 = 56 // Will be updated based on string length
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    // name offset (starts after the fixed fields = 24 bytes)
    var nameOffset: UInt32 = 24
    data.append(contentsOf: withUnsafeBytes(of: &nameOffset) { Array($0) })

    var timestamp: UInt32 = 2
    data.append(contentsOf: withUnsafeBytes(of: &timestamp) { Array($0) })

    // current_version = 1.2.3 (packed)
    var currentVersion: UInt32 = (1 << 16) | (2 << 8) | 3
    data.append(contentsOf: withUnsafeBytes(of: &currentVersion) { Array($0) })

    // compatibility_version = 1.0.0
    var compatVersion: UInt32 = (1 << 16)
    data.append(contentsOf: withUnsafeBytes(of: &compatVersion) { Array($0) })

    // Name string
    let name = "/usr/lib/libSystem.B.dylib\0"
    data.append(name.data(using: .utf8)!)

    let dylib = try DylibCommand(data: data, byteOrder: .little)

    #expect(dylib.cmd == UInt32(LC_LOAD_DYLIB))
    #expect(dylib.name == "/usr/lib/libSystem.B.dylib")
    #expect(dylib.currentVersion.major == 1)
    #expect(dylib.currentVersion.minor == 2)
    #expect(dylib.currentVersion.patch == 3)
    #expect(dylib.compatibilityVersion.major == 1)
    #expect(dylib.dylibType == .load)
  }

  @Test("Version string formatting")
  func testVersionString() {
    let version1 = DylibCommand.Version(packed: (1 << 16) | (2 << 8) | 3)
    #expect(version1.description == "1.2.3")

    let version2 = DylibCommand.Version(packed: (10 << 16) | (0 << 8) | 0)
    #expect(version2.description == "10.0")
  }
}

@Suite("MainCommand Tests", .serialized)
struct TestMainCommand {
  @Test("Parse main command")
  func testParseMain() throws {
    var data = Data()

    var cmd: UInt32 = 0x80000028 // LC_MAIN
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    var cmdsize: UInt32 = 24
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    var entryoff: UInt64 = 0x1234
    data.append(contentsOf: withUnsafeBytes(of: &entryoff) { Array($0) })

    var stacksize: UInt64 = 0
    data.append(contentsOf: withUnsafeBytes(of: &stacksize) { Array($0) })

    let main = try MainCommand(data: data, byteOrder: .little)

    #expect(main.cmd == 0x80000028)
    #expect(main.entryoff == 0x1234)
    #expect(main.stacksize == 0)
    #expect(main.mustUnderstandToExecute == true)
  }
}

@Suite("SourceVersionCommand Tests", .serialized)
struct TestSourceVersionCommand {
  @Test("Parse source version command")
  func testParseSourceVersion() throws {
    var data = Data()

    var cmd: UInt32 = UInt32(LC_SOURCE_VERSION)
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    var cmdsize: UInt32 = 16
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    // Version 1.2.3.4.5 packed
    // A.B.C.D.E where A is 24 bits, B-E are 10 bits each
    var version: UInt64 = (1 << 40) | (2 << 30) | (3 << 20) | (4 << 10) | 5
    data.append(contentsOf: withUnsafeBytes(of: &version) { Array($0) })

    let srcVersion = try SourceVersionCommand(data: data, byteOrder: .little)

    #expect(srcVersion.cmd == UInt32(LC_SOURCE_VERSION))
    #expect(srcVersion.versionString == "1.2.3.4.5")
  }
}

@Suite("EncryptionInfoCommand Tests", .serialized)
struct TestEncryptionInfoCommand {
  @Test("Parse encryption info command")
  func testParseEncryptionInfo() throws {
    var data = Data()

    var cmd: UInt32 = UInt32(LC_ENCRYPTION_INFO_64)
    data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

    var cmdsize: UInt32 = 24
    data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

    var cryptoff: UInt32 = 0x4000
    data.append(contentsOf: withUnsafeBytes(of: &cryptoff) { Array($0) })

    var cryptsize: UInt32 = 0x10000
    data.append(contentsOf: withUnsafeBytes(of: &cryptsize) { Array($0) })

    var cryptid: UInt32 = 0 // Not encrypted
    data.append(contentsOf: withUnsafeBytes(of: &cryptid) { Array($0) })

    var pad: UInt32 = 0
    data.append(contentsOf: withUnsafeBytes(of: &pad) { Array($0) })

    let encInfo = try EncryptionInfoCommand(data: data, byteOrder: .little, is64Bit: true)

    #expect(encInfo.cmd == UInt32(LC_ENCRYPTION_INFO_64))
    #expect(encInfo.cryptoff == 0x4000)
    #expect(encInfo.cryptsize == 0x10000)
    #expect(encInfo.isEncrypted == false)
  }
}

@Suite("SegmentEncryptionType Tests", .serialized)
struct TestSegmentEncryptionType {
  @Test("Encryption type from magic")
  func testEncryptionTypeFromMagic() {
    let none = SegmentEncryptionType(magic: SegmentEncryptionType.magicNone)
    #expect(none.canDecrypt == true)

    let aes = SegmentEncryptionType(magic: SegmentEncryptionType.magicAES)
    #expect(aes.canDecrypt == true)

    let blowfish = SegmentEncryptionType(magic: SegmentEncryptionType.magicBlowfish)
    #expect(blowfish.canDecrypt == true)

    let unknown = SegmentEncryptionType(magic: 0xDEADBEEF)
    #expect(unknown.canDecrypt == false)
  }
}
