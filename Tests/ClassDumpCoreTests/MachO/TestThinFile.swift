// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import MachO
import Testing

@testable import ClassDumpCore

// MARK: - Thin File Intel 64 Tests

@Suite("Thin File Intel 64 Tests")
struct ThinFileIntel64Tests {
    let binary: MachOBinary

    init() throws {
        let data = mockMachOData(cputype: CPU_TYPE_X86_64, cpusubtype: 3, is64Bit: true)
        binary = try MachOBinary(data: data)
    }

    @Test("best match Intel 64")
    func bestMatchIntel64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let result = try binary.bestMatch(for: arch)
        #expect(result.arch.cputype == CPU_TYPE_X86_64)
        #expect(result.arch.cpusubtype == 3)
    }

    @Test("machOFile with arch x86_64")
    func machOFileWithArchX86_64() throws {
        let arch = Arch(cputype: CPU_TYPE_X86_64, cpusubtype: 3)
        let machOFile = try binary.machOFile(for: arch)
        #expect(machOFile.arch.cputype == CPU_TYPE_X86_64)
    }

    @Test("machOFile with arch i386 throws architectureNotFound")
    func machOFileWithArchI386() {
        let arch = Arch(cputype: CPU_TYPE_X86, cpusubtype: 3)
        #expect(throws: MachOError.architectureNotFound(arch)) {
            try binary.machOFile(for: arch)
        }
    }
}

// MARK: - Thin File Intel 64 with LIB64 Tests

@Suite("Thin File Intel 64 with LIB64 Tests")
struct ThinFileIntel64Lib64Tests {
    let binary: MachOBinary
    let lib64 = Int32(bitPattern: 0x8000_0000)

    init() throws {
        let data = mockMachOData(cputype: CPU_TYPE_X86_64, cpusubtype: 3 | lib64, is64Bit: true)
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
    }

    @Test("machOFile with arch i386 throws architectureNotFound")
    func machOFileWithArchI386() {
        let arch = Arch(cputype: CPU_TYPE_X86, cpusubtype: 3)
        #expect(throws: MachOError.architectureNotFound(arch)) {
            try binary.machOFile(for: arch)
        }
    }
}
