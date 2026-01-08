# Swift 6.2 Migration - Remaining Work

## Next Up

### Phase 4.5 P2 - Code Quality (Medium Priority)
- [x] Remove dead code: `SwiftSymbolicResolver.contextKindName(_:)` - DONE
- [x] Document thread-safety requirements for processor classes - DONE
  - Added ## Thread Safety docs to ObjC2Processor, SwiftSymbolicResolver, SwiftMetadataProcessor
- [x] Consider extracting `ObjC2Processor.init` logic - REVIEWED
  - Current structure acceptable: logic is self-contained, well-commented, inherently complex

### Code Review Findings (2026-01-08)
Issues identified during comprehensive code review:
- ~~**Thread Safety**: All three processor classes have mutable caches without synchronization~~ - DOCUMENTED
- **Error Handling**: Uses magic strings (`"/* unknown type */"`) instead of typed errors
- **Magic Numbers**: Hardcoded struct offsets without named constants
- ~~**Lazy Property Risk**: `symbolicResolver` lazy var in `ObjC2Processor` not thread-safe~~ - DOCUMENTED

---

## Phase 4.7: Enhanced Swift & ObjC Demangling

### Task 40: Demangle Swift Class Names (40.2-40.3 remaining)
- [x] 40.2 Create `ObjCSwiftBridge` helper for consistent name translation - ALREADY EXISTS
  - SwiftDemangler already provides centralized demangling via `demangleSwiftName()`
  - `_TtC` → `Module.ClassName` via `demangleClassName()`
  - `_TtP` → `Module.ProtocolName` via `demangleProtocolName()`
  - Private types (`P33_...`) via `extractPrivateTypeName()`
  - Framework mappings via `objcToSwiftTypes` dictionary
- [x] 40.3 Add CLI option for demangling control - DONE
  - Added `--demangle` / `--no-demangle` flag (default: demangle)
  - Added `--demangle-style=swift` for `Module.Type` format
  - Added `--demangle-style=objc` for `Type` only (drop module)
  - Updated `ClassDumpVisitorOptions` with `demangleStyle` property
  - Updated `ObjCTypeFormatterOptions` with `demangleStyle` property
  - Both `TextClassDumpVisitor` and `ObjCTypeFormatter` now respect the setting

### Task 41: Demangle Swift Protocol Names - DONE
- [x] 41.1 Parse `_TtP` protocol name format - DONE
  - Format: `_TtP<module_len><module><name_len><name>_`
  - Implemented in `SwiftDemangler.demangleProtocolName()`
  - Trailing underscore marks end of protocol name
- [x] 41.2 Demangle protocol conformance lists - DONE
  - `TextClassDumpVisitor` demangles protocols in:
    - Class declarations (`@interface ... <Proto1, Proto2>`)
    - Protocol declarations (`@protocol Proto <ParentProto>`)
    - Category declarations
  - Respects `demangleStyle` option (`.swift`, `.objc`, `.none`)
- [x] 41.3 Add tests for protocol demangling - DONE
  - Unit tests in `TestSwiftDemangler.swift` (ProtocolDemanglingTests suite)
  - Integration tests in `TestVisitor.swift`:
    - Swift style demangling in class declarations
    - ObjC style demangling (strips module prefix)
    - Multiple protocols
    - Protocol parent protocols
    - Category protocols
    - Long protocol names (XCSourceControl example)

### Task 42: Swift Concurrency Type Demangling - DONE
- [x] 42.1 Parse Task types (`ScT` patterns)
  - `ScTyytNeverG` → `Task<Void, Never>`
  - `ScTySSs5ErrorpG` → `Task<String, Error>`
  - Handle generic success/failure type parameters via `parseTaskGenericArgs()`
  - `parseGenericType()` handles: Void (yt), Never, Error, shortcuts (SS, Si, Sb, etc.)
- [x] 42.2 Parse Continuation types (`ScC`, `ScU` patterns)
  - `ScC` → `CheckedContinuation`
  - `ScU` → `UnsafeContinuation`
  - Added to `commonPatterns` dictionary
- [x] 42.3 Parse Actor types and isolation
  - `ScA` → `Actor`
  - `ScM` → `MainActor`
  - Added to `commonPatterns` dictionary
- [x] 42.4 Parse AsyncStream/AsyncSequence types
  - `ScS` → `AsyncStream`
  - `ScF` → `AsyncThrowingStream`
  - `Scg` → `TaskGroup`
  - `ScG` → `ThrowingTaskGroup`
  - `ScP` → `TaskPriority`
  - Added to `commonPatterns` dictionary
- Implementation in `SwiftDemangler.swift`:
  - Added simple patterns to `commonPatterns` dictionary
  - Added `parseTaskGenericArgs()` for Task<Success, Failure> parsing
  - Added `parseGenericType()` for individual type argument parsing
  - 9 new tests in `ConcurrencyTypeDemanglingTests` suite (353 total tests)

### Task 43: Enhanced Generic Type Demangling
- [x] 43.1 Parse generic type parameters in full - DONE
  - `_TtGC10ModuleName7GenericSS_` → `ModuleName.Generic<String>`
  - Handle multiple type parameters (e.g., `PairMap<String, Int>`)
  - Handle nested generics: `Array<Dictionary<String, Int>>`
  - Fix `Dictionary<SS...>` → `[String: Int]` (Swift literal format)
  - Added `demangleGenericType()` for `_TtGC`/`_TtGV`/`_TtGO` prefixes
  - Added `parseGenericTypeArg()` for type argument parsing
  - Updated dictionary demangling to parse both key and value types
  - 14 new tests in `EnhancedGenericTypeDemanglingTests` suite (367 total tests)
- [ ] 43.2 Implement generic constraint parsing
  - Parse `where` clause equivalents in mangling
  - Handle associated type constraints
  - Handle protocol conformance constraints
- [x] 43.3 Format generic types in property/ivar declarations - DONE
  - Show `Array<String>` instead of mangled form via ObjCTypeFormatter
  - Handle Optional (`?` suffix) - `_TtSSSg` → `String?`
  - Handle Array shorthand - `_TtSaySSG` → `[String]`
  - Handle Dictionary shorthand - `_TtSDySSSiG` → `[String: Int]`
  - Added `_TtS` prefix handling for Swift stdlib types
  - 14 new tests for property type formatting (381 total tests)
- [x] 43.4 Handle deeply nested generic types - DONE
  - Recursive parsing for arbitrary nesting depth
  - Two-level: `[[String]]`, `[String: [Int]]`, `[Set<Int>]`
  - Three-level: `[[[String]]]`, `[String: [String: Int]]`
  - Optionals: `[String]?`, `[String?]`, `[String?]?`
  - Set types: `Set<String>`, `Set<[Int]>`
  - Mixed: `[String: Set<Int>]`, `[Set<[Int]>]`
  - Generic classes with nested type args: `Container<[[String]]>`
  - Safety: `maxGenericNestingDepth = 10` prevents stack overflow
  - 24 new tests in `DeeplyNestedGenericTypeDemanglingTests` (405 total tests)

### Task 44: Swift Type Descriptor Integration
- [ ] 44.1 Use `__swift5_types` to resolve type metadata
  - Link type descriptors to ObjC class metadata by address
  - Extract full generic signature from descriptors
  - Handle value types (struct/enum) as well as classes
- [ ] 44.2 Parse nominal type descriptors for complete type info
  - Access control (public/internal/private)
  - Generic parameters with constraints
  - Parent type for nested types
- [ ] 44.3 Use `__swift5_fieldmd` for property type resolution
  - Match field descriptors to class ivars by name
  - Resolve field types using symbolic references
  - Handle @objc properties specially

### Task 45: Function/Method Signature Demangling
- [ ] 45.1 Parse Swift method signatures
  - Format: `_$s...F...` for function symbols
  - Extract parameter types and return type
  - Handle throwing functions, async functions
- [ ] 45.2 Demangle closure types
  - `@convention(block)` closures
  - Escaping vs non-escaping
  - Sendable closures
- [ ] 45.3 Format method signatures in output
  - Show Swift-style: `func name(label: Type) -> ReturnType`
  - Or ObjC-style with Swift types: `- (ReturnType)nameWithLabel:(Type)param`

### Task 46: ObjC Type Encoding Enhancements
- [ ] 46.1 Complete ObjC type encoding coverage
  - Audit all ObjC type encoding characters
  - Handle complex struct encodings with nested types
  - Handle union types
  - Handle vector/SIMD types
- [ ] 46.2 Resolve forward-declared types
  - When type shows as `struct CGRect` but actual type available
  - Use runtime metadata to resolve typedefs
  - Handle `@class` forward declarations
- [x] 46.3 Improve block type formatting (eliminate CDUnknownBlockType) - DONE
  - [x] Parse block signature from type encoding (`@?<v@?@>` → `void (^)(id)`) - Already works
  - [x] Extract return type and parameter types from block encoding - Already works
  - [x] Show `void (^)(id, NSError *)` instead of `CDUnknownBlockType` - Works when signature present
  - [x] Handle completion handlers: `(void (^)(BOOL success, NSError *error))` - Works
  - [x] Handle blocks with block parameters (nested blocks) - Works
  - [x] Fall back to `id /* block */` instead of `CDUnknownBlockType` - NEW
  - [x] Block variable names now appear in proper position: `void (^handler)(void)`
  - 12 new tests added (417 total tests)
- [~] 46.4 Audit and fix CDUnknownBlockType occurrences - PARTIAL
  - [x] Changed fallback from `CDUnknownBlockType` to `id /* block */`
  - [ ] Cross-reference with protocol method signatures for same selector
  - [ ] Parse Swift metadata for closure signatures
  - [ ] Add logging/debugging mode to show raw type encoding
  - [x] Created comprehensive test cases for block signatures

### Task 47: System Library Integration
- [ ] 47.1 Use `swift-demangle` when available
  - Shell out to `/usr/bin/swift-demangle` for complex cases
  - Cache results for repeated symbols
  - Fall back to built-in demangler if unavailable
- [ ] 47.2 Optionally link libswiftDemangle
  - `dlopen` the Swift runtime library
  - Use `swift_demangle` C API for full accuracy
  - Handle symbol versioning across Swift versions
- [ ] 47.3 Create demangling cache for performance
  - LRU cache for demangled names
  - Persist cache across runs (optional)
  - Thread-safe implementation

### Task 48: Output Format Options
- [ ] 48.1 Add `--swift` output mode
  - Output `.swiftinterface`-style declarations
  - Format: `public class Name: SuperClass, Protocol { ... }`
  - Include access control, attributes
- [ ] 48.2 Add `--mixed` output mode
  - Show both ObjC and Swift representations
  - ObjC `@interface` followed by Swift `class` declaration
  - Useful for bridging header generation
- [ ] 48.3 Add `--json` structured output
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
- [x] Concurrency types:
  - [x] `ScT` Task types with generic parameters
  - [x] `ScC`/`ScU` Continuation types (CheckedContinuation, UnsafeContinuation)
  - [x] `ScA` Actor types
  - [x] `ScM` MainActor
  - [x] `ScP` TaskPriority
  - [x] `Scg` TaskGroup
  - [x] `ScG` ThrowingTaskGroup
  - [x] `ScS`/`ScF` AsyncStream, AsyncThrowingStream patterns
- [ ] Complex generics:
  - [ ] `Dictionary<SS...>` → `Dictionary<String, ...>`
  - [ ] Nested generics with multiple levels
  - [ ] Optional generic parameters

---

## Phase 1 & 2 Remaining Tasks

- [ ] 18 Concurrency + performance pass
  - TaskGroup parsing
  - Parallel file scanning
  - Caching
  - Memory mapping
- [ ] 23 Add Swift name demangling support (swift_demangle API or custom demangler)
- [ ] 24 Add Swift metadata parsing (Swift reflection metadata, type descriptors, witness tables)
- [ ] 25 Investigate native Apple frameworks for lexer/parser (SwiftSyntax, swift-format infrastructure)
- [ ] 26 Performance optimization pass
  - Reference: g-cqd/SwiftStaticAnalysis patterns
  - Memory-mapped Data with no intermediate copies
  - Parallel segment/section processing with TaskGroup
  - Lock-free concurrent caches
  - SIMD-accelerated string scanning where applicable
- [ ] 27 Create DocC generator from class-dump output
  - Generate DocC-compatible documentation from dumped headers
  - Support merging multiple framework dumps into unified documentation
  - Symbol graph generation for integration with Xcode documentation

---

## Phase 4: Swift Metadata Support (Incomplete)

### Partial Items
- [~] 33 Parse Swift protocol descriptors (partial)
  - Parse `__swift5_protos` section for protocol names
  - **TODO**: Full protocol requirements
- [~] 34 Parse protocol conformances (partial)
  - Parse `__swift5_proto` section for conformance records
  - Type-to-protocol mapping extracted
- [~] 36 Integrate Swift types with ObjC output (partial)
  - Field descriptor lookup by class name
  - **TODO**: Link field descriptors to ObjC classes via address matching

### Not Started
- [ ] 35 Generate Swift-style headers
  - Format Swift types as `.swiftinterface`-like output
  - Handle generics, property wrappers, result builders

---

## Phase 5: dyld_shared_cache Integration

- [ ] 36 Shared Cache Foundation
  - Implement `MemoryMappedReader` for large file access (3+ GB files)
  - Parse `dyld_cache_header` (magic, mappings, images)
  - Support split caches (.01, .02, etc.) for modern iOS
  - Reference: ipsw's `dyld.Open()` in pkg/dyld
- [ ] 37 Address Translation
  - Implement `SharedCacheAddressTranslator` for VM-to-offset logic
  - Parse `dyld_cache_slide_info` for pointer rebasing
  - Handle multiple cache mappings with different permissions
- [ ] 38 In-Cache Image Analysis
  - List available images in the shared cache
  - Extract Mach-O data for specific image (zero-copy view)
  - Adapt `ObjC2Processor` to work with in-cache images
  - Handle DSC-specific ObjC optimizations (shared selector table)
- [ ] 39 ObjC Optimization Tables (Optional)
  - Parse global class/selector/protocol tables for faster lookup
  - Reference: ipsw's `f.GetAllObjCClasses()` etc.

---

## Phase 6: Quality of Life Improvements

- [ ] 40 JSON output option (`--json`)
  - Structured output for tooling integration
  - Include class hierarchy, methods, properties, protocols
- [ ] 41 Inspection command (`class-dump info`)
  - Display Mach-O header, load commands, sections
  - Show architecture, platform, deployment target
  - Useful for debugging parsing failures
- [ ] 42 Address utilities
  - Expose `a2o` / `o2a` conversion for debugging
  - Resolve addresses to symbol names for `-A` output
- [ ] 43 Lipo export functionality
  - Extract single architecture to standalone file
  - Useful for processing fat binaries
- [ ] 44 Entitlements display
  - Parse LC_CODE_SIGNATURE blob
  - Extract and display XML entitlements

---

## Phase 7: Advanced Capabilities

- [ ] 45 Full Swift type support (generics, protocols, extensions, property wrappers)
- [ ] 46 Recursive framework dependency resolution with caching
- [ ] 47 Watch mode for incremental re-dumping on file changes
- [ ] 48 LSP integration for IDE support
- [ ] 49 Dylib extraction from shared cache
  - Reconstruct standalone Mach-O from cached image
  - Handle LINKEDIT reconstruction

---

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

---

## Concurrency and Performance Targets

- Parallel parsing of independent Mach-O files (TaskGroup)
- Concurrent processing of load commands/segments where safe
- Memory-mapped file IO for large binaries (required for DSC support)
- Avoid repeated parsing via caching of tables and strings
- Replace NSMutableArray with Swift arrays and reserveCapacity

---

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
