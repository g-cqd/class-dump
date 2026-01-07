import XCTest

final class TestFatFile_Intel32_64: XCTestCase {
  private var fatFile: CDFatFile!
  private var archI386: CDFatArch!
  private var archX86_64: CDFatArch!
  private var machoI386: CDMachOFile!
  private var machoX86_64: CDMachOFile!

  override func setUp() {
    super.setUp()

    fatFile = CDFatFile()

    machoI386 = CDMachOFile()
    machoI386.cputype = CPU_TYPE_X86
    machoI386.cpusubtype = CPU_SUBTYPE_386

    archI386 = CDFatArch(machOFile: machoI386)
    fatFile.addArchitecture(archI386)

    machoX86_64 = CDMachOFile()
    machoX86_64.cputype = CPU_TYPE_X86_64
    machoX86_64.cpusubtype = CPU_SUBTYPE_386

    archX86_64 = CDFatArch(machOFile: machoX86_64)
    fatFile.addArchitecture(archX86_64)
  }

  override func tearDown() {
    fatFile = nil
    archI386 = nil
    archX86_64 = nil
    machoI386 = nil
    machoX86_64 = nil

    super.tearDown()
  }

  func testBestMatchIntel64() {
    var arch = CDArch(cputype: CPU_TYPE_X86_64, cpusubtype: CPU_SUBTYPE_386)

    let result = fatFile.bestMatch(forArch: &arch)
    XCTAssertTrue(result, "Didn't find a best match for x86_64")
    XCTAssertEqual(arch.cputype, CPU_TYPE_X86_64, "Best match cputype should be CPU_TYPE_X86_64")
    XCTAssertEqual(arch.cpusubtype, CPU_SUBTYPE_386, "Best match cpusubtype should be CPU_SUBTYPE_386")
  }

  func testMachOFileWithArch_x86_64() {
    let arch = CDArch(cputype: CPU_TYPE_X86_64, cpusubtype: CPU_SUBTYPE_386)
    let machOFile = fatFile.machOFile(withArch: arch)
    XCTAssertNotNil(machOFile, "The Mach-O file shouldn't be nil")
    XCTAssertTrue(machOFile === machoX86_64, "Didn't find correct Mach-O file")
  }

  func testMachOFileWithArch_i386() {
    let arch = CDArch(cputype: CPU_TYPE_X86, cpusubtype: CPU_SUBTYPE_386)
    let machOFile = fatFile.machOFile(withArch: arch)
    XCTAssertNotNil(machOFile, "The Mach-O file shouldn't be nil")
    XCTAssertTrue(machOFile === machoI386, "Didn't find correct Mach-O file")
  }
}
