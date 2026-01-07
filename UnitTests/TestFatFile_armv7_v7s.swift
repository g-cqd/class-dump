import XCTest

final class TestFatFile_armv7_v7s: XCTestCase {
  private var fatFile: CDFatFile!
  private var archV7: CDFatArch!
  private var archV7s: CDFatArch!
  private var machoV7: CDMachOFile!
  private var machoV7s: CDMachOFile!

  override func setUp() {
    super.setUp()

    fatFile = CDFatFile()

    machoV7 = CDMachOFile()
    machoV7.cputype = CPU_TYPE_ARM
    machoV7.cpusubtype = CPU_SUBTYPE_ARM_V7

    archV7 = CDFatArch(machOFile: machoV7)
    fatFile.addArchitecture(archV7)

    machoV7s = CDMachOFile()
    machoV7s.cputype = CPU_TYPE_ARM
    machoV7s.cpusubtype = 11

    archV7s = CDFatArch(machOFile: machoV7s)
    fatFile.addArchitecture(archV7s)
  }

  override func tearDown() {
    fatFile = nil
    archV7 = nil
    archV7s = nil
    machoV7 = nil
    machoV7s = nil

    super.tearDown()
  }

  func testMachOFileWithArch_armv7() {
    let arch = CDArch(cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V7)
    let machOFile = fatFile.machOFile(withArch: arch)
    XCTAssertNotNil(machOFile, "The Mach-O file shouldn't be nil")
    XCTAssertTrue(machOFile === machoV7, "Didn't find correct Mach-O file")
  }

  func testMachOFileWithArch_armv7s() {
    let arch = CDArch(cputype: CPU_TYPE_ARM, cpusubtype: 11)
    let machOFile = fatFile.machOFile(withArch: arch)
    XCTAssertNotNil(machOFile, "The Mach-O file shouldn't be nil")
    XCTAssertTrue(machOFile === machoV7s, "Didn't find correct Mach-O file")
  }
}
