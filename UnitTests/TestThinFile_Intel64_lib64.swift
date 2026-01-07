import XCTest

final class TestThinFile_Intel64_lib64: XCTestCase {
  private var machoX86_64: CDMachOFile!

  override func setUp() {
    super.setUp()

    machoX86_64 = CDMachOFile()
    machoX86_64.cputype = CPU_TYPE_X86_64
    machoX86_64.cpusubtype = cpuSubtype386 | cpuSubtypeLib64
  }

  override func tearDown() {
    machoX86_64 = nil

    super.tearDown()
  }

  func testBestMatchIntel64() {
    var arch = CDArch(cputype: CPU_TYPE_X86_64, cpusubtype: cpuSubtype386)

    let result = machoX86_64.bestMatch(for: &arch)
    XCTAssertTrue(result, "Didn't find a best match for x86_64")
    XCTAssertEqual(arch.cputype, CPU_TYPE_X86_64, "Best match cputype should be CPU_TYPE_X86_64")
    XCTAssertEqual(
      arch.cpusubtype,
      cpuSubtype386 | cpuSubtypeLib64,
      "Best match cpusubtype should be CPU_SUBTYPE_386"
    )
  }

  func testMachOFileWithArch_x86_64() {
    let arch = CDArch(cputype: CPU_TYPE_X86_64, cpusubtype: cpuSubtype386)
    let machOFile = machoX86_64.machOFile(with: arch)
    XCTAssertNotNil(machOFile, "The Mach-O file shouldn't be nil")
    XCTAssertTrue(machOFile === machoX86_64, "Didn't find correct Mach-O file")
  }

  func testMachOFileWithArch_i386() {
    let arch = CDArch(cputype: CPU_TYPE_X86, cpusubtype: cpuSubtype386)
    let machOFile = machoX86_64.machOFile(with: arch)
    XCTAssertNil(machOFile, "The Mach-O file should be nil")
  }
}
