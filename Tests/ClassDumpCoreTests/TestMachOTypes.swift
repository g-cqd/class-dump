import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("Arch Tests", .serialized)
struct TestArch {
    @Test("Arch name for known types")
    func testArchNames() {
        #expect(Arch.arm64.name == "arm64")
        #expect(Arch.x86_64.name == "x86_64")
        #expect(Arch.i386.name == "i386")
    }

    @Test("Arch from name")
    func testArchFromName() {
        let arm64 = Arch(name: "arm64")
        #expect(arm64?.cputype == CPU_TYPE_ARM64)

        let x86_64 = Arch(name: "x86_64")
        #expect(x86_64?.cputype == CPU_TYPE_X86_64)

        let invalid = Arch(name: "invalid_arch_name_xyz")
        #expect(invalid == nil)
    }

    @Test("Arch uses 64-bit ABI")
    func testUses64BitABI() {
        #expect(Arch.arm64.uses64BitABI == true)
        #expect(Arch.x86_64.uses64BitABI == true)
        #expect(Arch.i386.uses64BitABI == false)
        #expect(Arch.armv7.uses64BitABI == false)
    }

    @Test("Arch masked CPU type")
    func testMaskedCPUType() {
        let arm64 = Arch.arm64
        // ARM64 has CPU_ARCH_ABI64 bit set, masked version should not
        #expect(arm64.maskedCPUType == CPU_TYPE_ARM)
    }

    @Test("Arch equality")
    func testArchEquality() {
        #expect(Arch.arm64 == Arch(cputype: CPU_TYPE_ARM64, cpusubtype: CPU_SUBTYPE_ARM_ALL))
        #expect(Arch.arm64 != Arch.x86_64)
    }

    @Test("Arch matching ignores subtype mask")
    func testArchMatching() {
        let arch1 = Arch(cputype: CPU_TYPE_ARM64, cpusubtype: CPU_SUBTYPE_ARM_ALL)
        let arch2 = Arch(
            cputype: CPU_TYPE_ARM64, cpusubtype: CPU_SUBTYPE_ARM_ALL | Int32(bitPattern: CPU_SUBTYPE_LIB64))
        #expect(arch1.matches(arch2))
    }
}

@Suite("ByteOrder Tests", .serialized)
struct TestByteOrder {
    @Test("Native byte order is little endian on Apple Silicon/Intel")
    func testNativeByteOrder() {
        // Modern Macs are all little endian
        #expect(ByteOrder.native == .little)
    }
}

@Suite("MachOHeader Tests", .serialized)
struct TestMachOHeader {
    @Test("Parse 64-bit little endian header")
    func testParse64BitLE() throws {
        // Create a minimal 64-bit Mach-O header (little endian)
        var header = mach_header_64()
        header.magic = MH_MAGIC_64
        header.cputype = CPU_TYPE_ARM64
        header.cpusubtype = CPU_SUBTYPE_ARM_ALL
        header.filetype = UInt32(MH_EXECUTE)
        header.ncmds = 10
        header.sizeofcmds = 1000
        header.flags = UInt32(MH_PIE)
        header.reserved = 0

        let data = withUnsafeBytes(of: header) { Data($0) }
        let parsed = try MachOHeader(data: data)

        #expect(parsed.magic == MH_MAGIC_64)
        #expect(parsed.uses64BitABI == true)
        #expect(parsed.cputype == CPU_TYPE_ARM64)
        #expect(parsed.filetype == UInt32(MH_EXECUTE))
        #expect(parsed.ncmds == 10)
        #expect(parsed.filetypeDescription == "EXECUTE")
    }

    @Test("Parse 32-bit header")
    func testParse32Bit() throws {
        var header = mach_header()
        header.magic = MH_MAGIC
        header.cputype = CPU_TYPE_I386
        header.cpusubtype = 3  // CPU_SUBTYPE_I386_ALL
        header.filetype = UInt32(MH_DYLIB)
        header.ncmds = 5
        header.sizeofcmds = 500
        header.flags = 0

        let data = withUnsafeBytes(of: header) { Data($0) }
        let parsed = try MachOHeader(data: data)

        #expect(parsed.magic == MH_MAGIC)
        #expect(parsed.uses64BitABI == false)
        #expect(parsed.cputype == CPU_TYPE_I386)
        #expect(parsed.filetypeDescription == "DYLIB")
    }

    @Test("Invalid magic throws error")
    func testInvalidMagic() {
        let data = Data([0x00, 0x00, 0x00, 0x00])
        #expect(throws: MachOError.self) {
            _ = try MachOHeader(data: data)
        }
    }

    @Test("Data too small throws error")
    func testDataTooSmall() {
        let data = Data([0xFE, 0xED])
        #expect(throws: MachOError.self) {
            _ = try MachOHeader(data: data)
        }
    }

    @Test("Arch property returns correct architecture")
    func testArchProperty() throws {
        var header = mach_header_64()
        header.magic = MH_MAGIC_64
        header.cputype = CPU_TYPE_ARM64
        header.cpusubtype = 2  // arm64e

        let data = withUnsafeBytes(of: header) { Data($0) }
        let parsed = try MachOHeader(data: data)

        #expect(parsed.arch.cputype == CPU_TYPE_ARM64)
        #expect(parsed.arch.cpusubtype == 2)
    }
}

@Suite("FatFile Tests", .serialized)
struct TestFatFile {
    @Test("Parse fat header with two arches")
    func testParseFatFile() throws {
        // Create a minimal fat header with 2 architectures
        var data = Data()

        // Fat header (big endian)
        var magic = FAT_MAGIC.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &magic) { Array($0) })
        var nfat_arch: UInt32 = 2
        nfat_arch = nfat_arch.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &nfat_arch) { Array($0) })

        // First arch: arm64
        func appendFatArch(cputype: cpu_type_t, cpusubtype: cpu_subtype_t, offset: UInt32, size: UInt32, align: UInt32)
        {
            var ct = UInt32(bitPattern: cputype).bigEndian
            var cs = UInt32(bitPattern: cpusubtype).bigEndian
            var off = offset.bigEndian
            var sz = size.bigEndian
            var al = align.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &ct) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &cs) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &off) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &sz) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &al) { Array($0) })
        }

        appendFatArch(cputype: CPU_TYPE_ARM64, cpusubtype: CPU_SUBTYPE_ARM_ALL, offset: 4096, size: 1000, align: 12)
        appendFatArch(cputype: CPU_TYPE_X86_64, cpusubtype: 3, offset: 8192, size: 2000, align: 12)

        let fatFile = try FatFile(data: data)

        #expect(fatFile.arches.count == 2)
        #expect(fatFile.arches[0].arch.cputype == CPU_TYPE_ARM64)
        #expect(fatFile.arches[1].arch.cputype == CPU_TYPE_X86_64)
        #expect(fatFile.archNames == ["arm64", "x86_64"])
    }

    @Test("Best match prefers 64-bit")
    func testBestMatch() throws {
        var data = Data()

        var magic = FAT_MAGIC.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &magic) { Array($0) })
        var nfat_arch: UInt32 = 2
        nfat_arch = nfat_arch.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &nfat_arch) { Array($0) })

        func appendFatArch(cputype: cpu_type_t, cpusubtype: cpu_subtype_t, offset: UInt32, size: UInt32, align: UInt32)
        {
            var ct = UInt32(bitPattern: cputype).bigEndian
            var cs = UInt32(bitPattern: cpusubtype).bigEndian
            var off = offset.bigEndian
            var sz = size.bigEndian
            var al = align.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &ct) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &cs) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &off) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &sz) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &al) { Array($0) })
        }

        // Put 32-bit first, 64-bit second
        appendFatArch(cputype: CPU_TYPE_I386, cpusubtype: 3, offset: 4096, size: 1000, align: 12)
        appendFatArch(cputype: CPU_TYPE_X86_64, cpusubtype: 3, offset: 8192, size: 2000, align: 12)

        let fatFile = try FatFile(data: data)

        // Best match for x86 should prefer 64-bit
        let best = fatFile.bestMatch(for: .x86_64)
        #expect(best?.uses64BitABI == true)
        #expect(best?.arch.cputype == CPU_TYPE_X86_64)
    }

    @Test("Contains architecture")
    func testContainsArch() throws {
        var data = Data()

        var magic = FAT_MAGIC.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &magic) { Array($0) })
        var nfat_arch: UInt32 = 1
        nfat_arch = nfat_arch.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &nfat_arch) { Array($0) })

        var ct = UInt32(bitPattern: CPU_TYPE_ARM64).bigEndian
        var cs = UInt32(bitPattern: CPU_SUBTYPE_ARM_ALL).bigEndian
        var off: UInt32 = 4096
        off = off.bigEndian
        var sz: UInt32 = 1000
        sz = sz.bigEndian
        var al: UInt32 = 12
        al = al.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &ct) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &cs) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &off) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &sz) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &al) { Array($0) })

        let fatFile = try FatFile(data: data)

        #expect(fatFile.contains(.arm64) == true)
        #expect(fatFile.contains(.x86_64) == false)
    }

    @Test("Invalid fat magic throws error")
    func testInvalidFatMagic() {
        let data = Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        #expect(throws: MachOError.self) {
            _ = try FatFile(data: data)
        }
    }
}

@Suite("MachOFile Tests", .serialized)
struct TestMachOFile {
    @Test("Parse MachOFile from header data")
    func testParseMachOFile() throws {
        var header = mach_header_64()
        header.magic = MH_MAGIC_64
        header.cputype = CPU_TYPE_ARM64
        header.cpusubtype = CPU_SUBTYPE_ARM_ALL
        header.filetype = UInt32(MH_EXECUTE)
        header.ncmds = 0
        header.sizeofcmds = 0
        header.flags = UInt32(MH_PIE)

        let data = withUnsafeBytes(of: header) { Data($0) }
        let file = try MachOFile(data: data, filename: "/test/binary")

        #expect(file.uses64BitABI == true)
        #expect(file.ptrSize == 8)
        #expect(file.archName == "arm64")
        #expect(file.filename == "/test/binary")
    }
}

@Suite("MachOBinary Tests", .serialized)
struct TestMachOBinary {
    @Test("Detect thin binary")
    func testDetectThin() throws {
        var header = mach_header_64()
        header.magic = MH_MAGIC_64
        header.cputype = CPU_TYPE_ARM64
        header.cpusubtype = CPU_SUBTYPE_ARM_ALL

        let data = withUnsafeBytes(of: header) { Data($0) }
        let binary = try MachOBinary(data: data)

        #expect(binary.isFat == false)
        #expect(binary.architectures.count == 1)
        #expect(binary.archNames == ["arm64"])
    }

    @Test("Detect fat binary")
    func testDetectFat() throws {
        var data = Data()

        var magic = FAT_MAGIC.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &magic) { Array($0) })
        var nfat_arch: UInt32 = 1
        nfat_arch = nfat_arch.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &nfat_arch) { Array($0) })

        var ct = UInt32(bitPattern: CPU_TYPE_ARM64).bigEndian
        var cs = UInt32(bitPattern: CPU_SUBTYPE_ARM_ALL).bigEndian
        var off: UInt32 = 4096
        off = off.bigEndian
        var sz: UInt32 = 1000
        sz = sz.bigEndian
        var al: UInt32 = 12
        al = al.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &ct) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &cs) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &off) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &sz) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &al) { Array($0) })

        let binary = try MachOBinary(data: data)

        #expect(binary.isFat == true)
        #expect(binary.architectures.count == 1)
    }
}
