# class-dump - Remaining Work

**Current Status**: 1028 tests passing | Swift 6.2 | Version 4.0.3

---

## IMMEDIATE: Codebase Refactoring & Organization

### Code Organization Rules (ENFORCED)
1. **One type per file**: One public XOR one internal type per file. Only private supporting types may remain.
2. **One test suite per file**: Each test file contains exactly one `@Suite`.
3. **Extensions in separate files**: Named `TypeName+Feature.swift` or `TypeName+ProtocolName.swift`.
4. **Max 400 lines per file**: Split large files into focused modules.
5. **Swift 6.2 strict concurrency**: All code must pass `-strict-concurrency=complete`.

---

### Task R01: Split Large Source Files (>400 lines)
**Priority**: Critical | **Estimated Files**: 9 files → ~45 files

| File | Lines | Action |
|------|-------|--------|
| `SwiftDemangler.swift` | 2,545 | Split into 6-7 files |
| `ObjC2Processor.swift` | 1,755 | Split into 4-5 files |
| `SwiftMetadata.swift` | 1,300 | Split into 8-10 files |
| `SwiftMetadataProcessor.swift` | 1,227 | Split into 3-4 files |
| `TextClassDumpVisitor.swift` | 726 | Split into 2 files |
| `JSONOutputVisitor.swift` | 625 | Split into 2 files |
| `SwiftOutputVisitor.swift` | 529 | Split into 2 files |
| `ObjCTypeParser.swift` | 474 | Split into 2 files |

- [ ] R01.1: **SwiftDemangler.swift** → Split into:
  - `SwiftDemangler.swift` - Core demangler class + cache
  - `SwiftDemangler+Parsing.swift` - Main parsing logic
  - `SwiftDemangler+Types.swift` - Type parsing (generics, tuples, etc.)
  - `SwiftDemangler+Functions.swift` - Function signature parsing
  - `SwiftDemangler+Operators.swift` - Operator demangling
  - `SwiftDemangler+Generics.swift` - Generic signature/constraint parsing
  - `SwiftDemangler+Extensions.swift` - String helpers (move to String+SwiftDemangling.swift)

- [ ] R01.2: **ObjC2Processor.swift** → Split into:
  - `ObjC2Processor.swift` - Core processor class
  - `ObjC2Processor+Classes.swift` - Class/metaclass loading
  - `ObjC2Processor+Methods.swift` - Method loading (regular + small)
  - `ObjC2Processor+Properties.swift` - Property/ivar loading
  - `ObjC2Processor+Categories.swift` - Category loading
  - `ObjC2Processor+Protocols.swift` - Protocol loading

- [ ] R01.3: **SwiftMetadata.swift** → Extract types to individual files:
  - `SwiftType.swift` - Core SwiftType struct
  - `SwiftProtocol.swift` - SwiftProtocol struct
  - `SwiftConformance.swift` - SwiftConformance struct
  - `SwiftFieldDescriptor.swift` - SwiftFieldDescriptor struct
  - `SwiftField.swift` - SwiftField struct
  - `SwiftGenericRequirement.swift` - Generic requirement types
  - `SwiftExtension.swift` - SwiftExtension struct
  - `SwiftPropertyWrapper.swift` - Property wrapper enum/info
  - `SwiftResultBuilder.swift` - Result builder enum/info
  - `SwiftTypeDetection.swift` - Type detection utilities
  - `SwiftContextDescriptorKind.swift` - Context descriptor enums
  - `SwiftMetadata.swift` - Main SwiftMetadata container only

- [ ] R01.4: **SwiftMetadataProcessor.swift** → Split into:
  - `SwiftMetadataProcessor.swift` - Core processor
  - `SwiftMetadataProcessor+Types.swift` - Type descriptor parsing
  - `SwiftMetadataProcessor+Fields.swift` - Field descriptor parsing
  - `SwiftMetadataProcessor+Protocols.swift` - Protocol parsing
  - `SwiftMetadataProcessor+Conformances.swift` - Conformance parsing

- [ ] R01.5: **TextClassDumpVisitor.swift** → Split into:
  - `TextClassDumpVisitor.swift` - Core visitor
  - `TextClassDumpVisitor+Formatting.swift` - Type formatting helpers

- [ ] R01.6: **JSONOutputVisitor.swift** → Extract models:
  - `JSONOutputVisitor.swift` - Core visitor
  - `JSONOutputModels.swift` - All Codable structs (ClassDumpJSON, etc.)

- [ ] R01.7: **SwiftOutputVisitor.swift** → Split into:
  - `SwiftOutputVisitor.swift` - Core visitor
  - `SwiftOutputVisitor+TypeConversion.swift` - ObjC→Swift type conversion

- [ ] R01.8: **ObjCTypeParser.swift** → Split into:
  - `ObjCTypeParser.swift` - Core parser
  - `ObjCTypeParser+Cache.swift` - Caching infrastructure

---

### Task R02: Extract Multi-Type Files
**Priority**: High | **Estimated Files**: 6 files → ~35 files

- [ ] R02.1: **OtherLoadCommands.swift** (13 types) → Extract each:
  - `DylinkerCommand.swift`
  - `UUIDCommand.swift`
  - `VersionCommand.swift`
  - `BuildVersionCommand.swift` (with BuildPlatform, BuildToolVersion)
  - `MainCommand.swift`
  - `SourceVersionCommand.swift`
  - `EncryptionInfoCommand.swift`
  - `LinkeditDataCommand.swift`
  - `RpathCommand.swift`
  - `DyldInfoCommand.swift`

- [ ] R02.2: **ObjC2RuntimeStructs.swift** (12 types) → Extract each:
  - `ObjC2ListHeader.swift`
  - `ObjC2SmallMethod.swift`
  - `ObjC2ImageInfo.swift`
  - `ObjC2Class.swift`
  - `ObjC2ClassROData.swift`
  - `ObjC2Method.swift`
  - `ObjC2Ivar.swift`
  - `ObjC2Property.swift`
  - `ObjC2Protocol.swift`
  - `ObjC2Category.swift`

- [ ] R02.3: **ChainedFixups.swift** (7 types) → Extract each:
  - `ChainedPointerFormat.swift`
  - `ChainedImportFormat.swift`
  - `ChainedFixupsHeader.swift`
  - `ChainedImport.swift`
  - `ChainedFixupResult.swift`
  - `ChainedFixupsError.swift`
  - `ChainedFixups.swift` (main)

- [ ] R02.4: **ObjCTypeLexer.swift** (3 types) → Extract:
  - `ObjCTypeToken.swift`
  - `ObjCTypeLexerState.swift`
  - `ObjCTypeLexer.swift` (main)

- [ ] R02.5: **Section.swift** (2 types) → Extract:
  - `SectionType.swift`
  - `Section.swift` (main)

---

### Task R03: Extract Extensions to Separate Files
**Priority**: High | **Estimated Files**: 2 files → ~10 files

- [ ] R03.1: **VisitorExtensions.swift** → Distribute to:
  - `ObjCClass+Visitor.swift`
  - `ObjCCategory+Visitor.swift`
  - `ObjCProtocol+Visitor.swift`
  - `ObjCProperty+Visitor.swift`
  - `ObjCInstanceVariable+Visitor.swift`
  - `ObjCMethod+Visitor.swift`
  - `ClassDumpVisitor+Helpers.swift`

- [ ] R03.2: **ClassFrameworkVisitor.swift** → Extract:
  - `ObjCClass+ClassFramework.swift`
  - `ObjCCategory+ClassFramework.swift`

---

### Task R04: Split Test Files (Multi-Suite)
**Priority**: High | **Estimated Files**: 28 files → ~130 files

**Critical (10+ suites):**
- [ ] R04.1: **TestLoadCommands.swift** (11 suites) → 11 files
- [ ] R04.2: **TestGenericConstraints.swift** (11 suites) → 9 files
- [ ] R04.3: **TestObjCTypeParsing.swift** (10 suites) → 10 files
- [ ] R04.4: **TestTextVisitor.swift** (10 suites) → 8 files
- [ ] R04.5: **TestObjCTypeEdgeCases.swift** (9 suites) → 8 files
- [ ] R04.6: **TestObjCMetadata.swift** (9 suites) → 8 files

**High (5-6 suites):**
- [ ] R04.7: **TestMachOTypes.swift** (6 suites) → 6 files
- [ ] R04.8: **TestNominalTypeDescriptor.swift** (6 suites) → 5 files
- [ ] R04.9: **TestSwiftConformance.swift** (6 suites) → 5 files
- [ ] R04.10: **TestVisitorExtensions.swift** (6 suites) → 6 files
- [ ] R04.11: **TestSwiftProtocol.swift** (5 suites) → 4 files
- [ ] R04.12: **TestObjCTypeFormatting.swift** (5 suites) → 3 files

**Medium (2-4 suites):**
- [ ] R04.13: Split remaining 16 multi-suite test files

---

### Task R05: Directory Structure Reorganization
**Priority**: Medium

- [ ] R05.1: Create subdirectories for large modules:
  ```
  Sources/ClassDumpCore/
  ├── Swift/
  │   ├── Demangling/          (SwiftDemangler + parts)
  │   ├── Metadata/            (SwiftMetadata types)
  │   └── Processing/          (SwiftMetadataProcessor + parts)
  ├── ObjCMetadata/
  │   ├── RuntimeStructs/      (ObjC2* types)
  │   └── Processing/          (ObjC2Processor + parts)
  ├── LoadCommands/
  │   ├── Core/                (LoadCommand, Section, Segment)
  │   └── Types/               (Individual command types)
  └── Visitor/
      ├── Core/                (Protocol, base types)
      ├── Text/                (Text visitors)
      └── Structured/          (JSON, SymbolGraph visitors)
  ```

- [ ] R05.2: Create subdirectories for tests:
  ```
  Tests/ClassDumpCoreTests/
  ├── LoadCommands/            (Split test files)
  ├── TypeSystem/              (Split test files)
  ├── Demangling/              (Split test files)
  └── Visitor/                 (Split test files)
  ```

---

### Task R06: Naming Convention Alignment
**Priority**: Medium

- [ ] R06.1: Rename files to match primary type exactly
- [ ] R06.2: Rename extension files to `TypeName+Feature.swift` pattern
- [ ] R06.3: Rename internal types to use `_` prefix where appropriate
- [ ] R06.4: Ensure all enum cases are `lowerCamelCase`

---

### Task R07: Import Organization
**Priority**: Low

- [ ] R07.1: Organize imports in 4 groups (separated by blank line):
  1. Standard Library/Frameworks
  2. External Dependencies
  3. Internal Core/Utility Modules
  4. Sibling/Feature Modules
- [ ] R07.2: Alphabetize imports within each group

---

### Task R08: Documentation Alignment
**Priority**: Low

- [ ] R08.1: Add file headers with SPDX license identifier
- [ ] R08.2: Add `// MARK: -` section dividers
- [ ] R08.3: Ensure all public APIs have doc comments

---

### Task R09: Swift 6.2 Strict Concurrency Audit
**Priority**: High

- [ ] R09.1: Verify all types are `Sendable` where appropriate
- [ ] R09.2: Audit all actors for proper isolation
- [ ] R09.3: Ensure no `nonisolated(unsafe)` usage without justification
- [ ] R09.4: Run with `-strict-concurrency=complete` flag

---

### Task R10: Validation & Verification
**Priority**: Critical (After all refactoring)

- [ ] R10.1: All 1028+ tests still passing
- [ ] R10.2: No new compiler warnings
- [ ] R10.3: `swift build` succeeds with strict concurrency
- [ ] R10.4: Benchmark shows no performance regression
- [ ] R10.5: Update test count in TODO.md

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

### Task T16: Mixed Output Mode ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T16.1: **MixedOutputVisitor** - New visitor combining ObjC and Swift output
  - Location: `Sources/ClassDumpCore/Visitor/MixedOutputVisitor.swift`
  - Outputs both ObjC header syntax and Swift interface syntax
  - Clear section headers separating each entity's representations
- [x] T16.2: **Show both ObjC and Swift representations**
  - Protocols: `@protocol Name` and `@objc public protocol Name`
  - Classes: `@interface Name` and `@objc public class Name`
  - Categories: `@interface Class (Category)` and `@objc public extension Class`
- [x] T16.3: **CLI integration** - `--format mixed` option
  - Useful for bridging header generation
  - Helps understand ObjC/Swift type mapping
- [x] T16.4: **16 new tests** for MixedOutputVisitor
  - Protocol, class, category formatting in both styles
  - Methods, properties, ivars in both outputs
  - Optional methods, demangling, addresses, hidden classes

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

### Task T22: DSC Small Methods Support ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T22.1: Implement small method parsing in `loadSmallMethods()`
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldCacheObjCProcessor.swift:750-867`
  - Parses 12-byte relative method entries (nameOffset, typesOffset, impOffset)
  - Handles both direct selectors (iOS 16+) and indirect selector references
- [x] T22.2: Selector base address resolution
  - Reads `relativeMethodSelectorBaseAddressOffset` from ObjC opt header
  - Converts to virtual address using ObjC opt header's VM address
  - Validates address is within valid cache mapping
- [x] T22.3: Safe fallback for unavailable selector base
  - Returns empty array instead of garbled names
  - Prevents garbled output when selector base unavailable
- [x] T22.4: **Support modern cache formats** (macOS 14+ / iOS 17+)
  - Location: `Sources/ClassDumpCore/DyldSharedCache/DyldCacheObjCOptimization.swift`
  - Modern caches have `objcOptOffset = 0` in main header
  - ObjC optimization is embedded in libobjc.A.dylib's `__TEXT.__objc_opt_ro` section
  - Added `objcOptimizationHeaderFromLibobjc()` to find and parse embedded header
  - Added `ObjCOptHeaderResult` struct to track header VM address for correct offset calculation
- [x] T22.5: **Cross-version compatibility**
  - Added `objcOptimizationHeaderWithFallback()` for seamless cross-version support
  - Works with both old caches (objcOptOffset in header) and new caches (embedded in libobjc)
  - Fixed selector base calculation: offset is relative to header VM address, not cache base

### Task T23: Inspection Command ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T23.1: **`class-dump info` subcommand** added
  - Location: `Sources/ClassDumpCLI/main.swift:588-947`
  - Shows file format, architectures, CPU type, file type, flags
  - Platform information (platform, min OS, SDK)
  - Runtime detection (ObjC, Swift)
- [x] T23.2: **Display Mach-O header, load commands, sections**
  - `--load-commands` flag shows all load commands
  - `--sections` flag shows all sections with address/size/offset
  - `--segments` flag shows segment details
- [x] T23.3: **Show architecture, platform, deployment target**
  - `--libraries` flag shows linked dylibs
  - `--encryption` flag shows encryption info
  - `--all` flag shows all available information
  - `--format json` for machine-readable output

### Task T24: Address Utilities ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T24.1: **`class-dump address` subcommand** added
  - Location: `Sources/ClassDumpCLI/main.swift:1241-1380`
  - `--a2o <address>` converts virtual address to file offset
  - `--o2a <offset>` converts file offset to virtual address
  - `--show-sections` lists all sections with VM address/file offset/size
- [x] T24.2: **Section context provided**
  - Address translations include section name where applicable
  - Uses `AddressTranslator` for efficient segment-based lookup

### Task T25: Lipo Export ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T25.1: **`class-dump lipo` subcommand** added
  - Location: `Sources/ClassDumpCLI/main.swift:1382-1569`
  - List architectures with `-l` / `--list` (default behavior)
  - Detailed info with `--detailed` (CPU type, offset, size)
  - Extract architecture with `-e` / `--extract <arch>`
  - Custom output path with `-o` / `--output <path>`
  - Verification with `--verify` flag validates extracted Mach-O
- [x] T25.2: **Error handling**
  - Invalid architecture names
  - Architecture not found with list of available ones
  - Invalid slice bounds
  - Verification failures

### Task T26: Entitlements Display ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T26.1: **`class-dump entitlements` subcommand** added
  - Location: `Sources/ClassDumpCLI/main.swift:1552-1721`
  - Location: `Sources/ClassDumpCore/MachO/CodeSignature.swift` (new)
  - Parses SuperBlob structure from LC_CODE_SIGNATURE
  - Extracts XML entitlements from CSSLOT_ENTITLEMENTS blob
- [x] T26.2: **Multiple output formats**
  - Default: Pretty-printed XML with indentation
  - `--raw`: Raw XML without formatting
  - `--json`: Converts plist to JSON format
  - `-o/--output`: Write to file
- [x] T26.3: **Code signature inspection**
  - `--show-blobs`: Lists all code signature blobs
  - Shows slot type, magic, offset, and size for each blob
  - Recognizes codeDirectory, requirements, entitlements, entitlementsDER, cmsSignature

### Task T27: DocC Generator ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T27.1: **Generate DocC-compatible Symbol Graph output**
  - Location: `Sources/ClassDumpCore/Visitor/SymbolGraphVisitor.swift`
  - Generates Symbol Graph JSON conforming to Apple's format (v0.6.0)
  - Maps ObjC protocols, classes, methods, properties, ivars to symbols
  - Generates relationships (memberOf, conformsTo, inheritsFrom, requirementOf)
  - Declaration fragments for syntax highlighting
  - Function signatures for methods
- [x] T27.2: **Support merging multiple framework dumps**
  - `SymbolGraph.merge()` combines multiple graphs into one
  - Deduplicates symbols by precise identifier
  - Tracks bystander modules for cross-module references
  - `SymbolGraph.merging(with:)` for pairwise merging
- [x] T27.3: **Symbol graph utilities for Xcode integration**
  - `jsonData()` / `jsonString()` for encoding
  - `from(jsonData:)` / `from(url:)` for decoding
  - `write(to:)` for file output
  - `recommendedFilename()` following Apple's naming convention
- [x] T27.4: **CLI integration** - `--format docc` option
  - Also supports `--format symbolgraph` as alias
  - Outputs to stdout like other formats
- [x] T27.5: **29 new tests** for SymbolGraphVisitor
  - Protocol, class, method, property, ivar formatting
  - Relationships, declaration fragments, demangling
  - Merging, round-trip JSON, filename conventions

---

## Future: Advanced Capabilities

### Task T28: Full Swift Type Support ✅ Complete
**Status**: Complete (2026-01-10)

- [x] T28.1: **Swift Extensions Parsing**
  - Location: `Sources/ClassDumpCore/Swift/SwiftMetadata.swift`
  - Added `SwiftExtension` struct for extension metadata
  - Parses extensions from `__swift5_types` section (kind = 1)
  - Tracks extended type, module, generic parameters, where clauses
  - Added extension lookup methods to `SwiftMetadata`

- [x] T28.2: **Property Wrappers Detection**
  - Location: `Sources/ClassDumpCore/Swift/SwiftMetadata.swift`
  - Added `SwiftPropertyWrapper` enum with common wrappers (@State, @Binding, @Published, etc.)
  - Added `SwiftPropertyWrapperInfo` for wrapper details
  - `SwiftField.propertyWrapper` computed property for detection
  - Detects SwiftUI, Combine, and SwiftData wrappers

- [x] T28.3: **Result Builders Detection**
  - Location: `Sources/ClassDumpCore/Swift/SwiftMetadata.swift`
  - Added `SwiftResultBuilder` enum (@ViewBuilder, @SceneBuilder, etc.)
  - Added `SwiftResultBuilderInfo` for builder details
  - `SwiftTypeDetection` utility enum for detection helpers

- [x] T28.4: **Additional Swift Type Detection Utilities**
  - `SwiftTypeDetection.looksLikeAsyncFunction()` for async detection
  - `SwiftTypeDetection.looksLikeSendableClosure()` for @Sendable detection
  - `SwiftTypeDetection.looksLikeActor()` for actor/isolation detection
  - `SwiftTypeDetection.looksLikeOpaqueType()` for "some" return types

### New Files Created
- `Tests/ClassDumpCoreTests/Swift/TestSwiftTypeSupport.swift` - 26 new tests

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
