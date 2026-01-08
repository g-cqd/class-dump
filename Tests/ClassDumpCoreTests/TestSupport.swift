import ClassDumpCore
import Foundation
import MachO

// CPU_SUBTYPE_386 is not imported into Swift in recent SDKs.
let cpuSubtype386: cpu_subtype_t = 3
let cpuSubtypeLib64: cpu_subtype_t = cpu_subtype_t(bitPattern: 0x80000000)

func mockMachOData(
    cputype: cpu_type_t,
    cpusubtype: cpu_subtype_t,
    filetype: UInt32 = UInt32(MH_EXECUTE),
    is64Bit: Bool = false
) -> Data {
    var data = Data()
    var magic = is64Bit ? MH_MAGIC_64 : MH_MAGIC
    
    // Use host endianness for Mach-O headers by default
    var cputypeVal = cputype
    var cpusubtypeVal = cpusubtype
    var filetypeVal = filetype
    var ncmdsVal: UInt32 = 0
    var sizeofcmdsVal: UInt32 = 0
    var flagsVal: UInt32 = 0
    var reservedVal: UInt32 = 0
    
    withUnsafeBytes(of: &magic) { data.append(contentsOf: $0) }
    withUnsafeBytes(of: &cputypeVal) { data.append(contentsOf: $0) }
    withUnsafeBytes(of: &cpusubtypeVal) { data.append(contentsOf: $0) }
    withUnsafeBytes(of: &filetypeVal) { data.append(contentsOf: $0) }
    withUnsafeBytes(of: &ncmdsVal) { data.append(contentsOf: $0) }
    withUnsafeBytes(of: &sizeofcmdsVal) { data.append(contentsOf: $0) }
    withUnsafeBytes(of: &flagsVal) { data.append(contentsOf: $0) }
    
    if is64Bit {
        withUnsafeBytes(of: &reservedVal) { data.append(contentsOf: $0) }
    }
    
    return data
}

func mockFatData(arches: [(cputype: cpu_type_t, cpusubtype: cpu_subtype_t, offset: UInt32, size: UInt32, align: UInt32)]) -> Data {
    var data = Data()
    var magic = FAT_MAGIC.bigEndian // Write as Big Endian
    var nfat = UInt32(arches.count).bigEndian
    
    withUnsafeBytes(of: &magic) { data.append(contentsOf: $0) }
    withUnsafeBytes(of: &nfat) { data.append(contentsOf: $0) }
    
    for arch in arches {
        var cpu = arch.cputype.bigEndian
        var sub = arch.cpusubtype.bigEndian
        var off = arch.offset.bigEndian
        var sz = arch.size.bigEndian
        var al = arch.align.bigEndian
        
        withUnsafeBytes(of: &cpu) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &sub) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &off) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &sz) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &al) { data.append(contentsOf: $0) }
    }
    
    return data
}