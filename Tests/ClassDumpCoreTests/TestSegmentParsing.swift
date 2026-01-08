import Foundation
import Testing
import MachO
@testable import ClassDumpCore

@Suite("Chained Fixups Tests", .serialized)
struct TestChainedFixups {

  @Test("Parse modern binary with chained fixups")
  func testParseChainedFixups() throws {
    let path = "/Applications/Xcode.app/Contents/Frameworks/DevToolsCore.framework/Versions/A/DevToolsCore"
    guard FileManager.default.fileExists(atPath: path) else {
      // Skip if Xcode not installed
      return
    }

    let url = URL(fileURLWithPath: path)
    let binary = try MachOBinary(contentsOf: url)
    let machO = try binary.bestMatchForLocal()

    #expect(machO.segments.count > 0)

    // Test ObjC2Processor can parse chained fixup pointers
    let processor = ObjC2Processor(
      data: machO.data,
      segments: machO.segments,
      byteOrder: machO.byteOrder,
      is64Bit: machO.uses64BitABI
    )

    let metadata = try processor.process()

    // DevToolsCore has many ObjC classes
    #expect(metadata.classes.count > 100)

    // Verify class names are valid
    for cls in metadata.classes.prefix(10) {
      #expect(!cls.name.isEmpty)
      // ObjC class names should not contain null bytes
      #expect(!cls.name.contains("\0"))
    }
  }
}
