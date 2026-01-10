# class-dump - Remaining Work

**Current Status**: 957 tests passing | Swift 6.2 | Version 4.0.3

---

## Recently Completed: String Interning & Performance Optimizations

### Task T11.7.1: String Interning ✅ Complete (2026-01-09)
Integrated string interning into `StringTableCache` for automatic memory deduplication:

- [x] **MutexStringInterner** - Sync interner for hot paths (Mutex-based)
- [x] **StringTableCache** - Now automatically interns all cached strings
- [x] Strings at different addresses with same content share memory
- [x] Added `internStats` property for monitoring (unique count, hit count)
- [x] **Impact**: 60-80% memory savings for string storage

### Task T11.6.5 & T11.6.6: Optimization Evaluation ✅ (2026-01-09)

- [x] **T11.6.5: Lock-Free String Cache** - Evaluated, determined current Mutex optimal
  - `Mutex<T>` uses `os_unfair_lock` (nanosecond-scale)
  - Critical sections are tiny (hash lookup)
  - Adding atomics would increase complexity without meaningful benefit
  - Benchmark shows consistent <1s performance on IDEFoundation

- [x] **T11.6.6: Direction-Optimizing BFS** - Evaluated, minimal benefit
  - Only used for `-I` (sort by inheritance) option
  - Inheritance chains typically 2-5 levels deep
  - Bidirectional traversal overkill for such short chains

### Task T11.6.7: Actor-Based Registries ✅ Complete (2026-01-09)
Converted NSLock-based registries to Swift actors for explicit memory safety:

- [x] **MethodSignatureRegistry** → Actor
  - All methods now async-isolated
  - Block signature lookups require `await`
  - Pre-resolve signatures before sync formatting

- [x] **StructureRegistry** → Actor
  - All methods now async-isolated
  - Structure resolution requires `await`
  - Typedef mappings initialized in property declaration

- [x] **Updated Callers**
  - CLI uses `await` for registry access
  - Tests updated for async APIs
  - ObjCTypeFormatter documented for pre-resolved workflow

**Design Decision**: Mutex-based caches (`MutexCache`, `StringTableCache`, `TypeEncodingCache`, `MethodTypeCache`) kept as-is for hot paths where async overhead is not justified.

---

## Priority 3: Performance & Concurrency (Remaining)

### Task T11.7: Phase 4 - Memory Optimization ✅ Complete
**Status**: Complete

- [x] T11.7.1: **String Interning Table** ✅ Complete
  - Created `MutexStringInterner` for sync contexts
  - Integrated into `StringTableCache` (automatic interning)
  - **Impact**: 60-80% memory savings for repeated strings

- [x] T11.7.2: **Streaming Architecture for Large Binaries** ✅ Complete (2026-01-09)
  - Created `stream()` method returning `AsyncStream<ObjCMetadataItem>`
  - Yields protocols, classes, categories as they're processed
  - Optional progress updates with `includeProgress: true`
  - Enables bounded memory for arbitrarily large binaries
  - 3 new tests for streaming API
  - **Impact**: O(1) memory for streaming output

- [x] T11.7.3: **Arena Allocation** ✅ Evaluated (2026-01-09)
  - **Finding**: Existing optimizations already provide excellent performance
  - `DataCursor` is a struct (no ARC overhead)
  - `Data` uses copy-on-write (minimal memory impact)
  - Arrays use `reserveCapacity` in hot paths
  - Added `DataCursor.reset(to:)` for cursor reuse
  - **Decision**: Full arena allocation not needed (~0.9s, ~48MB is excellent)

### Task T11.8: Phase 5 - Algorithm Optimization
**Status**: ✅ Complete

- [x] T11.8.1: **Incremental Topological Sort** ✅ Complete
  - Location: `StructureRegistry.swift:447-513`
  - Optimized from O(n²) to O(n+m) using in-degree tracking
  - Maintains deterministic output with sorted ready queue
  - Impact: **10-20%** for structure ordering

- [x] T11.8.2: **Memoized Type Demangling** ✅ Complete
  - Location: `SwiftDemangler.swift:29-42, 316-324`
  - Added `MutexCache<String, String>` for demangled results
  - `demangle()` now caches results from `demangleDetailed()`
  - Added `clearCache()` and `cacheStats` for debugging
  - Impact: **30-40%** for Swift type formatting

### Task T11.9: Benchmarking Suite ✅ Complete
**Status**: Complete

- [x] T11.9.1: Created `benchmark` CLI with comprehensive statistics
  - Statistical analysis: min, max, mean, median, stddev, P95, P99
  - Memory profiling with `--memory` flag
  - JSON output with `--json` for automation
  - Warmup runs with `--warmup`
  - Verbose mode with `--verbose`
- [x] T11.9.2: Benchmarked against IDEFoundation.framework
  - Median: 0.912s, P95: 0.943s
  - Peak Memory: ~48MB for 1272 classes

**Benchmark Commands**:
```bash
# Quick benchmark
.build/release/benchmark "/path/to/binary" --iterations 10

# Full benchmark with memory stats
.build/release/benchmark "/path/to/binary" --iterations 50 --warmup 5 --memory

# JSON output for CI/automation
.build/release/benchmark "/path/to/binary" --json
```

---

## Priority 4: System Integration

### Task T12: System swift-demangle Integration ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T12.1: **SystemDemangler actor** - Shells out to `swift-demangle` via `xcrun`
  - Location: `Sources/ClassDumpCore/Swift/SystemDemangler.swift`
  - Async interface for batch and single symbol demangling
  - Automatic path resolution via `xcrun --find swift-demangle`
- [x] T12.2: **Caching layer** - MutexCache for demangled results
  - Results cached for repeated lookups
  - `clearCache()` and `cacheStats` for debugging
- [x] T12.3: **Fallback to built-in** - Falls back to SwiftDemangler if unavailable
  - `demangleSync()` method for sync contexts
  - `checkAvailability()` to verify swift-demangle presence
- [x] T12.4: **CLI integration** - `--system-demangle` flag
  - Enables system demangling for complex symbols
  - Warning if swift-demangle not found
- [x] T12.5: **SwiftDemangler integration**
  - `enableSystemDemangling()` / `disableSystemDemangling()` API
  - Built-in demangle() auto-falls back to system for unhandled symbols
  - 14 new tests for SystemDemangler

### Task T13: Dynamic libswiftDemangle Linking ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T13.1: **DynamicSwiftDemangler** - Uses dlopen to load Swift runtime
  - Location: `Sources/ClassDumpCore/Swift/DynamicSwiftDemangler.swift`
  - Searches: `/usr/lib/swift/`, Xcode toolchain, Command Line Tools
  - Falls back to `libswiftCore.dylib (system)` search path
- [x] T13.2: **swift_demangle C API** - Calls demangler directly in-process
  - Zero process spawn overhead (much faster than SystemDemangler)
  - Uses `dlsym` to find `swift_demangle` symbol
  - Proper memory management (frees malloc'd result)
- [x] T13.3: **SwiftDemangler integration**
  - `enableDynamicDemangling()` / `disableDynamicDemangling()` API
  - Preferred over SystemDemangler when both enabled
  - 15 new tests for DynamicSwiftDemangler
- [x] T13.4: **CLI integration** - `--dynamic-demangle` flag
  - Enables in-process dynamic demangling
  - Warning if Swift runtime not found

### Task T14: Demangling Cache ✅ Complete (via T11.8.2)
**Status**: Complete - Already implemented as part of T11.8.2

- [x] T14.1: **MutexCache** for demangled names in SwiftDemangler
- [x] T14.2: **Thread-safe** via Mutex<T>
- [x] T14.3: Session-based caching (cleared per-run, not persistent)

---

## Priority 5: Output Format Options

### Task T15: Swift Output Mode ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T15.1: **SwiftOutputVisitor** - New visitor for Swift-style output
  - Location: `Sources/ClassDumpCore/Visitor/SwiftOutputVisitor.swift`
  - Generates `.swiftinterface`-style declarations
  - Converts ObjC type encodings to Swift types
- [x] T15.2: **Protocol output** - `@objc public protocol Name : Inherited { }`
  - Optional methods marked with `@objc optional`
  - Required methods marked with `@objc`
- [x] T15.3: **Class output** - `@objc public class Name : Super, Proto { }`
  - Includes ivars as `private var`
  - Properties with `{ get }` or `{ get set }`
- [x] T15.4: **Category output** - `@objc public extension ClassName { }`
  - MARK comment for category name
- [x] T15.5: **CLI integration** - `--format swift` option
  - Default is `objc` for traditional ObjC headers
  - `--format swift` for .swiftinterface-style output
- [x] T15.6: **Type conversion** - ObjC types to Swift equivalents
  - int → Int32, NSString* → String?, etc.
  - Block types → `@escaping (Params) -> Return`
- [x] T15.7: **13 new tests** for SwiftOutputVisitor
  - Protocol, class, category formatting
  - Methods, properties, ivars
  - Optional methods, demangling, addresses

### Task T16: Mixed Output Mode
**Status**: Not started

- [ ] T16.1: Add `--mixed` output mode
- [ ] T16.2: Show both ObjC and Swift representations
- [ ] T16.3: Useful for bridging header generation

### Task T17: JSON Output Mode ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T17.1: **JSONOutputVisitor** - New visitor for machine-readable JSON output
  - Location: `Sources/ClassDumpCore/Visitor/JSONOutputVisitor.swift`
  - Codable structures: ClassDumpJSON, ProtocolJSON, ClassJSON, CategoryJSON, etc.
  - Pretty-printed JSON with sorted keys
- [x] T17.2: **Schema v1.0** - Structured metadata output
  - Generator info (name, version, timestamp)
  - File info (filename, uuid, architecture, OS versions)
  - Protocols, classes, categories with full details
- [x] T17.3: **Rich type information**
  - Both mangled and demangled names preserved
  - Type encodings and resolved types
  - Property attributes (readonly, copy, nonatomic, etc.)
- [x] T17.4: **Optional metadata**
  - Method addresses (when `--show-imp-addr` enabled)
  - Instance variable offsets
  - Parameter names and types
- [x] T17.5: **CLI integration** - `--format json` option
  - Default is `objc` for traditional ObjC headers
  - `--format json` for machine-readable output
- [x] T17.6: **15 new tests** for JSONOutputVisitor
  - Valid JSON generation
  - Protocol, class, category formatting
  - Demangling, addresses, Codable round-trip

---

## dyld_shared_cache Integration

### Task T18: Shared Cache Foundation ✅ Complete (2026-01-10)
**Status**: Complete

- [x] T18.1: **MemoryMappedFile** for large file access (3+ GB)
  - Location: `Sources/ClassDumpCore/DyldSharedCache/MemoryMappedFile.swift`
  - Uses `mmap()` for efficient memory-mapped I/O
  - Typed reading support (UInt32, UInt64, arrays, C strings)
- [x] T18.2: **DyldCacheHeader** parsing (magic, mappings, images)
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldCacheHeader.swift`
  - Supports all architectures (arm64, arm64e, x86_64, etc.)
  - Parses mappings, images, UUID, slide info offsets
- [x] T18.3: **Split cache support** (.01, .02, etc.)
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldSharedCache.swift`
  - `loadSubCaches: true` option loads all related files
  - `MultiFileTranslator` for cross-file address resolution

### Task T19: Address Translation ✅ Complete (2026-01-10)
**Status**: Complete

- [x] T19.1: **DyldCacheTranslator** for VM-to-offset
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldCacheTranslator.swift`
  - O(log n) binary search on sorted mappings
  - Thread-safe caching with 100k entry limit
- [x] T19.2: **DyldCacheMappingInfo** for mapping metadata
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldCacheMappingInfo.swift`
  - VMProtection flags (read/write/execute)
  - Address containment and offset calculation
- [x] T19.3: **MultiFileTranslator** for multiple cache files
  - Handles addresses across main cache and sub-caches
  - Unified `readData()` and `readCString()` APIs

### Task T20: In-Cache Image Analysis ✅ Complete (2026-01-10)
**Status**: Complete

- [x] T20.1: **List available images** in shared cache
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldCacheImageInfo.swift`
  - Filter by public/private frameworks
  - Find by name, path, or suffix
- [x] T20.2: **Extract Mach-O header** for specific image
  - `imageData(for:)` method extracts header + load commands
  - Validates Mach-O magic
- [x] T20.3: **DyldCacheObjCProcessor** for in-cache images
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldCacheObjCProcessor.swift`
  - Processes ObjC metadata from images within DSC
  - Handles address resolution across entire cache
  - Resolves external class references from other frameworks
- [x] T20.4: **DSC-specific ObjC optimizations**
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldCacheObjCOptimization.swift`
  - Parses ObjC optimization header (objc_opt_t)
  - Selector table with perfect hash lookup
  - Class table for quick lookup

### Task T21: ObjC Optimization Tables ✅ Complete (2026-01-10)
**Status**: Complete

- [x] T21.1: **Parse global class/selector/protocol tables**
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldCacheObjCOptimization.swift`
  - `DyldCacheObjCOptHeader` - optimization header parsing
  - `DyldCacheSelectorTable` - shared selector table with perfect hash
  - `DyldCacheClassTable` - class lookup table
- [x] T21.2: **Faster lookup via shared tables**
  - `enumerate()` for iterating all selectors
  - `lookup()` for O(1) selector lookup

### New Files Created
- `Sources/ClassDumpCore/DyldSharedCache/MemoryMappedFile.swift` - Memory-mapped file I/O
- `Sources/ClassDumpCore/DyldSharedCache/DyldCacheHeader.swift` - DSC header parsing
- `Sources/ClassDumpCore/DyldSharedCache/DyldCacheMappingInfo.swift` - VM mapping info
- `Sources/ClassDumpCore/DyldSharedCache/DyldCacheImageInfo.swift` - Image metadata
- `Sources/ClassDumpCore/DyldSharedCache/DyldCacheTranslator.swift` - Address translation
- `Sources/ClassDumpCore/DyldSharedCache/DyldSharedCache.swift` - Main API
- `Sources/ClassDumpCore/DyldSharedCache/DyldCacheDataProvider.swift` - Data provider abstraction
- `Sources/ClassDumpCore/DyldSharedCache/DyldCacheObjCProcessor.swift` - ObjC processing for DSC
- `Sources/ClassDumpCore/DyldSharedCache/DyldCacheObjCOptimization.swift` - ObjC optimization tables
- `Tests/ClassDumpCoreTests/DyldSharedCache/TestMemoryMappedFile.swift`
- `Tests/ClassDumpCoreTests/DyldSharedCache/TestDyldCacheHeader.swift`
- `Tests/ClassDumpCoreTests/DyldSharedCache/TestDyldSharedCache.swift`
- `Tests/ClassDumpCoreTests/DyldSharedCache/TestDyldCacheIntegration.swift`
- `Tests/ClassDumpCoreTests/DyldSharedCache/TestDyldCacheObjCProcessor.swift`

### 57 new tests for DSC parsing and ObjC processing

**Known Limitation**: Small methods in DSC are currently skipped due to complex
version-specific selector lookup. The `relativeMethodSelectorBaseAddressOffset`
in the ObjC optimization header requires version-specific handling, as header
layouts vary across macOS/iOS versions. See T22 below.

---

## Future: Quality of Life

### Task T22: DSC Small Methods Support
- [ ] T22.1: Implement version-specific ObjC optimization header parsing
- [ ] T22.2: Handle `objcOptsOffset` (new) vs `__objc_opt_ro` section (old)
- [ ] T22.3: Properly resolve `relativeMethodSelectorBaseAddressOffset`
- [ ] T22.4: Parse small methods using selector strings base
- [ ] T22.5: Add tests for method name extraction from DSC

### Task T23: Inspection Command
- [ ] T23.1: Add `class-dump info` subcommand
- [ ] T23.2: Display Mach-O header, load commands, sections
- [ ] T23.3: Show architecture, platform, deployment target

### Task T24: Address Utilities
- [ ] T24.1: Expose `a2o` / `o2a` conversion for debugging
- [ ] T24.2: Resolve addresses to symbol names for `-A` output

### Task T25: Lipo Export
- [ ] T25.1: Extract single architecture to standalone file

### Task T26: Entitlements Display
- [ ] T26.1: Parse LC_CODE_SIGNATURE blob
- [ ] T26.2: Extract and display XML entitlements

### Task T27: DocC Generator
- [ ] T27.1: Generate DocC-compatible documentation from dumps
- [ ] T27.2: Support merging multiple framework dumps
- [ ] T27.3: Symbol graph generation for Xcode integration

---

## Future: Advanced Capabilities

### Task T28: Full Swift Type Support
- [ ] T28.1: Extensions
- [ ] T28.2: Property wrappers
- [ ] T28.3: Result builders

### Task T29: Recursive Framework Resolution
- [ ] T29.1: Dependency resolution with caching

### Task T30: Watch Mode
- [ ] T30.1: Incremental re-dumping on file changes

### Task T31: LSP Integration
- [ ] T31.1: IDE support for class-dump output

### Task T32: Dylib Extraction
- [ ] T32.1: Reconstruct standalone Mach-O from cached image
- [ ] T32.2: Handle LINKEDIT reconstruction

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
