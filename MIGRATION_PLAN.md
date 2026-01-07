# Swift 6.2 Migration Plan for class-dump

## Goals
- Convert all Obj-C code to Swift 6.2 with strict concurrency
- Improve performance (parallel parsing, memory mapping)
- Modernize build system and testing
- Preserve behavior and pass tests

## Current State Snapshot
- Targets: class-dump, deprotect, formatType, MachObjC, UnitTests
- Code: Obj-C + C, PCH, Foundation/Cocoa, no Swift
- Tests: Obj-C XCTest in UnitTests

## Migration Strategy (High Level)
1. Keep current Obj-C as baseline; move tests to Swift first.
2. Introduce Swift core module and migrate low-level parsing -> higher layers.
3. Incrementally replace CLI entry points.
4. Enable strict concurrency, parallel processing, and performance improvements.

## Detailed Steps (each step = one commit)
[x] 01 Add migration plan doc (this file) and branch notes
[x] 02 Add Swift test scaffolding (bridging header, Swift version, test helpers)
[x] 03 Convert CPU arch naming tests to Swift (CDArchFromName/CDNameForCPUType/CDArchUses64BitABI)
[x] 04 Convert fat/thin file selection tests to Swift (CDFatFile/CDMachOFile)
[ ] 05 Convert block signature tests to Swift (CDType private API exposure)
[ ] 06 Remove Obj-C UnitTests sources from target once Swift equivalents exist
[ ] 07 Define Swift module layout for core + CLIs (Xcode targets or SPM), add shared Swift support
[ ] 08 Migrate byte parsing utilities (CDDataCursor, CDMachOFileDataCursor, ULEB128, byte order) to Swift structs
[ ] 09 Migrate Mach-O model types (CDFile, CDFatFile, CDFatArch, CDMachOFile) to Swift, keep Obj-C shims
[ ] 10 Migrate load command types (CDLC*), sections, symbols, relocation parsing
[ ] 11 Migrate Objective-C metadata parsing (CDObjectiveC1/2Processor, CDOC* types)
[ ] 12 Migrate type system and formatting (CDType*, formatter, lexer, parser)
[ ] 13 Migrate visitor pipeline + output formatting (CDVisitor, CDClassDumpVisitor, CDTextClassDumpVisitor, etc.)
[ ] 14 Migrate CLI entry points (class-dump, deprotect, formatType, MachObjC) to Swift async main
[ ] 15 Concurrency + performance pass (TaskGroup parsing, parallel file scanning, caching, memory mapping)
[ ] 16 Modernization pass (Swift 6.2 strict concurrency flags, Sendable annotations, Logger, URL APIs)
[ ] 17 Remove Obj-C sources, PCH, and deprecated build settings; clean project
[ ] 18 Final verification (tests, performance checks, docs update)

## Concurrency and Performance Targets
- Parallel parsing of independent Mach-O files (TaskGroup)
- Concurrent processing of load commands/segments where safe
- Memory-mapped file IO for large binaries
- Avoid repeated parsing via caching of tables and strings
- Replace NSMutableArray with Swift arrays and reserveCapacity

## Modernity Adaptations Needed
- Swift 6.2 strict concurrency with Sendable and actors
- Replace getopt with ArgumentParser (optional) or Swift CLI parser
- Replace NS* legacy APIs with modern Foundation/URL/Logger
- Remove PCH and global macros; use Swift configs
- SPM package layout for core library + executables (optional but recommended)

## Progress Log
- 2026-01-07: created plan, branch swift6-migration
- 2026-01-07: added Swift test scaffolding (bridging header, Swift version)
- 2026-01-07: converted CPU arch naming/ABI tests to Swift
- 2026-01-07: converted fat/thin file selection tests to Swift
