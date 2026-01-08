# Swift 6.2 Migration Plan for class-dump

## Goals
- Convert all Obj-C code to Swift 6.2 with strict concurrency
- Improve performance (parallel parsing, memory mapping)
- Modernize build system and testing
- Preserve behavior and pass tests

## Current State Snapshot
- Targets: class-dump, deprotect, formatType, MachObjC, UnitTests
- Code: Obj-C + C, PCH, Foundation/Cocoa, plus Swift tests and SPM skeleton
- Tests: Swift XCTest in UnitTests target (not yet in SPM)

## Migration Strategy (High Level)
1. Keep current Obj-C as baseline; move tests to Swift first.
2. Introduce Swift core module and migrate low-level parsing -> higher layers.
3. Incrementally replace CLI entry points.
4. Make SPM the primary build, move tests into SPM, then retire Xcode project.
5. Enable strict concurrency, parallel processing, and performance improvements.

## Detailed Steps (each step = one commit)
[x] 01 Add migration plan doc (this file) and branch notes
[x] 02 Add Swift test scaffolding (bridging header, Swift version, test helpers)
[x] 03 Convert CPU arch naming tests to Swift (CDArchFromName/CDNameForCPUType/CDArchUses64BitABI)
[x] 04 Convert fat/thin file selection tests to Swift (CDFatFile/CDMachOFile)
[x] 05 Convert block signature tests to Swift (CDType private API exposure)
[x] 06 Remove Obj-C UnitTests sources from target once Swift equivalents exist
[x] 07 Define Swift module layout for core + CLIs (Xcode targets or SPM), add shared Swift support
[x] 08 Update Swift tools version to 6.2 in Package.swift
[x] 09 Move tests to SPM (Tests/ClassDumpCoreTests, etc.) and make `swift test` the primary runner
[x] 10 Add ARM64e/current ARM subtype parsing and tests (CDArchFromName/CDNameForCPUType)
[x] 11 Migrate byte parsing utilities (DataCursor, MachOFileDataCursor, ByteOrder) to Swift structs
[x] 12 Migrate Mach-O model types (MachOFile, FatFile, MachOHeader, Arch) to Swift
[x] 13 Migrate load command types (LoadCommand, SegmentCommand, etc.), sections, symbols
[x] 14 Migrate Objective-C metadata parsing (ObjC2Processor, runtime structs, chained fixups, small methods)
[x] 15 Migrate type system and formatting (ObjCType, ObjCTypeParser, ObjCTypeLexer, ObjCTypeFormatter)
[x] 16 Migrate visitor pipeline + output formatting (TextClassDumpVisitor, ClassDumpHeaderVisitor, etc.)
[x] 17 Migrate class-dump CLI to Swift with ArgumentParser
[x] 17b Implement deprotect CLI in Swift
[x] 17c Implement formatType CLI in Swift
[x] 17d Full CLI feature parity (-a, -A, -f, -H, -o, -t, --list-arches, --hide, --sdk-*, sorting)
[ ] 18 Concurrency + performance pass (TaskGroup parsing, parallel file scanning, caching, memory mapping)
[x] 19 Modernization pass (Swift 6.2 strict concurrency audit, Sendable annotations, deprecated API migration)
[x] 20 Remove Obj-C sources, PCH, deprecated build settings; retire Xcode project
[x] 21 Final verification (tests, performance checks, docs update)

## Phase 2: Swift Testing & Enhanced Features

[x] 22 Migrate all tests from XCTest to Swift Testing (@Test, @Suite, #expect)
[ ] 23 Add Swift name demangling support (swift_demangle API or custom demangler)
[ ] 24 Add Swift metadata parsing (Swift reflection metadata, type descriptors, witness tables)
[ ] 25 Investigate native Apple frameworks for lexer/parser (SwiftSyntax, swift-format infrastructure)
[ ] 26 Performance optimization pass (zero-copy parsing, memory mapping, extreme parallelism)
    - Reference: g-cqd/SwiftStaticAnalysis patterns
    - Memory-mapped Data with no intermediate copies
    - Parallel segment/section processing with TaskGroup
    - Lock-free concurrent caches
    - SIMD-accelerated string scanning where applicable
[ ] 27 Create DocC generator from class-dump output
    - Generate DocC-compatible documentation from dumped headers
    - Support merging multiple framework dumps into unified documentation
    - Symbol graph generation for integration with Xcode documentation

## Phase 3: Modern Mach-O Support (iOS 14+ Compatibility)

[x] 28 Parse `LC_DYLD_CHAINED_FIXUPS` load command
    - Implemented ChainedFixups.swift with full header and import table parsing
    - Handle DYLD_CHAINED_PTR_64, DYLD_CHAINED_PTR_ARM64E, ARM64E_USERLAND24 formats
    - Reference: ipsw's `m.DyldChainedFixups()` in go-macho
[x] 29 Resolve chained binds to external symbols
    - Map bind ordinals to imported symbol names via ChainedFixups.symbolName(forOrdinal:)
    - Update superclass resolution to use fixup chains (strips OBJC_CLASS_$_ prefix)
    - Update category class reference resolution similarly
[x] 30 Handle chained rebases for internal pointers
    - decodePointer() method handles both rebases (extracting target address) and binds
    - Supports multiple pointer formats: ARM64E, ARM64E_USERLAND24, PTR64, PTR32

## Phase 4: Swift Metadata Support

[x] 31 Detect Swift binaries
    - Check for `__swift5_*` sections in __TEXT segment
    - Implemented `hasSwiftMetadata` property on MachOFile
    - Created SwiftMetadataProcessor for parsing Swift sections
[x] 32 Parse Swift type descriptors
    - Created SwiftMetadata.swift with type definitions
    - Parse `__swift5_types` section to extract type descriptors
    - Parse `__swift5_fieldmd` section for field descriptors
    - SwiftSymbolicResolver for resolving symbolic type references
    - 72% resolution rate on real binaries (65/90 references)
[~] 33 Parse Swift protocol descriptors (partial)
    - Parse `__swift5_protos` section for protocol names
    - Full protocol requirements need more work
[~] 34 Parse protocol conformances (partial)
    - Parse `__swift5_proto` section for conformance records
    - Type-to-protocol mapping extracted
[ ] 35 Generate Swift-style headers
    - Format Swift types as `.swiftinterface`-like output
    - Handle generics, property wrappers, result builders
[~] 36 Integrate Swift types with ObjC output (partial)
    - Field descriptor lookup by class name
    - Need to link field descriptors to ObjC classes via address matching

### Swift Support Notes
- Swift ivar types now show `Swift.AnyObject` when type resolution not available (was `/* Swift */`)
- Eliminated `/* symbolic ref */` markers - now shows mangled name
- SwiftDemangler provides class name demangling from ObjC format
- SwiftSymbolicResolver resolves direct context references (0x01)
- Indirect references (0x02) partially resolved - need GOT handling
- Field descriptor to ObjC class matching improved for nested classes
- Added support for nested class demangling (`_TtCC` prefix)

### Immediate Priority: Swift Demangling Refactoring (COMPLETED)
Completed 2026-01-08:

[x] Unify demangling methods into cohesive implementation
    - Refactored SwiftDemangler with clear entry points documented in header
    - Created focused helper sections: Type Lookup Tables, Detailed Demangling,
      ObjC Class Name Parsing, ObjC Import Demangling, Swift 5+ Symbol Demangling,
      Qualified Type Parsing, Word Substitution Helpers, Primitive Parsing Helpers
    - Five public entry points: `demangle()`, `demangleClassName()`,
      `demangleNestedClassName()`, `extractTypeName()`, `demangleComplexType()`
[x] Add comprehensive tests for SwiftDemangler (43 tests in 14 suites)
    - Standard library types: Array, Dictionary, Optional, Set, etc. (21 shortcuts)
    - Common patterns: Sb, Si, SS, etc. (6 two-char + 8 fixed-width ints)
    - Builtin types: 11 Builtin.* types tested
    - ObjC class names: Simple, long, generic, nested, old-style formats
    - Nested classes: _TtCC and _TtCCC prefixes with array extraction
    - Module-qualified types: Foundation.Date, UIKit types
    - ObjC imports: So prefix with dispatch types, Foundation types
    - Swift 5+ symbols: _$s and $s prefixed symbols
    - Word substitutions: 0A pattern handling
    - Private types: P33_ discriminator handling
    - Generic types: Optional suffix, Array/Dictionary shorthands
    - Edge cases: Empty string, unknown input, symbolic references

## Phase 4.5: Cleanup & Stabilization (BLOCKING)

Before continuing to Phase 4 Task 35 or Phase 5, these issues must be resolved:

### P0 - Critical (Blocks Build/Tests)
- [x] Fix test compilation: `TestVisitor.swift` uses old `ObjCInstanceVariable` API
      - ✓ Already correct - uses `typeEncoding:` parameter with default for `typeString:`
- [x] Remove debug print statements from `ObjC2Processor.swift:400-415`
      - ✓ Already clean - no DEBUG: statements present in codebase

### P1 - High Priority (Correctness Issues)
- [x] Fix `chainedFixups` propagation inconsistency in `SwiftMetadataProcessor.swift`
      - ✓ Both methods now correctly pass chainedFixups to resolver (lines 113, 144)
- [x] Remove unused variable assignment in `SwiftSymbolicResolver.swift:218`
      - ✓ No such pattern exists in current code

### P2 - Medium Priority (Code Quality)
- [ ] Remove dead code: `SwiftSymbolicResolver.contextKindName(_:)` (lines 448-460)
- [ ] Document thread-safety requirements for processor classes
      - `ObjC2Processor` marked `@unchecked Sendable` but has mutable state
      - `SwiftSymbolicResolver` and `SwiftMetadataProcessor` have unsynchronized caches
- [ ] Consider extracting `ObjC2Processor.init` logic (80+ lines) to separate method

### Code Review Findings (2026-01-08)
Issues identified during comprehensive code review:
- **Thread Safety**: All three processor classes have mutable caches without synchronization
- **Error Handling**: Uses magic strings (`"/* unknown type */"`) instead of typed errors
- **Magic Numbers**: Hardcoded struct offsets without named constants
- **Lazy Property Risk**: `symbolicResolver` lazy var in `ObjC2Processor` not thread-safe

## Phase 4.7: Enhanced Swift & ObjC Demangling

### Current State (as of 2026-01-08)
Output still contains many mangled names that should be human-readable.

**Example of current output:**
```objc
@interface _TtC13IDEFoundation37IDETestableTreeItemConsolidatedSource : _TtCs12_SwiftObject
{
    Dictionary<SSIDEFoundation.IDETestableTreeItemSource> treeItemSourceStore;
    ScTyytNeverG? observationStreamTask;
    ScS12ContinuationVMn sourceStreamProcessingStreamContinuation;
    [IDEFoundation.IDETestableTreeItem] children;
    Combine.AnyCancellable testableChangedSubscription;
}
```

**What works:**
- Some generic ivar types are partially resolved (e.g., `Dictionary<...>`, `[...]`)
- Module-qualified types in some contexts (e.g., `IDEFoundation.IDETestableTreeItem`)
- `Combine.AnyCancellable` shows correctly

**What still needs work:**
- Class names in `@interface`: `_TtC13IDEFoundation37...` → `IDEFoundation.IDETestableTreeItemConsolidatedSource`
- Superclass names: `_TtCs12_SwiftObject` → `Swift._SwiftObject`
- Protocol names: `_TtP15XCSourceControl30XCSourceControlXPCBaseProtocol_` → readable
- Generic key types: `SS` in `Dictionary<SS...>` → `String`
- Concurrency types: `ScTyytNeverG?` → `Task<Void, Never>?`
- Continuation types: `ScS12ContinuationVMn` → `CheckedContinuation<...>` or similar
- Complex nested generics still partially mangled

### Task 40: Demangle Swift Class Names in Output
[x] 40.1 Apply demangling to class/protocol names in visitor output (COMPLETED 2026-01-08)
    - ✓ Updated `TextClassDumpVisitor` to use `SwiftDemangler.demangleSwiftName()`
    - ✓ Class names, superclass names, and protocol names all demangled
    - ✓ Categories demangle their class reference names
    - ✓ Added `demangleSwiftName()` as unified entry point for output formatting
    - ✓ Added `demangleProtocolName()` for `_TtP..._` protocol format
    - ✓ Handles nested classes: `_TtCC...` → `Module.Outer.Inner`
    - ✓ Handles private types: `P33_<hash>` → `Module.(private).TypeName`
    - ✓ Handles stdlib types: `_TtCs12_SwiftObject` → `_SwiftObject`
    - ✓ Handles enums (_TtO) and structs (_TtV)
    - ✓ Updated `ObjCTypeFormatter` to demangle class names in property/ivar types
    - ✓ Property types now show `IDEFoundation.IDEBuildableReference *` instead of mangled form
    - ✓ 13 new tests added (337 total tests passing)

[ ] 40.2 Create `ObjCSwiftBridge` helper for consistent name translation
    - Centralize `_TtC` → `Module.ClassName` translation
    - Centralize `_TtP` → `Module.ProtocolName` translation
    - Handle private type discriminators (`P33_...`)
    - Map common framework types to readable names

[ ] 40.3 Add CLI option for demangling control
    - `--demangle` / `--no-demangle` flag (default: demangle)
    - `--demangle-style=swift` for `Module.Type` format
    - `--demangle-style=objc` for `Type` only (drop module)

### Task 41: Demangle Swift Protocol Names
[ ] 41.1 Parse `_TtP` protocol name format
    - Format: `_TtP<module_len><module><name_len><name>_`
    - Trailing underscore marks end of protocol name
    - Handle nested protocols if applicable

[ ] 41.2 Demangle protocol conformance lists
    - In `@interface Class : Super <Proto1, Proto2>`, demangle protocol names
    - In `@protocol Proto <ParentProto>`, demangle parent protocols
    - Handle multiple protocol inheritance

[ ] 41.3 Add tests for protocol demangling
    - Simple protocols: `_TtP10Foundation8Hashable_`
    - Module-qualified: `_TtP15XCSourceControl30XCSourceControlXPCBaseProtocol_`
    - Nested/composed protocols

### Task 42: Swift Concurrency Type Demangling
[ ] 42.1 Parse Task types (`ScT` patterns)
    - `ScTyytNeverG` → `Task<Void, Never>`
    - `ScTySSErrorG` → `Task<String, Error>`
    - Handle generic success/failure type parameters
    - Handle optional Task types (`ScTyytNeverG?` → `Task<Void, Never>?`)

[ ] 42.2 Parse Continuation types (`ScS` patterns)
    - `ScS12ContinuationVMn` → `CheckedContinuation<...>`
    - `ScS17UnsafeContinuationVMn` → `UnsafeContinuation<...>`
    - Extract resume type from generic parameters
    - Handle throwing vs non-throwing continuations

[ ] 42.3 Parse Actor types and isolation
    - `ScA` actor markers
    - `@MainActor`, `@globalActor` attributes
    - Actor-isolated type references

[ ] 42.4 Parse AsyncStream/AsyncSequence types
    - `Sc*Stream` patterns
    - `AsyncThrowingStream`, `AsyncStream`
    - Element type extraction

### Task 43: Enhanced Generic Type Demangling
[ ] 43.1 Parse generic type parameters in full
    - `_TtGC10ModuleName7GenericSS_` → `ModuleName.Generic<String>`
    - Handle multiple type parameters
    - Handle nested generics: `Array<Dictionary<String, Int>>`
    - Fix `Dictionary<SS...>` → `Dictionary<String, ...>`

[ ] 43.2 Implement generic constraint parsing
    - Parse `where` clause equivalents in mangling
    - Handle associated type constraints
    - Handle protocol conformance constraints

[ ] 43.3 Format generic types in property/ivar declarations
    - Show `Array<String>` instead of mangled form
    - Handle Optional (`?` suffix vs `Optional<T>`)
    - Handle Result, Either, and other stdlib generics

[ ] 43.4 Handle deeply nested generic types
    - `Dictionary<String, Array<Set<Int>>>` style nesting
    - Proper bracket matching and formatting
    - Limit recursion depth for safety

### Task 44: Swift Type Descriptor Integration
[ ] 44.1 Use `__swift5_types` to resolve type metadata
    - Link type descriptors to ObjC class metadata by address
    - Extract full generic signature from descriptors
    - Handle value types (struct/enum) as well as classes

[ ] 44.2 Parse nominal type descriptors for complete type info
    - Access control (public/internal/private)
    - Generic parameters with constraints
    - Parent type for nested types

[ ] 44.3 Use `__swift5_fieldmd` for property type resolution
    - Match field descriptors to class ivars by name
    - Resolve field types using symbolic references
    - Handle @objc properties specially

### Task 45: Function/Method Signature Demangling
[ ] 45.1 Parse Swift method signatures
    - Format: `_$s...F...` for function symbols
    - Extract parameter types and return type
    - Handle throwing functions, async functions

[ ] 45.2 Demangle closure types
    - `@convention(block)` closures
    - Escaping vs non-escaping
    - Sendable closures

[ ] 45.3 Format method signatures in output
    - Show Swift-style: `func name(label: Type) -> ReturnType`
    - Or ObjC-style with Swift types: `- (ReturnType)nameWithLabel:(Type)param`

### Task 46: ObjC Type Encoding Enhancements
[ ] 46.1 Complete ObjC type encoding coverage
    - Audit all ObjC type encoding characters
    - Handle complex struct encodings with nested types
    - Handle union types
    - Handle vector/SIMD types

[ ] 46.2 Resolve forward-declared types
    - When type shows as `struct CGRect` but actual type available
    - Use runtime metadata to resolve typedefs
    - Handle `@class` forward declarations

[ ] 46.3 Improve block type formatting (eliminate CDUnknownBlockType)
    - Parse block signature from type encoding (`@?<v@?@>` → `void (^)(id)`)
    - Extract return type and parameter types from block encoding
    - Show `void (^)(id, NSError *)` instead of `CDUnknownBlockType`
    - Handle completion handlers: `(void (^)(BOOL success, NSError *error))`
    - Handle blocks with block parameters (nested blocks)
    - Fall back to `void (^)(/* unknown */)` rather than `CDUnknownBlockType`

[ ] 46.4 Audit and fix CDUnknownBlockType occurrences
    - Current cause: `ObjCTypeParser` returns `.block(types: nil)` when no `<...>` signature
    - Method encodings often lack block signatures (only `@?` not `@?<v@?>`)
    - Extended type encodings (protocols) DO include signatures - leverage these
    - Options to fix:
      1. Cross-reference with protocol method signatures for same selector
      2. Parse Swift metadata for closure signatures
      3. At minimum show `id /* block */` instead of `CDUnknownBlockType`
    - Add logging/debugging mode to show raw type encoding
    - Create test cases from real-world block signatures
    - Handle Swift closure types bridged to ObjC blocks

### Task 47: System Library Integration
[ ] 47.1 Use `swift-demangle` when available
    - Shell out to `/usr/bin/swift-demangle` for complex cases
    - Cache results for repeated symbols
    - Fall back to built-in demangler if unavailable

[ ] 47.2 Optionally link libswiftDemangle
    - `dlopen` the Swift runtime library
    - Use `swift_demangle` C API for full accuracy
    - Handle symbol versioning across Swift versions

[ ] 47.3 Create demangling cache for performance
    - LRU cache for demangled names
    - Persist cache across runs (optional)
    - Thread-safe implementation

### Task 48: Output Format Options
[ ] 48.1 Add `--swift` output mode
    - Output `.swiftinterface`-style declarations
    - Format: `public class Name: SuperClass, Protocol { ... }`
    - Include access control, attributes

[ ] 48.2 Add `--mixed` output mode
    - Show both ObjC and Swift representations
    - ObjC `@interface` followed by Swift `class` declaration
    - Useful for bridging header generation

[ ] 48.3 Add `--json` structured output
    - Machine-readable type information
    - Include both mangled and demangled names
    - Include source locations, offsets

### Demangling Test Matrix
Ensure comprehensive test coverage for:
- [ ] Swift classes: `_TtC`, `_TtCC`, `_TtCCC` (nested)
- [ ] Swift structs: `_TtV`, `_TtVV` (nested)
- [ ] Swift enums: `_TtO`, `_TtOO` (nested)
- [ ] Swift protocols: `_TtP..._`
- [ ] Swift generics: `_TtGC...`, `_TtGV...`
- [ ] Swift 5+ symbols: `_$s...`, `$s...`
- [ ] Private types: `P33_<32-hex-chars>`
- [ ] Module substitutions: `So` (ObjC), `s` (Swift), `SC` (Clang)
- [ ] Word substitutions: `0A`, `0B`, etc.
- [ ] Standard library types: All 21 single-char shortcuts
- [ ] Builtin types: `B*` patterns
- [ ] Function types: Parameter lists, return types, throws, async
- [ ] Concurrency types:
  - [ ] `ScT` Task types with generic parameters
  - [ ] `ScS` Continuation types (CheckedContinuation, UnsafeContinuation)
  - [ ] `ScA` Actor types
  - [ ] `ScP` TaskPriority
  - [ ] `Scg` TaskGroup
  - [ ] AsyncStream, AsyncSequence patterns
- [ ] Complex generics:
  - [ ] `Dictionary<SS...>` → `Dictionary<String, ...>`
  - [ ] Nested generics with multiple levels
  - [ ] Optional generic parameters

## Phase 5: dyld_shared_cache Integration

[ ] 36 Shared Cache Foundation
    - Implement `MemoryMappedReader` for large file access (3+ GB files)
    - Parse `dyld_cache_header` (magic, mappings, images)
    - Support split caches (.01, .02, etc.) for modern iOS
    - Reference: ipsw's `dyld.Open()` in pkg/dyld
[ ] 37 Address Translation
    - Implement `SharedCacheAddressTranslator` for VM-to-offset logic
    - Parse `dyld_cache_slide_info` for pointer rebasing
    - Handle multiple cache mappings with different permissions
[ ] 38 In-Cache Image Analysis
    - List available images in the shared cache
    - Extract Mach-O data for specific image (zero-copy view)
    - Adapt `ObjC2Processor` to work with in-cache images
    - Handle DSC-specific ObjC optimizations (shared selector table)
[ ] 39 ObjC Optimization Tables (Optional)
    - Parse global class/selector/protocol tables for faster lookup
    - Reference: ipsw's `f.GetAllObjCClasses()` etc.

## Phase 6: Quality of Life Improvements

[ ] 40 JSON output option (`--json`)
    - Structured output for tooling integration
    - Include class hierarchy, methods, properties, protocols
[ ] 41 Inspection command (`class-dump info`)
    - Display Mach-O header, load commands, sections
    - Show architecture, platform, deployment target
    - Useful for debugging parsing failures
[ ] 42 Address utilities
    - Expose `a2o` / `o2a` conversion for debugging
    - Resolve addresses to symbol names for `-A` output
[ ] 43 Lipo export functionality
    - Extract single architecture to standalone file
    - Useful for processing fat binaries
[ ] 44 Entitlements display
    - Parse LC_CODE_SIGNATURE blob
    - Extract and display XML entitlements

## Phase 7: Advanced Capabilities

[ ] 45 Full Swift type support (generics, protocols, extensions, property wrappers)
[ ] 46 Recursive framework dependency resolution with caching
[ ] 47 Watch mode for incremental re-dumping on file changes
[ ] 48 LSP integration for IDE support
[ ] 49 Dylib extraction from shared cache
    - Reconstruct standalone Mach-O from cached image
    - Handle LINKEDIT reconstruction

## Performance Evaluation

Use this command to benchmark the tool against a real-world, complex Swift framework:

```bash
class-dump "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
```

This binary is ideal for testing because it:
- Contains extensive Swift metadata alongside ObjC classes
- Uses chained fixups (iOS 14+ format)
- Has complex generic types and protocol conformances
- Is large enough to reveal performance issues

## Concurrency and Performance Targets
- Parallel parsing of independent Mach-O files (TaskGroup)
- Concurrent processing of load commands/segments where safe
- Memory-mapped file IO for large binaries (required for DSC support)
- Avoid repeated parsing via caching of tables and strings
- Replace NSMutableArray with Swift arrays and reserveCapacity

## Reference Documentation
- **Feature Gap Analysis**: See `.plan/docs/FEATURE_GAP_ANALYSIS.md` for detailed comparison with ipsw/go-macho
- **Cutting-Edge Research**: See `.plan/docs/CUTTING_EDGE_RESEARCH.md` for latest binary format knowledge (2024-2025)
- **ipsw dyld commands**: https://github.com/blacktop/ipsw/tree/master/cmd/ipsw/cmd/dyld
- **ipsw macho commands**: https://github.com/blacktop/ipsw/tree/master/cmd/ipsw/cmd/macho
- **go-macho library**: https://github.com/blacktop/go-macho (reference implementation for Swift/DSC/fixups)
- **MachOKit (Swift)**: https://github.com/p-x9/MachOKit (Swift-native Mach-O parser with DSC support)
- **MachOSwiftSection**: https://github.com/MxIris-Reverse-Engineering/MachOSwiftSection (Swift metadata extraction)
- **Apple dyld source**: https://github.com/apple-oss-distributions/dyld
- **Apple objc4 source**: https://github.com/apple-oss-distributions/objc4

## Module Layout (Swift Package Skeleton)
- ClassDumpCore: shared parsing, modeling, and formatting logic
- ClassDumpCoreObjC: legacy ObjC/C core (SPM C target) re-exported by ClassDumpCore
- ClassDumpCLI: class-dump executable (Argument parsing + dispatch into ClassDumpCore)
- DeprotectCLI: deprotect executable (segment decrypt + file write)
- FormatTypeCLI: formatType executable (type format inspection)

## Modernity Adaptations Needed
- Swift 6.2 strict concurrency with Sendable and actors
- Replace getopt with ArgumentParser (optional) or Swift CLI parser
- Replace NS* legacy APIs with modern Foundation/URL/Logger
- Remove PCH and global macros; use Swift configs
- SPM package layout for core library + executables (required); remove Xcode project once SPM builds all targets/tests

## Progress Log
- 2026-01-07: created plan, branch swift6-migration
- 2026-01-07: added Swift test scaffolding (bridging header, Swift version)
- 2026-01-07: converted CPU arch naming/ABI tests to Swift
- 2026-01-07: converted fat/thin file selection tests to Swift
- 2026-01-07: converted block signature tests to Swift
- 2026-01-07: removed Obj-C UnitTests sources from the project
- 2026-01-07: added Swift package skeleton and module layout for core + CLIs
- 2026-01-07: set Swift tools version to 6.2 and adjusted SPM migration steps
- 2026-01-07: verified arm64e mapping via tests (no code change required)
- 2026-01-07: moved Swift tests into SPM and made `swift test` the primary runner (ObjC core split into ClassDumpCoreObjC)
- 2026-01-08: implemented full Swift 6 core - DataCursor, MachO types, load commands, ObjC2Processor with chained fixups and small methods, type system (parser/lexer/formatter), visitor pipeline, class-dump CLI with ArgumentParser. 265 tests passing. Pushed to fork.
- 2026-01-08: implemented deprotect and formatType CLIs in Swift with full functionality
- 2026-01-08: modernization pass - added built-in arch tables to avoid deprecated NXGetArchInfo* APIs for common architectures (i386, x86_64, armv6/7/7s, arm64/e)
- 2026-01-08: full CLI feature parity - added -a (ivar offsets), -A (method addresses), -f (find method), -H/-o (multi-file headers), -t (suppress header), --list-arches, --hide, --sdk-*, sorting flags. All 224 tests passing.
- 2026-01-08: implemented comprehensive LC_DYLD_CHAINED_FIXUPS support (Phase 3, tasks 28-30):
    - Created ChainedFixups.swift with full parsing of header, import table, and pointer formats
    - Added ObjC2Processor convenience init from MachOFile that auto-parses chained fixups
    - Updated superclass and category class resolution to use bind symbol names
    - External classes (like NSObject) now properly resolved via chained bind ordinals
    - Added MachOFile.hasChainedFixups and parseChainedFixups() API
    - Updated tests to verify chained fixups parsing and external superclass resolution. All 277 tests passing.
- 2026-01-08: implemented Swift metadata support foundation (Phase 4, tasks 31-34 partial):
    - Created Swift/ module with SwiftMetadata.swift, SwiftDemangler.swift, SwiftMetadataProcessor.swift
    - Parse __swift5_types, __swift5_fieldmd, __swift5_protos, __swift5_proto sections
    - Added MachOFile.hasSwiftMetadata and parseSwiftMetadata() API
    - Integrated Swift metadata with ObjC2Processor for ivar type resolution
    - Swift ivars now display `/* Swift */` instead of empty `/* */`
    - Added SwiftDemangler for basic type name demangling
    - Note: Full Swift type resolution requires symbolic reference resolution (future work)
    - Added 3 new Swift metadata tests. All 280 tests passing.
- 2026-01-08: implemented Swift symbolic reference resolution (Phase 4, task 32 completion):
    - Created SwiftSymbolicResolver.swift for resolving symbolic type references
    - Handle direct context references (0x01 prefix) - read type descriptor and extract name
    - Handle indirect context references (0x02 prefix) - dereference GOT-like pointers
    - Store raw bytes for field type data (symbolic refs contain nulls in offset bytes)
    - SwiftFieldRecord now has mangledTypeData and hasSymbolicReference properties
    - Achieved 72% resolution rate (65/90 symbolic references resolved in test binary)
    - SwiftMetadataProcessor.resolveFieldTypeFromData() for raw data resolution
    - Added SwiftDemangler unit tests for class name demangling
    - Field descriptor to ObjC class mapping still needs improvement (class name matching)
    - All 284 tests passing.
- 2026-01-08: WIP - Swift type integration improvements (uncommitted):
    - Extended SwiftSymbolicResolver with ChainedFixups support for indirect refs
    - Added protocol requirements parsing (baseProtocol, method, initializer, getter, setter, etc.)
    - Separated ObjCInstanceVariable.typeEncoding from typeString for proper Swift type display
    - Extended SwiftDemangler to handle generic (_TtGC) and old-style (_Tt) class names
    - Improved field name matching with underscore/dollar prefix handling
    - **BLOCKING**: Test compilation broken due to API change, debug code present
- 2026-01-08: code review conducted - identified P0/P1/P2 issues documented in Phase 4.5
- 2026-01-08: Implemented Task 40.1 - Swift name demangling in output:
    - Added `demangleSwiftName()` unified entry point to SwiftDemangler
    - Added `demangleProtocolName()` for `_TtP..._` protocol names
    - Added private type handling (`P33_<hash>` discriminators)
    - Added enum (_TtO), struct (_TtV), and nested type handling
    - Updated TextClassDumpVisitor to demangle class/superclass/protocol names
    - Updated ObjCTypeFormatter to demangle class names in property types
    - Added 13 new tests (337 total tests passing)
    - Verified P0/P1 issues from Phase 4.5 were already resolved
