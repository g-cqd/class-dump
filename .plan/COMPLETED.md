# class-dump - Completed Work

**840 tests passing** | Swift 6.2 | Version 4.0.3 | Full CLI feature parity

---

## Summary

| Phase | Status | Description |
|-------|--------|-------------|
| [Phase 1](completed/PHASE_1_CORE_MIGRATION.md) | ✅ Complete | Core Swift 6.2 migration |
| [Phase 2](completed/PHASE_2_SWIFT_TESTING.md) | ✅ Complete | Swift Testing framework migration |
| [Phase 3](completed/PHASE_3_MODERN_MACHO.md) | ✅ Complete | iOS 14+ chained fixups |
| [Phase 4](completed/PHASE_4_SWIFT_METADATA.md) | ✅ Complete | Swift metadata parsing (T02-T05) |
| [Phase 4.5](completed/PHASE_4_5_CLEANUP.md) | ✅ Complete | Code cleanup & stabilization |
| [Phase 4.7](completed/PHASE_4_7_DEMANGLING.md) | ✅ Complete | Swift demangling |
| Phase 5 | ✅ Complete | ObjC type encoding enhancement (T06) |
| Phase 6 | ✅ Complete | Test reorganization (T01) |

---

## Completed Tasks

| Task | Status | Description |
|------|--------|-------------|
| [T00](completed/T00_SWIFT_TYPE_RESOLUTION.md) | ✅ Complete | Swift type resolution regressions (34 tests) |
| [T07](completed/T07_SWIFT_STDLIB_DEMANGLING.md) | ✅ Complete | Swift stdlib type demangling (15 tests) |
| [T08](completed/T08_OUTPUT_MODE_CONSISTENCY.md) | ✅ Complete | Output mode consistency (14 tests) |
| [T09](completed/T09_FORWARD_DECLARATIONS.md) | ✅ Complete | Forward-declared types (24 tests) |
| [T10](completed/T10_BLOCK_TYPE_RESOLUTION.md) | ✅ Complete | Block type resolution (26 tests) |
| [T11](completed/T11_CONCURRENCY_PERFORMANCE.md) | ✅ Complete | Concurrency & performance (Phases 1-3) |

---

## Key Capabilities

### Core Features
- Full Mach-O parsing (fat/thin, all architectures)
- ObjC metadata extraction (classes, protocols, categories)
- iOS 14+ LC_DYLD_CHAINED_FIXUPS support
- Swift metadata parsing (`__swift5_*` sections)
- Comprehensive type encoding parsing and formatting
- 128-bit integer support (__int128, unsigned __int128)
- Actor-based thread-safe symbolic resolution

### Performance
- ~700% CPU utilization on multi-core systems
- ~0.94s for IDEFoundation.framework (74,493 lines)
- Parallel class/protocol loading with TaskGroup
- SIMD-accelerated string scanning
- O(1) Swift field descriptor lookups
- Type encoding parse cache

### Swift Demangling
- Class names: `_TtC...` → `Module.ClassName`
- Protocol names: `_TtP..._` → `Module.ProtocolName`
- Generic types: `_TtGC...` → `Module.Generic<T>`
- Generic constraints: `SHRzl` → `where T: Hashable`
- Concurrency types: Task, Actor, AsyncStream, Continuation
- Function signatures: async, throws, @Sendable, typed throws
- Closure types: @escaping, @convention(block/c), effects

### CLI Options
```
class-dump [file]
  --arch <arch>           Select architecture
  --list-arches           List architectures
  -a                      Show ivar offsets
  -A                      Show method addresses
  -s/-S/-I                Sort by name/methods/inheritance
  -C <regex>              Filter classes
  -f <string>             Find method
  -H                      Generate header files
  -o <dir>                Output directory
  -t                      Suppress header
  --hide <section>        Hide structures/protocols/all
  --demangle/--no-demangle
  --demangle-style=swift|objc
  --method-style=swift|objc
  --output-style=objc|swift
  --show-raw-types
  --sdk-ios/--sdk-mac/--sdk-root
```

---

## Module Layout

```
Sources/
├── ClassDumpCore/
│   ├── MachO/              # File parsing
│   ├── ObjCMetadata/       # Runtime metadata
│   ├── Swift/              # Swift metadata & demangling
│   ├── TypeSystem/         # Type encoding
│   ├── Utilities/          # Caches, address translation
│   └── Visitor/            # Output generation
├── ClassDumpCLI/           # class-dump executable
├── DeprotectCLI/           # deprotect executable
└── FormatTypeCLI/          # formatType executable

Tests/ClassDumpCoreTests/
├── Arch/                   # Architecture tests
├── Demangling/             # Swift demangling tests
├── MachO/                  # Mach-O parsing tests
├── ObjCMetadata/           # ObjC metadata tests
├── Performance/            # Benchmarks & concurrency tests
├── Swift/                  # Swift metadata tests
├── TypeSystem/             # Type encoding tests
└── Visitor/                # Output generation tests
                            # 840 tests across 161 suites
```

---

## Test Distribution

| Category | Tests | Suites |
|----------|-------|--------|
| Architecture | 15 | 3 |
| Demangling | 280+ | 40 |
| MachO Parsing | 60+ | 12 |
| ObjC Metadata | 90+ | 10 |
| Performance | 30+ | 5 |
| Swift Metadata | 110+ | 18 |
| Type System | 150+ | 25 |
| Visitor/Output | 100+ | 20 |
| **Total** | **840** | **161** |
