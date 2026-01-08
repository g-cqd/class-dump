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
- Swift ivar types show `/* Swift */` when type resolution not available
- SwiftDemangler provides class name demangling from ObjC format
- SwiftSymbolicResolver resolves direct context references (0x01)
- Indirect references (0x02) partially resolved - need GOT handling
- Field descriptor to ObjC class matching needs improvement

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
