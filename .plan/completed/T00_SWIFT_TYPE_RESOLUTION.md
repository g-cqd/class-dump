# Task T00: Swift Type Resolution Regressions
**Status**: ✅ Complete

Fixed Swift type demangling issues with 34 new comprehensive tests.

## Subtasks

### T00.1: Swift.AnyObject Conversion to id ✅
- Added `Swift.AnyObject` → `id` conversion in ObjC output mode
- Modified: `TextClassDumpVisitor.convertSwiftTypeToObjC()` and type map
- Modified: `ObjCTypeFormatter.format()` for AnyObject handling

### T00.2: Malformed Array Type Demangling ✅
- Added `parseModuleQualifiedType()` for module.type parsing with `_p` suffix
- Handles: `Say13IDEFoundation19IDETestingSpecifier_pG` → `[any IDETestingSpecifier]`
- Proper Swift syntax using `any` for existential types

### T00.3: Corrupted Generic Array Types ✅
- Validation pass catches partially demangled strings
- Test coverage in T00.8 validation tests

### T00.4: Builtin.DefaultActorStorage Resolution ✅
- DefaultActorStorage handled in demangling
- Tests verify proper formatting

### T00.5: Swift Concurrency Type Demangling ✅
- Added AsyncStream/AsyncThrowingStream with generics: `ScSy...G`
- Added CheckedContinuation/UnsafeContinuation with generics: `ScCy...G`, `ScUy...G`
- Added `parseTaskGenericArgsFromInput()` helper for Task<Success, Failure>
- Handles nested: `SayScTyytNeverGG` → `[Task<(), Never>]`

### T00.6: Protocol Existential Types (`_p` suffix) ✅
- `_p` suffix parsed in `parseModuleQualifiedType()`
- Outputs Swift `any Protocol` syntax for existentials

### T00.7: Complex Nested Generic Dictionary Types ✅
- Covered by improved generic type parsing
- Test coverage for deeply nested dictionaries

### T00.8: Guard Against Partial Demangling Output ✅
- Added `isValidDemangledOutput()` helper to detect garbage
- Tests verify malformed output detection

## Files Modified
- `Sources/ClassDumpCore/Visitor/TextClassDumpVisitor.swift`
- `Sources/ClassDumpCore/Swift/SwiftDemangler.swift`
- `Sources/ClassDumpCore/TypeSystem/ObjCTypeFormatter.swift`

## Tests Added
- `Tests/ClassDumpCoreTests/Demangling/TestSwiftTypeResolution.swift` (34 tests)
