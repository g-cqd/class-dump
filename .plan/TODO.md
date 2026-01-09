# class-dump - Remaining Work

**Current Status**: 776 tests passing | Swift 6.2 | Version 4.0.2

---

## Priority 1: Output Quality (HIGH PRIORITY)

### Task T07: Swift Standard Library Type Demangling
**Status**: ✅ Complete (commit 330d1c9)

Enhanced Swift stdlib type demangling to handle:
- `SD` prefix (Dictionary<K,V>)
- `Sa` prefix (Array<T>)
- `Sc` prefix (Continuation types)
- `So` prefix (ObjC imported types with `_p` protocol suffix)
- `Ss` prefix (String, other stdlib types)
- Nested generic arguments recursively
- 15 new tests for complex nested stdlib types

### Task T08: Output Mode Consistency & Formatting
**Status**: ✅ Complete

Implemented strict output mode enforcement with `--output-style` flag:

**ObjC Mode (default)** - All output is valid ObjC syntax:
- Pointer asterisks: `IDETestManager *testManager`
- Swift optionals converted: `IDETestable?` → `IDETestable *`
- Swift Dictionary syntax: `[String: Type]` → `NSDictionary *`
- Swift Array syntax: `[Type]` → `NSArray *`
- Class types get pointers: `Module.ClassName *`

**Swift Mode** - All output preserves Swift syntax:
- Use Swift type names: `String`, `[Type]`, `[Key: Value]`
- Use Swift optionals: `Type?`
- No pointer asterisks

**Flags**: `--output-style=objc|swift` (default: objc)

- [x] T08.1: Add `--output-style` flag with `objc` and `swift` options
- [x] T08.2: Implement ObjC formatter that converts all Swift syntax to ObjC
- [x] T08.3: Add pointer asterisks for Swift class type ivars in ObjC mode
- [x] T08.4: Convert Swift optionals to ObjC pointers in ObjC mode
- [x] T08.5: Convert Swift Dictionary/Array syntax to ObjC types in ObjC mode
- [x] T08.6: Investigated missing ivar names - handled by skipping invalid ivars
- [x] T08.7: Add tests for output mode consistency (14 new tests)
- [x] T08.8: Document the output mode flag in CLI help

---

## Priority 2: Type Resolution

### Task T09: Resolve Forward-Declared Types
**Status**: ✅ Complete

Created a StructureRegistry system to collect and resolve forward-declared types.

**Phase 1: Core Registry** (T09.1) ✅ Complete
- [x] T09.1.1: Create `StructureRegistry` class with register/resolve methods
- [x] T09.1.2: Add ObjCType helper methods (isForwardDeclaredStructure, structureName)
- [x] T09.1.3: Write unit tests for StructureRegistry (24 tests)
- [x] T09.1.4: Integrate with ObjC2Processor to collect structures
- [x] T09.1.5: Wire up to ObjCTypeFormatter for resolution during formatting
- [x] T09.1.6: Generate CDStructures.h content from registry

**Phase 2: Typedef Resolution** (T09.2) ✅ Complete
- [x] T09.2.1: Add typedef tracking for common types (CGFloat, NSInteger, etc.)
- [x] T09.2.2: Use Swift metadata field descriptors for type names (already implemented)

**Phase 3: @class Enhancement** (T09.3) ✅ Complete
- [x] T09.3.1: Enhance existing @class handling in MultiFileVisitor
- [x] T09.3.2: Only emit @class for truly external classes
- [x] T09.3.3: Fixed empty @class declarations bug

**Phase 4: Swift Metadata Cross-Reference** (T09.4) ✅ Complete
- [x] T09.4.1: Cross-reference Swift field descriptors for type resolution
- [x] T09.4.2: Implemented via SwiftSymbolicResolver

**Files**:
- `Sources/ClassDumpCore/TypeSystem/StructureRegistry.swift` (NEW)
- `Tests/ClassDumpCoreTests/TypeSystem/TestStructureRegistry.swift` (NEW)
- `Sources/ClassDumpCore/TypeSystem/ObjCTypeFormatter.swift`
- `Sources/ClassDumpCore/ObjCMetadata/ObjC2Processor.swift`
- `Sources/ClassDumpCore/Visitor/ClassDumpVisitor.swift`
- `Sources/ClassDumpCLI/main.swift`

### Task T10: Block Type Resolution Improvements
**Status**: ✅ Complete

**T10.1: Protocol Method Signature Cross-Reference** ✅ Complete
- Created `MethodSignatureRegistry` to index protocol method signatures by selector
- Block types without signatures (`@?`) can now be enhanced with richer signatures from protocol methods
- Protocol sources are prioritized over class sources
- Registry wired into `ObjCTypeFormatter` for automatic block type enhancement
- 14 new tests for MethodSignatureRegistry

**T10.2: Swift Closure to ObjC Block Conversion** ✅ Complete
- Swift closure types from field descriptors now convert to ObjC block syntax in ObjC output mode
- `(String) -> Void` → `void (^)(NSString *)`
- `@escaping (Int, Bool) -> String` → `NSString * (^)(NSInteger, BOOL)`
- Handles common Swift-to-ObjC type mappings (String→NSString, Int→NSInteger, Bool→BOOL, etc.)
- Strips @escaping, @Sendable and other attributes before conversion
- Swift output mode preserves original closure syntax
- 7 new tests for closure conversion

**T10.3: Add --show-raw-types Debugging Flag** ✅ Complete
- Added `--show-raw-types` flag to CLI
- Methods show raw type encoding in comments: `// @24@0:8@16`
- Ivars show raw ObjC type encoding: `// @"NSString"`
- Properties show raw attribute string: `// T@"NSString",R,C,V_name`
- 5 new tests for show-raw-types feature

**Files**:
- `Sources/ClassDumpCore/TypeSystem/MethodSignatureRegistry.swift` (NEW)
- `Tests/ClassDumpCoreTests/TypeSystem/TestMethodSignatureRegistry.swift` (NEW)
- `Sources/ClassDumpCore/TypeSystem/ObjCTypeFormatter.swift`
- `Sources/ClassDumpCore/ObjCMetadata/ObjC2Processor.swift`
- `Sources/ClassDumpCore/Visitor/ClassDumpVisitor.swift`
- `Sources/ClassDumpCore/Visitor/TextClassDumpVisitor.swift`
- `Sources/ClassDumpCLI/main.swift`

---

## Priority 3: Performance & Concurrency

### Task T11: Concurrency & Performance Pass
**Status**: Not started

- [ ] T11.1: Implement TaskGroup parsing for parallel file scanning
- [ ] T11.2: Memory-mapped file IO for large binaries
- [ ] T11.3: Cache tables and strings to avoid repeated parsing
- [ ] T11.4: Profile and benchmark against IDEFoundation.framework

---

## Priority 4: System Integration

### Task T12: System swift-demangle Integration
**Status**: Not started

- [ ] T12.1: Shell out to `/usr/bin/swift-demangle` for complex cases
- [ ] T12.2: Cache results for repeated symbols
- [ ] T12.3: Fall back to built-in demangler if unavailable

### Task T13: Optional libswiftDemangle Linking
**Status**: Not started

- [ ] T13.1: `dlopen` the Swift runtime library
- [ ] T13.2: Use `swift_demangle` C API for full accuracy
- [ ] T13.3: Handle symbol versioning across Swift versions

### Task T14: Demangling Cache
**Status**: Not started

- [ ] T14.1: LRU cache for demangled names
- [ ] T14.2: Thread-safe implementation
- [ ] T14.3: Optional persistence across runs

---

## Priority 5: Output Format Options

### Task T15: Swift Output Mode
**Status**: Not started

- [ ] T15.1: Add `--swift` output mode
- [ ] T15.2: Output `.swiftinterface`-style declarations
- [ ] T15.3: Include access control, attributes
- [ ] T15.4: Format: `public class Name: SuperClass, Protocol { ... }`

### Task T16: Mixed Output Mode
**Status**: Not started

- [ ] T16.1: Add `--mixed` output mode
- [ ] T16.2: Show both ObjC and Swift representations
- [ ] T16.3: Useful for bridging header generation

### Task T17: JSON Output Mode
**Status**: Not started

- [ ] T17.1: Add `--json` structured output
- [ ] T17.2: Machine-readable type information
- [ ] T17.3: Include both mangled and demangled names
- [ ] T17.4: Include source locations, offsets

---

## Future: dyld_shared_cache Integration

### Task T18: Shared Cache Foundation
- [ ] T18.1: Implement `MemoryMappedReader` for large file access (3+ GB)
- [ ] T18.2: Parse `dyld_cache_header` (magic, mappings, images)
- [ ] T18.3: Support split caches (.01, .02, etc.)

### Task T19: Address Translation
- [ ] T19.1: Implement `SharedCacheAddressTranslator` for VM-to-offset
- [ ] T19.2: Parse `dyld_cache_slide_info` for pointer rebasing
- [ ] T19.3: Handle multiple cache mappings

### Task T20: In-Cache Image Analysis
- [ ] T20.1: List available images in shared cache
- [ ] T20.2: Extract Mach-O data for specific image (zero-copy)
- [ ] T20.3: Adapt `ObjC2Processor` for in-cache images
- [ ] T20.4: Handle DSC-specific ObjC optimizations

### Task T21: ObjC Optimization Tables
- [ ] T21.1: Parse global class/selector/protocol tables
- [ ] T21.2: Faster lookup via shared tables

---

## Future: Quality of Life

### Task T22: Inspection Command
- [ ] T22.1: Add `class-dump info` subcommand
- [ ] T22.2: Display Mach-O header, load commands, sections
- [ ] T22.3: Show architecture, platform, deployment target

### Task T23: Address Utilities
- [ ] T23.1: Expose `a2o` / `o2a` conversion for debugging
- [ ] T23.2: Resolve addresses to symbol names for `-A` output

### Task T24: Lipo Export
- [ ] T24.1: Extract single architecture to standalone file

### Task T25: Entitlements Display
- [ ] T25.1: Parse LC_CODE_SIGNATURE blob
- [ ] T25.2: Extract and display XML entitlements

### Task T26: DocC Generator
- [ ] T26.1: Generate DocC-compatible documentation from dumps
- [ ] T26.2: Support merging multiple framework dumps
- [ ] T26.3: Symbol graph generation for Xcode integration

---

## Future: Advanced Capabilities

### Task T27: Full Swift Type Support
- [ ] T27.1: Extensions
- [ ] T27.2: Property wrappers
- [ ] T27.3: Result builders

### Task T28: Recursive Framework Resolution
- [ ] T28.1: Dependency resolution with caching

### Task T29: Watch Mode
- [ ] T29.1: Incremental re-dumping on file changes

### Task T30: LSP Integration
- [ ] T30.1: IDE support for class-dump output

### Task T31: Dylib Extraction
- [ ] T31.1: Reconstruct standalone Mach-O from cached image
- [ ] T31.2: Handle LINKEDIT reconstruction

---

## Benchmarking

Use this command to benchmark against a real-world Swift framework:

```bash
time class-dump "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation" > /dev/null
```

This binary tests:
- Extensive Swift metadata alongside ObjC classes
- Chained fixups (iOS 14+ format)
- Complex generic types and protocol conformances
- Large enough to reveal performance issues

---

## Reference Documentation

- **Feature Gap Analysis**: `.plan/docs/FEATURE_GAP_ANALYSIS.md`
- **Cutting-Edge Research**: `.plan/docs/CUTTING_EDGE_RESEARCH.md`
- **ipsw dyld commands**: https://github.com/blacktop/ipsw/tree/master/cmd/ipsw/cmd/dyld
- **ipsw macho commands**: https://github.com/blacktop/ipsw/tree/master/cmd/ipsw/cmd/macho
- **go-macho library**: https://github.com/blacktop/go-macho
- **MachOKit (Swift)**: https://github.com/p-x9/MachOKit
- **MachOSwiftSection**: https://github.com/MxIris-Reverse-Engineering/MachOSwiftSection
- **Apple dyld source**: https://github.com/apple-oss-distributions/dyld
- **Apple objc4 source**: https://github.com/apple-oss-distributions/objc4
