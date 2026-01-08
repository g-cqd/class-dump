import ClassDumpCore
import XCTest

final class TestCDArchFromName: XCTestCase {
    func testArmv6() {
        let arch = CDArchFromName("armv6")
        XCTAssertEqual(arch.cputype, CPU_TYPE_ARM, "The cputype for 'armv6' should be ARM")
        XCTAssertEqual(arch.cpusubtype, CPU_SUBTYPE_ARM_V6, "The cpusubtype for 'armv6' should be ARM_V6")
    }

    func testArmv7() {
        let arch = CDArchFromName("armv7")
        XCTAssertEqual(arch.cputype, CPU_TYPE_ARM, "The cputype for 'armv7' should be ARM")
        XCTAssertEqual(arch.cpusubtype, CPU_SUBTYPE_ARM_V7, "The cpusubtype for 'armv7' should be ARM_V7")
    }

    func testArmv7s() {
        let arch = CDArchFromName("armv7s")
        XCTAssertEqual(arch.cputype, CPU_TYPE_ARM, "The cputype for 'armv7s' should be ARM")
        XCTAssertEqual(arch.cpusubtype, 11, "The cpusubtype for 'armv7s' should be 11")
    }

    func testArm64() {
        let arch = CDArchFromName("arm64")
        XCTAssertEqual(
            arch.cputype,
            CPU_TYPE_ARM | CPU_ARCH_ABI64,
            "The cputype for 'arm64' should be ARM with 64-bit mask"
        )
        XCTAssertEqual(
            arch.cpusubtype,
            CPU_SUBTYPE_ARM_ALL,
            "The cpusubtype for 'arm64' should be CPU_SUBTYPE_ARM_ALL"
        )
    }

    func testArm64e() {
        let arch = CDArchFromName("arm64e")
        XCTAssertEqual(
            arch.cputype,
            CPU_TYPE_ARM | CPU_ARCH_ABI64,
            "The cputype for 'arm64e' should be ARM with 64-bit mask"
        )
        XCTAssertEqual(
            arch.cpusubtype,
            CPU_SUBTYPE_ARM64E,
            "The cpusubtype for 'arm64e' should be CPU_SUBTYPE_ARM64E"
        )
    }

    func testI386() {
        let arch = CDArchFromName("i386")
        XCTAssertEqual(arch.cputype, CPU_TYPE_X86, "The cputype for 'i386' should be X86")
        XCTAssertEqual(arch.cpusubtype, cpuSubtype386, "The cpusubtype for 'i386' should be 386")
    }

    func testX86_64() {
        let arch = CDArchFromName("x86_64")
        XCTAssertEqual(arch.cputype, CPU_TYPE_X86_64, "The cputype for 'x86_64' should be X86_64")
        XCTAssertEqual(arch.cpusubtype, cpuSubtype386, "The cpusubtype for 'x86_64' should be 386")
    }
}
