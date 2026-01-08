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

## Phase 3: Advanced Capabilities

[ ] 28 Full Swift type support (generics, protocols, extensions, property wrappers)
[ ] 29 Recursive framework dependency resolution with caching
[ ] 30 Watch mode for incremental re-dumping on file changes
[ ] 31 LSP integration for IDE support

## Concurrency and Performance Targets
- Parallel parsing of independent Mach-O files (TaskGroup)
- Concurrent processing of load commands/segments where safe
- Memory-mapped file IO for large binaries
- Avoid repeated parsing via caching of tables and strings
- Replace NSMutableArray with Swift arrays and reserveCapacity

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
