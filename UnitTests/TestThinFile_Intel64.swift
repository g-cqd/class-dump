import XCTest

final class TestThinFile_Intel64: XCTestCase {
  private var machoX86_64: CDMachOFile!

  override func setUp() {
    super.setUp()

    machoX86_64 = CDMachOFile()
    machoX86_64.cputype = CPU_TYPE_X86_64
    machoX86_64.cpusubtype = CPU_SUBTYPE_386
  }

  override func tearDown() {
    machoX86_64 = nil

    super.tearDown()
  }

  func testBestMatchIntel64() {
    var arch = CDArch(cputype: CPU_TYPE_X86_64, cpusubtype: CPU_SUBTYPE_386)

    let result = machoX86_64.bestMatch(forArch: &arch)
    XCTAssertTrue(result, "Didn't find a best match for x86_64")
    XCTAssertEqual(arch.cputype, CPU_TYPE_X86_64, "Best match cputype should be CPU_TYPE_X86_64")
    XCTAssertEqual(arch.cpusubtype, CPU_SUBTYPE_386, "Best match cpusubtype should be CPU_SUBTYPE_386")
  }

  func testMachOFileWithArch_x86_64() {
    let arch = CDArch(cputype: CPU_TYPE_X86_64, cpusubtype: CPU_SUBTYPE_386)
    let machOFile = machoX86_64.machOFile(withArch: arch)
    XCTAssertNotNil(machOFile, "The Mach-O file shouldn't be nil")
    XCTAssertTrue(machOFile === machoX86_64, "Didn't find correct Mach-O file")
  }

  func testMachOFileWithArch_i386() {
    let arch = CDArch(cputype: CPU_TYPE_X86, cpusubtype: CPU_SUBTYPE_386)
    let machOFile = machoX86_64.machOFile(withArch: arch)
    XCTAssertNil(machOFile, "The Mach-O file should be nil")
  }
}
