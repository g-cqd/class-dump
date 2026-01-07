import XCTest

final class TestCDArchUses64BitABI: XCTestCase {
  func testI386() {
    let arch = CDArch(cputype: CPU_TYPE_X86, cpusubtype: CPU_SUBTYPE_386)
    XCTAssertFalse(CDArchUses64BitABI(arch), "i386 does not use 64 bit ABI")
  }

  func testX86_64() {
    let arch = CDArch(cputype: CPU_TYPE_X86_64, cpusubtype: CPU_SUBTYPE_386)
    XCTAssertTrue(CDArchUses64BitABI(arch), "x86_64 uses 64 bit ABI")
  }

  func testX86_64_lib64() {
    let arch = CDArch(
      cputype: CPU_TYPE_X86_64,
      cpusubtype: cpu_subtype_t(CPU_SUBTYPE_386 | CPU_SUBTYPE_LIB64)
    )
    XCTAssertTrue(CDArchUses64BitABI(arch), "x86_64 (with LIB64 capability bit) uses 64 bit ABI")
  }

  func testX86_64PlusOtherCapability() {
    let arch = CDArch(cputype: CPU_TYPE_X86_64 | 0x40000000, cpusubtype: CPU_SUBTYPE_386)
    XCTAssertTrue(CDArchUses64BitABI(arch), "x86_64 (with other capability bit) uses 64 bit ABI")
  }
}
