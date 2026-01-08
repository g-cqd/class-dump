import Testing
@testable import ClassDumpCore
import MachO
import Foundation

@Suite struct TestFatFile_armv7_v7s {
    let binary: MachOBinary
    
    init() throws {
        let offsetV7: UInt32 = 0x1000
        let sizeV7: UInt32 = 0x100
        let alignV7: UInt32 = 12
        
        let offsetV7s: UInt32 = 0x2000
        let sizeV7s: UInt32 = 0x100
        let alignV7s: UInt32 = 12
        
        let arches = [
            (cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V7, offset: offsetV7, size: sizeV7, align: alignV7),
            (cputype: CPU_TYPE_ARM, cpusubtype: cpu_subtype_t(11), offset: offsetV7s, size: sizeV7s, align: alignV7s)
        ]
        
        var data = mockFatData(arches: arches)
        
        // V7
        if data.count < offsetV7 {
            data.append(Data(repeating: 0, count: Int(offsetV7) - data.count))
        }
        data.append(mockMachOData(cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V7, is64Bit: false))
        if data.count < offsetV7 + sizeV7 {
            data.append(Data(repeating: 0, count: Int(offsetV7 + sizeV7) - data.count))
        }
        
        // V7s
        if data.count < offsetV7s {
            data.append(Data(repeating: 0, count: Int(offsetV7s) - data.count))
        }
        data.append(mockMachOData(cputype: CPU_TYPE_ARM, cpusubtype: 11, is64Bit: false))
        if data.count < offsetV7s + sizeV7s {
            data.append(Data(repeating: 0, count: Int(offsetV7s + sizeV7s) - data.count))
        }
        
        binary = try MachOBinary(data: data)
    }

    @Test func machOFileWithArch_armv7() throws {
        let arch = Arch(cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V7)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cpusubtype == CPU_SUBTYPE_ARM_V7)
    }

    @Test func machOFileWithArch_armv7s() throws {
        let arch = Arch(cputype: CPU_TYPE_ARM, cpusubtype: 11)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cpusubtype == 11)
    }
}
