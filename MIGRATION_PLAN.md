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
[ ] 11 Migrate byte parsing utilities (CDDataCursor, CDMachOFileDataCursor, ULEB128, byte order) to Swift structs
[ ] 12 Migrate Mach-O model types (CDFile, CDFatFile, CDFatArch, CDMachOFile) to Swift, keep Obj-C shims
[ ] 13 Migrate load command types (CDLC*), sections, symbols, relocation parsing
[ ] 14 Migrate Objective-C metadata parsing (CDObjectiveC1/2Processor, CDOC* types)
[ ] 15 Migrate type system and formatting (CDType*, formatter, lexer, parser)
[ ] 16 Migrate visitor pipeline + output formatting (CDVisitor, CDClassDumpVisitor, CDTextClassDumpVisitor, etc.)
[ ] 17 Migrate CLI entry points (class-dump, deprotect, formatType, MachObjC) to Swift async main
[ ] 18 Concurrency + performance pass (TaskGroup parsing, parallel file scanning, caching, memory mapping)
[ ] 19 Modernization pass (Swift 6.2 strict concurrency flags, Sendable annotations, Logger, URL APIs)
[ ] 20 Remove Obj-C sources, PCH, deprecated build settings; retire Xcode project
[ ] 21 Final verification (tests, performance checks, docs update)

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
