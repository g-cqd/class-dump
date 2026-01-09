// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

// MARK: - Fat File ARM v7/v7s Tests

@Suite("Fat File ARM v7/v7s Tests")
struct FatFileARMv7v7sTests {
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
            (cputype: CPU_TYPE_ARM, cpusubtype: cpu_subtype_t(11), offset: offsetV7s, size: sizeV7s, align: alignV7s),
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

    @Test("machOFile with arch armv7")
    func machOFileWithArchArmv7() throws {
        let arch = Arch(cputype: CPU_TYPE_ARM, cpusubtype: CPU_SUBTYPE_ARM_V7)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cpusubtype == CPU_SUBTYPE_ARM_V7)
    }

    @Test("machOFile with arch armv7s")
    func machOFileWithArchArmv7s() throws {
        let arch = Arch(cputype: CPU_TYPE_ARM, cpusubtype: 11)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cpusubtype == 11)
    }
}

// MARK: - Fat File Intel 32/64 Tests

@Suite("Fat File Intel 32/64 Tests")
struct FatFileIntel32_64Tests {
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

    @Test("best match Intel 64")
    func bestMatchIntel64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let result = try binary.bestMatch(for: arch)
        #expect(result.arch.cputype == CPU_TYPE_X86_64)
    }

    @Test("machOFile with arch x86_64")
    func machOFileWithArchX86_64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86_64)
    }

    @Test("machOFile with arch i386")
    func machOFileWithArchI386() throws {
        let arch = Arch(cputype: CPU_TYPE_X86, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86)
    }
}

// MARK: - Fat File Intel 32/64 with LIB64 Tests

@Suite("Fat File Intel 32/64 with LIB64 Tests")
struct FatFileIntel32_64Lib64Tests {
    let binary: MachOBinary
    let lib64 = Int32(bitPattern: 0x8000_0000)

    init() throws {
        let offset32: UInt32 = 0x1000
        let size32: UInt32 = 0x100
        let align32: UInt32 = 12

        let offset64: UInt32 = 0x2000
        let size64: UInt32 = 0x100
        let align64: UInt32 = 12

        let arches = [
            (cputype: CPU_TYPE_X86, cpusubtype: cpu_subtype_t(3), offset: offset32, size: size32, align: align32),
            (
                cputype: CPU_TYPE_X86_64, cpusubtype: cpu_subtype_t(3) | lib64, offset: offset64, size: size64,
                align: align64
            ),
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
        data.append(mockMachOData(cputype: CPU_TYPE_X86_64, cpusubtype: 3 | lib64, is64Bit: true))
        if data.count < offset64 + size64 {
            data.append(Data(repeating: 0, count: Int(offset64 + size64) - data.count))
        }

        binary = try MachOBinary(data: data)
    }

    @Test("best match Intel 64 with LIB64")
    func bestMatchIntel64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let result = try binary.bestMatch(for: arch)
        #expect(result.arch.cputype == CPU_TYPE_X86_64)
        #expect(result.arch.cpusubtype == 3 | lib64)
    }

    @Test("machOFile with arch x86_64 LIB64")
    func machOFileWithArchX86_64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86_64)
        #expect(machOFile.arch.cpusubtype == 3 | lib64)
    }

    @Test("machOFile with arch i386")
    func machOFileWithArchI386() throws {
        let arch = Arch(cputype: CPU_TYPE_X86, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86)
    }
}

// MARK: - Fat File Intel 64/32 (Reverse Order) Tests

@Suite("Fat File Intel 64/32 (Reverse Order) Tests")
struct FatFileIntel64_32Tests {
    let binary: MachOBinary

    init() throws {
        let offset64: UInt32 = 0x1000
        let size64: UInt32 = 0x100
        let align64: UInt32 = 12

        let offset32: UInt32 = 0x2000
        let size32: UInt32 = 0x100
        let align32: UInt32 = 12

        let arches = [
            (cputype: CPU_TYPE_X86_64, cpusubtype: cpu_subtype_t(3), offset: offset64, size: size64, align: align64),
            (cputype: CPU_TYPE_X86, cpusubtype: cpu_subtype_t(3), offset: offset32, size: size32, align: align32),
        ]

        var data = mockFatData(arches: arches)

        if data.count < offset64 {
            data.append(Data(repeating: 0, count: Int(offset64) - data.count))
        }
        data.append(mockMachOData(cputype: CPU_TYPE_X86_64, cpusubtype: 3, is64Bit: true))
        if data.count < offset64 + size64 {
            data.append(Data(repeating: 0, count: Int(offset64 + size64) - data.count))
        }

        if data.count < offset32 {
            data.append(Data(repeating: 0, count: Int(offset32) - data.count))
        }
        data.append(mockMachOData(cputype: CPU_TYPE_X86, cpusubtype: 3, is64Bit: false))
        if data.count < offset32 + size32 {
            data.append(Data(repeating: 0, count: Int(offset32 + size32) - data.count))
        }

        binary = try MachOBinary(data: data)
    }

    @Test("best match Intel 64 reverse order")
    func bestMatchIntel64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let result = try binary.bestMatch(for: arch)
        #expect(result.arch.cputype == CPU_TYPE_X86_64)
    }

    @Test("machOFile with arch x86_64 reverse order")
    func machOFileWithArchX86_64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86_64)
    }

    @Test("machOFile with arch i386 reverse order")
    func machOFileWithArchI386() throws {
        let arch = Arch(cputype: CPU_TYPE_X86, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86)
    }
}
