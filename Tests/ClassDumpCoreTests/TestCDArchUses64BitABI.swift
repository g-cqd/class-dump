import Testing
@testable import ClassDumpCore
import MachO

@Suite struct TestArchUses64BitABI {
    @Test func i386() {
        let arch = Arch(cputype: CPU_TYPE_X86, cpusubtype: 3)
        #expect(!arch.uses64BitABI, "i386 does not use 64 bit ABI")
    }

    @Test func x86_64() {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        #expect(arch.uses64BitABI, "x86_64 uses 64 bit ABI")
    }

    @Test func x86_64_lib64() {
        let lib64 = cpu_subtype_t(bitPattern: 0x80000000)
        let arch = Arch(
            cputype: CPU_TYPE_X86_64,
            cpusubtype: 3 | lib64
        )
        #expect(arch.uses64BitABI, "x86_64 (with LIB64 capability bit) uses 64 bit ABI")
    }

    @Test func x86_64PlusOtherCapability() {
        let arch = Arch(cputype: CPU_TYPE_X86_64 | 0x4000_0000, cpusubtype: 3)
        #expect(arch.uses64BitABI, "x86_64 (with other capability bit) uses 64 bit ABI")
    }
}
