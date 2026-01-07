import XCTest

final class TestCDNameForCPUType: XCTestCase {
  func testArmv6() {
    XCTAssertEqual(
      CDNameForCPUType(CPU_TYPE_ARM, CPU_SUBTYPE_ARM_V6),
      "armv6",
      "The name for ARM subtype CPU_SUBTYPE_ARM_V6 should be 'armv6'"
    )
  }

  func testArmv7() {
    XCTAssertEqual(
      CDNameForCPUType(CPU_TYPE_ARM, CPU_SUBTYPE_ARM_V7),
      "armv7",
      "The name for ARM subtype CPU_SUBTYPE_ARM_V7 should be 'armv7'"
    )
  }

  func testArmv7s() {
    XCTAssertEqual(
      CDNameForCPUType(CPU_TYPE_ARM, 11),
      "armv7s",
      "The name for ARM subtype 11 should be 'armv7s'"
    )
  }

  func testArm64() {
    XCTAssertEqual(
      CDNameForCPUType(CPU_TYPE_ARM | CPU_ARCH_ABI64, CPU_SUBTYPE_ARM_ALL),
      "arm64",
      "The name for ARM 64-bit subtype CPU_SUBTYPE_ARM_ALL should be 'arm64'"
    )
  }

  func testI386() {
    XCTAssertEqual(
      CDNameForCPUType(CPU_TYPE_X86, CPU_SUBTYPE_386),
      "i386",
      "The name for X86 subtype CPU_SUBTYPE_386 should be 'i386'"
    )
  }

  func testX86_64() {
    XCTAssertEqual(
      CDNameForCPUType(CPU_TYPE_X86_64, CPU_SUBTYPE_386),
      "x86_64",
      "The name for X86_64 subtype CPU_SUBTYPE_386 should be 'x86_64'"
    )
  }

  func testX86_64_lib64() {
    XCTAssertEqual(
      CDNameForCPUType(CPU_TYPE_X86_64, CPU_SUBTYPE_386 | CPU_SUBTYPE_LIB64),
      "x86_64",
      "The name for X86_64 subtype CPU_SUBTYPE_386 with capability bits should be 'x86_64'"
    )
  }
}
