import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite struct TestFatFile_Intel32_64 {
    let binary: MachOBinary

    init() throws {
        let offset32: UInt32 = 0x1000
        let size32: UInt32 = 0x100
        let align32: UInt32 = 12

        let offset64: UInt32 = 0x2000
        let size64: UInt32 = 0x100
        let align64: UInt32 = 12

        let arches = [
            (cputype: CPU_TYPE_X86, cpusubtype: cpu_subtype_t(3), offset: offset32, size: size32, align: align32),
            (cputype: CPU_TYPE_X86_64, cpusubtype: cpu_subtype_t(3), offset: offset64, size: size64, align: align64),
        ]

        var data = mockFatData(arches: arches)

        if data.count < offset32 {
            data.append(Data(repeating: 0, count: Int(offset32) - data.count))
        }
        data.append(mockMachOData(cputype: CPU_TYPE_X86, cpusubtype: 3, is64Bit: false))
        if data.count < offset32 + size32 {
            data.append(Data(repeating: 0, count: Int(offset32 + size32) - data.count))
        }

        if data.count < offset64 {
            data.append(Data(repeating: 0, count: Int(offset64) - data.count))
        }
        data.append(mockMachOData(cputype: CPU_TYPE_X86_64, cpusubtype: 3, is64Bit: true))
        if data.count < offset64 + size64 {
            data.append(Data(repeating: 0, count: Int(offset64 + size64) - data.count))
        }

        binary = try MachOBinary(data: data)
    }

    @Test func bestMatchIntel64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let result = try binary.bestMatch(for: arch)
        #expect(result.arch.cputype == CPU_TYPE_X86_64)
    }

    @Test func machOFileWithArch_x86_64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86_64)
    }

    @Test func machOFileWithArch_i386() throws {
        let arch = Arch(cputype: CPU_TYPE_X86, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86)
    }
}
