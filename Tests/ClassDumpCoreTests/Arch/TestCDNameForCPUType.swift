import MachO
import Testing

@testable import ClassDumpCore

@Suite struct TestNameForCPUType {
    @Test func armv6() {
        let arch = Arch(cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V6)
        #expect(arch.name == "armv6")
    }

    @Test func armv7() {
        let arch = Arch(cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V7)
        #expect(arch.name == "armv7")
    }

    @Test func armv7s() {
        let arch = Arch(cputype: CPU_TYPE_ARM, cpusubtype: 11)
        #expect(arch.name == "armv7s")
    }

    @Test func arm64() {
        let arch = Arch(cputype: CPU_TYPE_ARM | CPU_ARCH_ABI64, cpusubtype: CPU_SUBTYPE_ARM_ALL)
        #expect(arch.name == "arm64")
    }

    @Test func arm64e() {
        let arch = Arch(cputype: CPU_TYPE_ARM | CPU_ARCH_ABI64, cpusubtype: 2)  // CPU_SUBTYPE_ARM64E
        #expect(arch.name == "arm64e")
    }

    @Test func i386() {
        let arch = Arch(cputype: CPU_TYPE_X86, cpusubtype: 3)  // CPU_SUBTYPE_I386_ALL
        #expect(arch.name == "i386")
    }

    @Test func x86_64() {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        #expect(arch.name == "x86_64")
    }

    @Test func x86_64_lib64() {
        let lib64 = Int32(bitPattern: 0x8000_0000)
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3 | lib64)
        #expect(arch.name == "x86_64")
    }
}
