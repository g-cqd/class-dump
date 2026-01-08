import Testing
@testable import ClassDumpCore
import MachO

@Suite struct TestArchFromName {
    @Test func armv6() {
        let arch = Arch(name: "armv6")
        #expect(arch != nil)
        #expect(arch?.cputype == CPU_TYPE_ARM)
        #expect(arch?.cpusubtype == CPU_SUBTYPE_ARM_V6)
    }

    @Test func armv7() {
        let arch = Arch(name: "armv7")
        #expect(arch != nil)
        #expect(arch?.cputype == CPU_TYPE_ARM)
        #expect(arch?.cpusubtype == CPU_SUBTYPE_ARM_V7)
    }

    @Test func armv7s() {
        let arch = Arch(name: "armv7s")
        #expect(arch != nil)
        #expect(arch?.cputype == CPU_TYPE_ARM)
        #expect(arch?.cpusubtype == 11)
    }

    @Test func arm64() {
        let arch = Arch(name: "arm64")
        #expect(arch != nil)
        #expect(arch?.cputype == CPU_TYPE_ARM | CPU_ARCH_ABI64)
        #expect(arch?.cpusubtype == CPU_SUBTYPE_ARM_ALL)
    }

    @Test func arm64e() {
        let arch = Arch(name: "arm64e")
        #expect(arch != nil)
        #expect(arch?.cputype == CPU_TYPE_ARM | CPU_ARCH_ABI64)
        #expect(arch?.cpusubtype == 2) // CPU_SUBTYPE_ARM64E
    }

    @Test func i386() {
        let arch = Arch(name: "i386")
        #expect(arch != nil)
        #expect(arch?.cputype == CPU_TYPE_X86)
        #expect(arch?.cpusubtype == 3) // CPU_SUBTYPE_I386_ALL
    }

    @Test func x86_64() {
        let arch = Arch(name: "x86_64")
        #expect(arch != nil)
        #expect(arch?.cputype == CPU_TYPE_X86_64)
        #expect(arch?.cpusubtype == 3) // CPU_SUBTYPE_X86_64_ALL
    }
}