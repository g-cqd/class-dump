import Testing
@testable import ClassDumpCore
import MachO

@Suite struct TestThinFile_Intel64_lib64 {
    let binary: MachOBinary
    let lib64 = Int32(bitPattern: 0x80000000)

    init() throws {
        let data = mockMachOData(cputype: CPU_TYPE_X86_64, cpusubtype: 3 | lib64, is64Bit: true)
        binary = try MachOBinary(data: data)
    }

    @Test func bestMatchIntel64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let result = try binary.bestMatch(for: arch)
        #expect(result.arch.cputype == CPU_TYPE_X86_64)
        #expect(result.arch.cpusubtype == 3 | lib64)
    }

    @Test func machOFileWithArch_x86_64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86_64)
    }

    @Test func machOFileWithArch_i386() {
        let arch = Arch(cputype: CPU_TYPE_X86, cpusubtype: 3)
        #expect(throws: MachOError.architectureNotFound(arch)) {
            try binary.machOFile(for: arch)
        }
    }
}