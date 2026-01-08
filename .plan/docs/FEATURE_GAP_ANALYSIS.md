# Feature Gap Analysis: ipsw vs class-dump

## Purpose

This document identifies features from **blacktop/ipsw** (dyld + macho commands) that are relevant to **class-dump's core mission**: generating Objective-C and Swift header files from Mach-O binaries.

This is a focused analysis—not an exhaustive comparison. We exclude features unrelated to header generation (disassembly, code signing, binary patching, etc.).

---

## Current class-dump Capabilities

| Capability | Status | Implementation |
|------------|--------|----------------|
| Parse Mach-O headers | ✅ | `MachOFile.swift`, `MachOHeader.swift` |
| Parse load commands | ✅ | `LoadCommand.swift`, `SegmentCommand.swift` |
| Handle fat/universal binaries | ✅ | `FatFile.swift` |
| Extract ObjC classes | ✅ | `ObjC2Processor.swift` |
| Extract ObjC protocols | ✅ | `ObjCProtocol.swift` |
| Extract ObjC categories | ✅ | `ObjCCategory.swift` |
| Extract ObjC methods/properties/ivars | ✅ | `ObjCMethod.swift`, `ObjCProperty.swift`, `ObjCInstanceVariable.swift` |
| Parse type encodings | ✅ | `ObjCTypeParser.swift`, `ObjCTypeLexer.swift` |
| Format type strings | ✅ | `ObjCTypeFormatter.swift` |
| Generate headers | ✅ | `TextClassDumpVisitor.swift`, `MultiFileVisitor.swift` |
| Decrypt protected segments | ⚠️ Partial | `SegmentDecryptor.swift` (legacy schemes only) |
| Parse Swift metadata | ❌ | Not implemented |
| Parse dyld_shared_cache | ❌ | Not implemented |
| Parse fixup chains (iOS 14+) | ❌ | Not implemented |

---

## Part 1: Critical Gaps (Block Core Functionality)

### 1.1 dyld_shared_cache (DSC) Support

**Impact:** Cannot analyze iOS system frameworks (UIKit, Foundation, etc.) which live in the DSC, not as individual files.

| Gap | ipsw Implementation | Priority |
|-----|---------------------|----------|
| DSC file format detection | `dyld_v1` magic, `dyld_cache_header` parsing | **CRITICAL** |
| Sub-cache support | Modern iOS splits DSC into .01, .02, etc. files | **CRITICAL** |
| Image enumeration | `dyld_cache_image_info` iteration | **CRITICAL** |
| In-cache Mach-O extraction | Get Mach-O data for a specific framework | **CRITICAL** |
| Memory-mapped reading | DSC files are 3+ GB; can't load into RAM | **CRITICAL** |
| Address translation | VM-to-offset with mappings and slide info | **HIGH** |

**ipsw API reference:**
```go
f, err := dyld.Open(dscPath)           // Open cache
images := f.Images                      // List all frameworks
image, err := f.Image("UIKit")         // Find specific image
m, err := image.GetMacho()             // Extract Mach-O
classes, err := m.GetObjCClasses()     // Parse ObjC
```

**class-dump needs:**
```swift
struct DyldSharedCache {
    init(contentsOf url: URL) throws    // Memory-mapped
    var images: [DyldCacheImage]
    func image(named: String) -> DyldCacheImage?
    func machOFile(for image: DyldCacheImage) throws -> MachOFile
}
```

---

### 1.2 Swift Metadata Parsing

**Impact:** Cannot generate headers for modern Swift apps/frameworks. Swift is now the dominant iOS language.

| Gap | ipsw Implementation | Priority |
|-----|---------------------|----------|
| Detect Swift binaries | `m.HasSwift()` | **HIGH** |
| Swift type extraction | `m.GetSwiftTypes()` - structs, classes, enums | **CRITICAL** |
| Swift protocol extraction | `m.GetSwiftProtocols()` | **CRITICAL** |
| Protocol conformances | `m.GetSwiftProtocolConformances()` | **HIGH** |
| Symbol demangling | `swift.DemangleBlob()`, `demangle.Do()` | **HIGH** |

**ipsw API reference:**
```go
if m.HasSwift() {
    types, _ := m.GetSwiftTypes()
    protocols, _ := m.GetSwiftProtocols()
    conformances, _ := m.GetSwiftProtocolConformances()
}
demangled := swift.DemangleBlob(mangledName)
```

**class-dump needs:**
```swift
extension MachOFile {
    var hasSwift: Bool
    func swiftTypes() throws -> [SwiftType]
    func swiftProtocols() throws -> [SwiftProtocol]
}

func demangleSwift(_ symbol: String) -> String
```

---

### 1.3 Fixup Chains (iOS 14+)

**Impact:** iOS 14+ binaries use `LC_DYLD_CHAINED_FIXUPS` instead of `LC_DYLD_INFO`. Without this, external class references cannot be resolved.

| Gap | ipsw Implementation | Priority |
|-----|---------------------|----------|
| Detect chained fixups | `m.HasFixups()` | **HIGH** |
| Parse fixup chains | `m.DyldChainedFixups()` | **HIGH** |
| Bind resolution | External symbol references | **HIGH** |
| Rebase handling | Internal pointer fixups | **MEDIUM** |

**ipsw API reference:**
```go
if m.HasFixups() {
    dcf, _ := m.DyldChainedFixups()
    for _, fixup := range dcf.Starts[0].Fixups {
        switch f := fixup.(type) {
        case fixupchains.Bind:   // External reference
        case fixupchains.Rebase: // Internal pointer
        }
    }
}
```

**class-dump needs:**
```swift
extension MachOFile {
    var hasFixups: Bool
    func chainedFixups() throws -> ChainedFixups
}

struct ChainedFixups {
    let binds: [ChainedBind]
    let rebases: [ChainedRebase]
}
```

---

## Part 2: Important Gaps (Improve Quality)

### 2.1 ObjC Shared Cache Optimization Tables

**Impact:** DSC has pre-optimized global ObjC tables. More efficient than per-image parsing.

| Gap | ipsw Implementation | Priority |
|-----|---------------------|----------|
| Global class table | `f.GetAllObjCClasses()` | **MEDIUM** |
| Global selector table | `f.GetAllObjCSelectors()` | **MEDIUM** |
| Global protocol table | `f.GetAllObjCProtocols()` | **MEDIUM** |
| IMP cache parsing | Pre-computed method implementations | **LOW** |

---

### 2.2 Mach-O Inspection Utilities

**Impact:** Users can't debug parsing failures or inspect binary structure.

| Gap | ipsw Implementation | Priority |
|-----|---------------------|----------|
| Header/load command dump | `macho info --header --loads` | **MEDIUM** |
| Address-to-offset conversion | `macho a2o`, `macho o2a` | **LOW** |
| Architecture extraction | `macho lipo` (write thin binary) | **MEDIUM** |
| JSON output | `--json` flag | **MEDIUM** |

---

### 2.3 Code Signature & Entitlements

**Impact:** Useful context for security analysis. Shows what APIs a binary can access.

| Gap | ipsw Implementation | Priority |
|-----|---------------------|----------|
| Entitlements extraction | `m.CodeSignature().Entitlements` | **LOW** |
| Certificate info | `macho info --sig` | **LOW** |

---

### 2.4 Address-to-Symbol Resolution

**Impact:** When showing method addresses (`-A` flag), symbols provide context.

| Gap | ipsw Implementation | Priority |
|-----|---------------------|----------|
| Symbol lookup by address | `m.FindAddressSymbols(addr)` | **LOW** |

---

## Part 3: Out of Scope

These ipsw features are **NOT relevant** to class-dump's header generation mission:

| Feature | Reason |
|---------|--------|
| Disassembly (`dyld disass`, `macho disass`) | Code analysis, not metadata |
| LLM Decompilation (`--dec`) | AI code understanding |
| Emulation (`dyld emu`) | Runtime analysis |
| IDA Integration (`dyld ida`) | Different tool |
| Code Signing (`macho sign`) | Binary modification |
| Load Command Patching (`macho patch`) | Binary modification |
| Cross-references (`dyld xref`) | Code flow analysis |
| WebKit/MobileGestalt | Domain-specific tools |
| TBD Generation | Different output format |
| Stub Islands | Linker internals |

---

## Implementation Roadmap

### Phase A: Foundation (Enable DSC Access)

| Task | Description | Effort |
|------|-------------|--------|
| A.1 | `MemoryMappedReader` for large files | Medium |
| A.2 | `DyldCacheHeader` parsing | Medium |
| A.3 | `DyldCacheImage` enumeration | Medium |
| A.4 | `SharedCacheAddressTranslator` (VM-to-offset) | High |
| A.5 | Slide info / rebase handling | High |

### Phase B: In-Cache Analysis (Zero-Copy)

| Task | Description | Effort |
|------|-------------|--------|
| B.1 | Extract Mach-O for specific image in cache | High |
| B.2 | Adapt `ObjC2Processor` for in-cache images | Medium |
| B.3 | Handle DSC-specific fixups and selector optimization | Medium |

### Phase C: Swift Support

| Task | Description | Effort |
|------|-------------|--------|
| C.1 | Detect Swift binaries (`hasSwift`) | Low |
| C.2 | Parse Swift type descriptors | High |
| C.3 | Parse Swift protocol descriptors | High |
| C.4 | Symbol demangling (call `swift-demangle` or reimplement) | Medium |
| C.5 | Generate Swift-style headers | High |

### Phase D: Modern Mach-O Support

| Task | Description | Effort |
|------|-------------|--------|
| D.1 | Parse `LC_DYLD_CHAINED_FIXUPS` | Medium |
| D.2 | Resolve chained binds to external symbols | Medium |
| D.3 | Handle chained rebases | Low |

### Phase E: Quality of Life

| Task | Description | Effort |
|------|-------------|--------|
| E.1 | JSON output option | Low |
| E.2 | `info` command (header/load command inspection) | Low |
| E.3 | Lipo export (write thin binary) | Medium |
| E.4 | Entitlements display | Low |
| E.5 | Address-to-symbol resolution for `-A` | Low |

---

## Priority Summary

| Priority | Feature | User Impact |
|----------|---------|-------------|
| 🔴 Critical | dyld_shared_cache support | Cannot analyze iOS system frameworks |
| 🔴 Critical | Swift metadata parsing | Cannot analyze modern Swift apps |
| 🟠 High | Fixup chains (iOS 14+) | Modern binaries may fail to parse |
| 🟡 Medium | Symbol demangling | Swift names unreadable |
| 🟡 Medium | JSON output | Hard to integrate with tools |
| 🟢 Low | Entitlements | Nice context info |
| 🟢 Low | Inspection utilities | Debugging aid |

---

## Reference Implementations

The **go-macho** library (https://github.com/blacktop/go-macho) provides mature Go implementations of:

- ObjC metadata parsing (comparable to class-dump)
- Swift metadata parsing (what class-dump needs)
- DSC handling (what class-dump needs)
- Fixup chains (what class-dump needs)

The **ipsw** tool (https://github.com/blacktop/ipsw) uses go-macho and adds CLI wrappers for all these features.

---

## What class-dump Does Well

- ✅ ObjC class/protocol/category header generation
- ✅ Type encoding parsing and formatting
- ✅ Fat/universal binary architecture selection
- ✅ Regex class name filtering (`-C`)
- ✅ Multiple output formats (stdout, individual headers)
- ✅ Method search functionality (`-f`)
- ✅ Ivar offset display (`-a`)
- ✅ Implementation address display (`-A`)
- ✅ Inheritance-based sorting (`-I`)
