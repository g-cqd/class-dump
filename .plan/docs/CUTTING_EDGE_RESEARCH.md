# Cutting-Edge Mach-O & Swift Binary Research (2024-2025)

This document compiles the latest, most advanced knowledge from reverse engineering communities, Apple's evolving formats, and specialized tooling for Mach-O parsing and Swift binary analysis.

---

## 1. ARM64E & Pointer Authentication (PAC)

### What's New
ARM64E binaries on Apple Silicon (M1+, A12+) embed **Pointer Authentication Codes (PAC)** in the high-order bits of pointers. This is a hardware-backed security feature.

### Impact on Parsing
```
Raw pointer:     0x8001_0000_0001_2345
Actual address:  0x0000_0000_0001_2345  (after stripping PAC)
```

**Critical for class-dump:** When reading pointers in ObjC metadata (class pointers, method IMPs, etc.), we must strip PAC bits:
```swift
func stripPAC(_ pointer: UInt64) -> UInt64 {
    // Strip high 16 bits for ARM64E PAC
    return pointer & 0x0000_FFFF_FFFF_FFFF
}
```

### References
- Apple Developer: "Preparing your app to work with pointer authentication"
- `go-macho` handles this in `pkg/fixupchains`

---

## 2. Chained Fixups (iOS 14+ / macOS 12+)

### The New Format
`LC_DYLD_CHAINED_FIXUPS` replaces `LC_DYLD_INFO(_ONLY)` for modern binaries:
- **Binds**: External symbol references (superclass, protocol references)
- **Rebases**: Internal pointer fixups

### Pointer Format Types
| Type | Description |
|------|-------------|
| `DYLD_CHAINED_PTR_64` | Standard 64-bit chained pointer |
| `DYLD_CHAINED_PTR_ARM64E` | With PAC support |
| `DYLD_CHAINED_PTR_ARM64E_USERLAND` | User-space ARM64E |
| `DYLD_CHAINED_PTR_ARM64E_KERNEL` | Kernel extensions |

### Parsing Strategy
```swift
struct ChainedFixupPointer {
    let raw: UInt64
    
    var isBind: Bool { (raw >> 63) == 1 }
    var ordinal: UInt32 { UInt32(raw & 0xFFFFFF) }  // For binds
    var target: UInt64 { raw & 0x7FFFFFFFFFF }     // For rebases
}
```

### Impact on class-dump
External superclass references (e.g., `NSObject`) are now encoded as **bind ordinals**, not direct pointers. We must:
1. Parse `LC_DYLD_CHAINED_FIXUPS`
2. Build ordinal → symbol name table
3. Resolve ordinals when processing ObjC class metadata

---

## 3. Relative Method Lists ("Small Methods")

### iOS 14+ Optimization
ObjC method lists now use **32-bit relative offsets** instead of absolute pointers:
```c
// Old format (pre-iOS 14)
struct method_t {
    SEL name;        // 8 bytes absolute pointer
    const char *types;
    IMP imp;
};

// New format (iOS 14+)
struct small_method_t {
    int32_t name;    // Relative offset to selector
    int32_t types;   // Relative offset to type string
    int32_t imp;     // Relative offset to implementation
};
```

### Detection
Check the `method_list_t` flags for `0x80000000` (uses relative offsets).

### Benefits
- 50% smaller method lists
- Position-independent code
- Better ASLR security

### Our Current Status
✅ class-dump already handles small methods in `ObjC2Processor.swift`

---

## 4. Export Trie Format (LC_DYLD_EXPORTS_TRIE)

### Modern Symbol Export Format
Replaces the export info in `LC_DYLD_INFO`. Uses a compressed trie with ULEB128 encoding:

```
Root
├── "_" (prefix)
│   ├── "NSLog" → export info (flags, address)
│   ├── "NSObject" → export info
│   └── "objc_" (prefix)
│       ├── "msgSend" → export info
│       └── "alloc" → export info
```

### Parsing Algorithm
1. Start at offset from `LC_DYLD_EXPORTS_TRIE`
2. Read node: terminal size (ULEB128), then export info if non-zero
3. Read child count, then edges (string + node offset)
4. Recursively traverse, accumulating symbol name

### Use Case for class-dump
- Symbol demangling for `-A` output
- Detecting exported vs private symbols

---

## 5. Swift Metadata Sections (Deep Dive)

### Key Sections in `__TEXT`
| Section | Contents |
|---------|----------|
| `__swift5_types` | Type context descriptors (classes, structs, enums) |
| `__swift5_protos` | Protocol descriptors |
| `__swift5_proto` | Protocol conformance records |
| `__swift5_fieldmd` | Field/property metadata |
| `__swift5_typeref` | Type references (mangled names) |
| `__swift5_reflstr` | Reflection strings |
| `__swift5_assocty` | Associated type metadata |
| `__swift5_builtin` | Built-in type metadata |

### Type Descriptor Structure
```swift
struct TypeContextDescriptor {
    var flags: UInt32                    // Kind, isGeneric, etc.
    var parent: RelativePointer<Void>    // Enclosing context
    var name: RelativePointer<CChar>     // Type name (mangled)
    var accessFunction: RelativePointer<Void>
    var fields: RelativePointer<FieldDescriptor>
    // Additional fields for classes:
    var superclass: RelativePointer<CChar>  // Superclass mangled name
    var metadataNegativeSize: UInt32
    var metadataPositiveSize: UInt32
    var numImmediateMembers: UInt32
    var numFields: UInt32
}
```

### Relative Pointers
Swift uses **32-bit signed relative offsets** everywhere:
```swift
struct RelativePointer<T> {
    let offset: Int32
    
    func resolve(from base: UInt64) -> UInt64 {
        return UInt64(Int64(base) + Int64(offset))
    }
}
```

### Swift 6 Changes
- **Typed throws**: Function descriptors now encode error types
- **Noncopyable types**: New flag in type descriptors, witness tables omit copy operations
- **Concurrency metadata**: Actor isolation encoded in function signatures

---

## 6. dyld_shared_cache (iOS 18 / macOS 15)

### Multi-File "Sub-Cache" Format
Since dyld 940 (iOS 16+), the cache is split:
```
dyld_shared_cache_arm64e
dyld_shared_cache_arm64e.01
dyld_shared_cache_arm64e.02
dyld_shared_cache_arm64e.symbols
dyld_shared_cache_arm64e.map
```

### Cryptex Locations (iOS 18)
```
/private/preboot/Cryptexes/OS/System/Library/Caches/com.apple.dyld/
/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/
```

### Header Structure (Simplified)
```c
struct dyld_cache_header {
    char        magic[16];           // "dyld_v1  arm64e\0"
    uint32_t    mappingOffset;
    uint32_t    mappingCount;
    uint32_t    imagesOffsetOld;
    uint32_t    imagesCountOld;
    uint64_t    dyldBaseAddress;
    // ... 100+ more fields
    uint32_t    subCacheArrayOffset;
    uint32_t    subCacheArrayCount;
};
```

### ObjC Optimization Tables
The DSC contains pre-built hash tables for O(1) lookup:
- **Selector table**: Global selector → address mapping
- **Class table**: Class name → class address mapping
- **Protocol table**: Protocol name → protocol address mapping

Located at offsets specified in `dyld_cache_header.objcOptsOffset`.

---

## 7. MH_FILESET (Kernelcache)

### What Is It?
`MH_FILESET` (type 0xC) is a container for multiple Mach-O binaries:
- iOS kernelcache contains XNU + all kexts
- Each "fileset entry" is a complete Mach-O

### Parsing
1. Read main Mach-O header (magic, filetype = MH_FILESET)
2. Find `LC_FILESET_ENTRY` load commands
3. Each entry has: name, VM address, file offset
4. Parse embedded Mach-O at each entry's offset

### Relevance to class-dump
Future support for analyzing kernel extensions could use this format.

---

## 8. Embedded Swift Runtime

### Minimal Metadata Mode
Embedded Swift (`$e` symbol prefix) strips most reflection metadata:
- No `Mirror` support
- Minimal type descriptors (only for polymorphism)
- Smaller witness tables

### Impact
Binaries compiled with Embedded Swift have very limited introspection. class-dump would extract minimal information from these.

---

## 9. Swift-Native Mach-O Libraries (Pure Swift Reference)

### Discovered Tools

| Tool | Language | Stars | Description |
|------|----------|-------|-------------|
| **MachOSwiftSection** | Swift | 254 | Parse Swift metadata from Mach-O |
| **MachOKit (p-x9)** | Swift | 211 | Full Mach-O + dyld cache parser |
| **MachOObjCSection** | Swift | 28 | ObjC metadata extraction |
| **swift-dwarf** | Swift | 15 | DWARF debug info parsing |
| **classdump-dyld** | Logos | 611 | In-process class-dump from DSC |
| **dyld-shared-cache-extractor** | C | 555 | CLI for DSC extraction |
| **DyldExtractor** | Python | 462 | DSC binary extraction |

### MachOKit (p-x9) - Most Relevant
https://github.com/p-x9/MachOKit

This Swift library provides:
- Full Mach-O parsing (headers, load commands, segments)
- dyld shared cache support
- Symbol table extraction
- Swift metadata parsing via companion libraries
- Chained fixup support

**Potential for integration or reference implementation.**

---

## 10. ObjC Runtime Optimization Details

### Selector Uniquing in DSC
The shared cache uses a perfect hash table for selectors:
```
selector_name → {image_index, offset}
```
This enables O(1) `sel_getUid()` lookups at runtime.

### IMP Cache Structure
Per-class method cache using buckets:
```c
struct cache_t {
    uintptr_t _bucketsAndMaybeMask;  // Buckets pointer + inline mask
    // ... preoptimized cache pointer for DSC
};
```

### Small Method Selector References
In DSC, selectors may be indices into the global selector table rather than direct strings:
```swift
// Check if using shared cache selector
if methodEntry.selectorOffset & 0x1 != 0 {
    // Indirect: look up in global selector table
    let index = methodEntry.selectorOffset >> 1
    return globalSelectorTable[index]
}
```

---

## 11. Implementation Priorities for class-dump

Based on this research, prioritized additions:

### Immediate (High Impact, Lower Effort)
1. **LC_DYLD_CHAINED_FIXUPS parsing** - Required for iOS 14+ superclass resolution
2. **PAC stripping** - Required for ARM64E binaries
3. **Swift detection** - `hasSwift` property checking for `__swift5_*` sections

### Medium-Term (High Impact, Higher Effort)
4. **Swift type descriptor parsing** - Basic struct/class/enum extraction
5. **Symbol demangling** - Call `swift-demangle` or port algorithm
6. **dyld_shared_cache header parsing** - Memory-mapped reading

### Long-Term (Major Features)
7. **Full DSC image extraction** - In-cache Mach-O access
8. **Swift protocol conformance** - Type → Protocol mappings
9. **DSC ObjC optimization tables** - Fast class/selector lookup

---

## 12. Key References & Resources

### Apple Documentation
- dyld source: https://github.com/apple-oss-distributions/dyld
- objc4 source: https://github.com/apple-oss-distributions/objc4
- Swift ABI: https://github.com/swiftlang/swift/tree/main/docs/ABI

### Technical Deep Dives
- Scott Knight: "Swift Metadata" (knight.sc)
- Synacktiv: "Demystifying Objective-C Internals" (PDF)
- NowSecure: "Reversing iOS System Libraries Using Radare2"
- OBTS v8: "Using Type Metadata from Swift Binaries"

### Tools & Libraries
- go-macho: https://github.com/blacktop/go-macho
- ipsw: https://github.com/blacktop/ipsw
- MachOKit (Swift): https://github.com/p-x9/MachOKit
- MachOSwiftSection: https://github.com/MxIris-Reverse-Engineering/MachOSwiftSection
- LIEF: https://lief.re

### GitHub Issues/Discussions
- MachO-Kit: "Handle Small ObjC Method Lists" (#21)
- mold linker: "Add support for objc_msgSend stubs" (#758)
- Swift Forums: Noncopyable types ABI discussion

---

## 13. Recommended Next Steps for class-dump

### Phase 1: Modern Binary Compatibility
```swift
// Add to MachOFile.swift
var hasChainedFixups: Bool {
    loadCommands.contains { $0.cmd == LC_DYLD_CHAINED_FIXUPS }
}

var hasSwift: Bool {
    segments.flatMap { $0.sections }.contains { 
        $0.sectname.hasPrefix("__swift5_")
    }
}
```

### Phase 2: Fixup Chain Resolution
```swift
// New file: ChainedFixups.swift
struct ChainedFixupsParser {
    func parseBindTable() -> [String]  // Ordinal → symbol name
    func resolvePointer(_ ptr: UInt64, at offset: UInt64) -> ResolvedPointer
}
```

### Phase 3: Swift Metadata Foundation
```swift
// New file: SwiftMetadata/TypeDescriptor.swift
struct SwiftTypeDescriptor {
    let kind: TypeKind  // class, struct, enum
    let name: String
    let fields: [SwiftField]
    let superclass: String?
}
```

### Phase 4: DSC Support
```swift
// New file: DyldSharedCache/DyldSharedCache.swift
struct DyldSharedCache {
    let url: URL
    let header: DyldCacheHeader
    let images: [DyldCacheImage]
    
    func machOFile(for image: DyldCacheImage) throws -> MachOFile
}
```

---

*This document should be updated as Apple releases new OS versions and binary format changes are discovered.*
