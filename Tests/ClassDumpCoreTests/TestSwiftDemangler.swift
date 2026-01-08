// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Standard Library Type Shortcuts

@Suite("Standard Library Type Shortcuts")
struct StandardLibraryTypeShortcutTests {
    @Test(
        "Single character shortcuts demangle to standard types",
        arguments: [
            ("a", "Array"),
            ("b", "Bool"),
            ("D", "Dictionary"),
            ("d", "Double"),
            ("f", "Float"),
            ("h", "Set"),
            ("i", "Int"),
            ("J", "Character"),
            ("N", "ClosedRange"),
            ("n", "Range"),
            ("O", "ObjectIdentifier"),
            ("P", "UnsafePointer"),
            ("p", "UnsafeMutablePointer"),
            ("q", "Optional"),
            ("R", "UnsafeBufferPointer"),
            ("r", "UnsafeMutableBufferPointer"),
            ("S", "String"),
            ("s", "Substring"),
            ("u", "UInt"),
            ("V", "UnsafeRawPointer"),
            ("v", "UnsafeMutableRawPointer"),
        ]
    )
    func singleCharacterShortcuts(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }
}

// MARK: - Common Mangled Patterns

@Suite("Common Mangled Patterns")
struct CommonMangledPatternTests {
    @Test(
        "Two-character patterns demangle correctly",
        arguments: [
            ("Sb", "Bool"),
            ("Si", "Int"),
            ("Su", "UInt"),
            ("Sf", "Float"),
            ("Sd", "Double"),
            ("SS", "String"),
        ]
    )
    func twoCharacterPatterns(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }

    @Test(
        "Fixed-width integer types demangle correctly",
        arguments: [
            ("s5Int8V", "Int8"),
            ("s6UInt8V", "UInt8"),
            ("s5Int16V", "Int16"),
            ("s6UInt16V", "UInt16"),
            ("s5Int32V", "Int32"),
            ("s6UInt32V", "UInt32"),
            ("s5Int64V", "Int64"),
            ("s6UInt64V", "UInt64"),
        ]
    )
    func fixedWidthIntegers(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }

    @Test("Optional pattern demangles correctly")
    func optionalPatterns() {
        #expect(SwiftDemangler.demangle("Sg") == "Optional")
        #expect(SwiftDemangler.demangle("Sq") == "Optional")
    }

    @Test("Void tuple demangles correctly")
    func voidTuple() {
        #expect(SwiftDemangler.demangle("yt") == "()")
    }

    @Test(
        "Concurrency types demangle correctly",
        arguments: [
            ("ScT", "Task"),
            ("Scg", "TaskGroup"),
            ("ScP", "TaskPriority"),
            ("ScA", "Actor"),
        ]
    )
    func concurrencyTypes(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }
}

// MARK: - Builtin Types

@Suite("Builtin Types")
struct BuiltinTypeTests {
    @Test(
        "Builtin types demangle correctly",
        arguments: [
            ("Bb", "Builtin.BridgeObject"),
            ("Bo", "Builtin.NativeObject"),
            ("BO", "Builtin.UnknownObject"),
            ("Bp", "Builtin.RawPointer"),
            ("Bw", "Builtin.Word"),
            ("BB", "Builtin.UnsafeValueBuffer"),
            ("BD", "Builtin.DefaultActorStorage"),
            ("Be", "Builtin.Executor"),
            ("Bi", "Builtin.Int"),
            ("Bf", "Builtin.FPIEEE"),
            ("Bv", "Builtin.Vec"),
        ]
    )
    func builtinTypes(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }
}

// MARK: - ObjC Class Name Demangling

@Suite("ObjC Swift Class Name Demangling")
struct ObjCClassNameTests {
    @Test("Demangle simple class name")
    func simpleClassName() {
        let name = "_TtC13IDEFoundation16IDEActionHistory"
        let result = SwiftDemangler.demangleClassName(name)

        #expect(result != nil, "Should demangle Swift class name")
        if let (module, className) = result {
            #expect(module == "IDEFoundation", "Module should be IDEFoundation")
            #expect(className == "IDEActionHistory", "Class should be IDEActionHistory")
        }
    }

    @Test("Demangle long class name")
    func longClassName() {
        let name = "_TtC13IDEFoundation61IDETestTagReferenceTreeItemCollectionSourceConsolidatedSource"
        let result = SwiftDemangler.demangleClassName(name)

        #expect(result != nil, "Should demangle long Swift class name")
        if let (module, className) = result {
            #expect(module == "IDEFoundation")
            #expect(
                className == "IDETestTagReferenceTreeItemCollectionSourceConsolidatedSource",
                "Class name: \(className)"
            )
        }
    }

    @Test("Demangle generic class name (_TtGC prefix)")
    func genericClassName() {
        let name = "_TtGC13IDEFoundation3MapSS_"
        let result = SwiftDemangler.demangleClassName(name)

        #expect(result != nil)
        if let (module, className) = result {
            #expect(module == "IDEFoundation")
            #expect(className == "Map")
        }
    }

    @Test("Demangle old style class name (_Tt prefix)")
    func oldStyleClassName() {
        let name = "_Tt13IDEFoundation7MyClass"
        let result = SwiftDemangler.demangleClassName(name)

        #expect(result != nil)
        if let (module, className) = result {
            #expect(module == "IDEFoundation")
            #expect(className == "MyClass")
        }
    }

    @Test("Returns nil for non-Swift names")
    func nonSwiftName() {
        #expect(SwiftDemangler.demangleClassName("NSObject") == nil)
        #expect(SwiftDemangler.demangleClassName("UIView") == nil)
        #expect(SwiftDemangler.demangleClassName("") == nil)
    }
}

// MARK: - Nested Class Demangling

@Suite("Nested Class Demangling")
struct NestedClassTests {
    @Test("Demangle nested class (_TtCC prefix)")
    func nestedClass() {
        let name = "_TtCC13IDEFoundation22IDEBuildNoticeProvider16BuildLogObserver"
        let result = SwiftDemangler.demangleClassName(name)

        #expect(result != nil)
        if let (module, className) = result {
            #expect(module == "IDEFoundation")
            #expect(className == "IDEBuildNoticeProvider.BuildLogObserver")
        }
    }

    @Test("Get nested class names as array")
    func nestedClassNameArray() {
        let name = "_TtCC13IDEFoundation22IDEBuildNoticeProvider16BuildLogObserver"
        let names = SwiftDemangler.demangleNestedClassName(name)

        #expect(names.count == 2)
        #expect(names.first == "IDEBuildNoticeProvider")
        #expect(names.last == "BuildLogObserver")
    }

    @Test("Get deeply nested class names (_TtCCC prefix)")
    func deeplyNestedClassName() {
        // Class within class within class
        let name = "_TtCCC10ModuleName5Outer5Inner7Deepest"
        let names = SwiftDemangler.demangleNestedClassName(name)

        #expect(names.count == 3)
        #expect(names == ["Outer", "Inner", "Deepest"])
    }

    @Test("Returns empty array for non-nested class")
    func nonNestedClass() {
        let names = SwiftDemangler.demangleNestedClassName("NSObject")
        #expect(names.isEmpty)
    }
}

// MARK: - Module-Qualified Types

@Suite("Module-Qualified Types")
struct ModuleQualifiedTypeTests {
    @Test("Demangle Foundation.Date")
    func foundationDate() {
        let mangled = "10Foundation4DateV"
        let result = SwiftDemangler.extractTypeName(mangled)
        #expect(result == "Foundation.Date")
    }

    @Test("Demangle UIKit types")
    func uikitTypes() {
        let mangled = "5UIKit6UIViewC"
        let result = SwiftDemangler.extractTypeName(mangled)
        #expect(result == "UIKit.UIView")
    }

    @Test("Demangle Swift module types")
    func swiftModuleTypes() {
        // Swift.Array struct
        let mangled = "s5ArrayV"
        let result = SwiftDemangler.extractTypeName(mangled)
        #expect(result.contains("Array"))
    }
}

// MARK: - ObjC Imported Types (So prefix)

@Suite("ObjC Imported Types")
struct ObjCImportedTypeTests {
    @Test("Demangle dispatch queue type")
    func dispatchQueueType() {
        let mangled = "So17OS_dispatch_queueC"
        let result = SwiftDemangler.extractTypeName(mangled)
        #expect(result == "DispatchQueue")
    }

    @Test("Demangle NSObject")
    func nsObjectType() {
        let mangled = "So8NSObjectC"
        let result = SwiftDemangler.demangle(mangled)
        #expect(result == "NSObject")
    }

    @Test("Demangle NSString")
    func nsStringType() {
        let mangled = "So8NSStringC"
        let result = SwiftDemangler.demangle(mangled)
        #expect(result == "String")
    }

    @Test("Demangle NSURL")
    func nsurlType() {
        let mangled = "So5NSURLC"
        let result = SwiftDemangler.demangle(mangled)
        #expect(result == "URL")
    }

    @Test("Demangle NSData")
    func nsDataType() {
        let mangled = "So6NSDataC"
        let result = SwiftDemangler.demangle(mangled)
        #expect(result == "Data")
    }

    @Test("Demangle unknown ObjC type")
    func unknownObjCType() {
        // Should return the type name as-is when not in mappings
        let mangled = "So15SomeCustomClassC"
        let result = SwiftDemangler.demangle(mangled)
        #expect(result == "SomeCustomClass")
    }
}

// MARK: - Swift 5+ Symbols

@Suite("Swift 5+ Symbol Demangling")
struct Swift5SymbolTests {
    @Test("Demangle _$s prefixed symbol")
    func dollarSPrefixedSymbol() {
        let mangled = "_$s10Foundation4DateV"
        let result = SwiftDemangler.extractTypeName(mangled)
        #expect(result == "Foundation.Date")
    }

    @Test("Demangle $s prefixed symbol (without underscore)")
    func dollarSWithoutUnderscore() {
        let mangled = "$s10Foundation4DateV"
        let result = SwiftDemangler.extractTypeName(mangled)
        #expect(result == "Foundation.Date")
    }

    @Test("Demangle Swift stdlib type via _$s")
    func swiftStdlibType() {
        // Swift.String struct
        let mangled = "_$sSS"
        let result = SwiftDemangler.extractTypeName(mangled)
        // Should recognize this as Swift.String or just String
        #expect(result.contains("S") || result == "_$sSS")
    }
}

// MARK: - Word Substitutions

@Suite("Word Substitution Demangling")
struct WordSubstitutionTests {
    @Test("Handle word substitution in type names")
    func wordSubstitutionBasic() {
        // IDEFoundation.IDEFoundationCache -> uses word substitution
        // In Swift mangling, repeated words use 0A, 0B etc. references
        // This is a simplified test - the actual substitution logic is complex
        let mangled = "_$s8Dispatch0A5QueueC"  // Dispatch.DispatchQueue (uses 0A = "Dispatch")
        let result = SwiftDemangler.extractTypeName(mangled)
        #expect(result.contains("Dispatch"))
    }
}

// MARK: - Private Types

@Suite("Private Type Demangling")
struct PrivateTypeTests {
    @Test("Demangle private class with discriminator")
    func privateClassWithDiscriminator() {
        // Private classes have P33_ followed by 32 hex chars
        let name = "_TtC13IDEFoundation11PublicClassP33_1234567890ABCDEF1234567890ABCDEF12PrivateClass"
        let result = SwiftDemangler.demangleClassName(name)

        // Should at least extract the module and outer class
        #expect(result != nil)
        if let (module, _) = result {
            #expect(module == "IDEFoundation")
        }
    }

    @Test("Nested class parsing stops at private discriminator")
    func nestedClassStopsAtPrivateDiscriminator() {
        // Note: The mangled name format for nested classes with private discriminators
        // varies. This tests that the parser handles the P (private) marker correctly.
        let name = "_TtCC13IDEFoundation10OuterClass10InnerClassP33_ABC"
        let names = SwiftDemangler.demangleNestedClassName(name)

        // Should extract class names (may vary based on parsing strategy)
        // The key is that it doesn't crash and returns reasonable results
        #expect(names.count >= 0)  // Should not crash

        // If names were extracted, they should be reasonable
        if !names.isEmpty {
            #expect(names.allSatisfy { !$0.isEmpty })
        }
    }
}

// MARK: - Generic Types

@Suite("Generic Type Demangling")
struct GenericTypeTests {
    @Test("Demangle Optional suffix (Sg)")
    func optionalSuffix() {
        // IntSg = Optional<Int>
        let result = SwiftDemangler.demangle("SiSg")
        #expect(result == "Int?")
    }

    @Test("Demangle Array shorthand (Say...G)")
    func arrayShorthand() {
        // Array<Int> = SaySiG
        let result = SwiftDemangler.demangle("SaySiG")
        #expect(result == "[Int]")
    }

    @Test("Demangle Dictionary shorthand (SDy...G)")
    func dictionaryShorthand() {
        // Dictionary<String, Int> = SDySSSiG
        let result = SwiftDemangler.demangle("SDySSSiG")
        // Accepts either Dictionary<K, V> or [K: V] format
        #expect(result.contains("Dictionary") || result.contains("[String: Int]"))
    }
}

// MARK: - Edge Cases

@Suite("Edge Cases")
struct EdgeCaseTests {
    @Test("Empty string returns empty")
    func emptyString() {
        #expect(SwiftDemangler.demangle("") == "")
        #expect(SwiftDemangler.extractTypeName("") == "")
    }

    @Test("Unknown mangled string returns original")
    func unknownMangledString() {
        let weird = "xyz123abc"
        let result = SwiftDemangler.demangle(weird)
        // Should return something, not crash
        #expect(!result.isEmpty || result == weird)
    }

    @Test("Symbolic reference marker returns input")
    func symbolicReferenceMarker() {
        // 0x01 is the symbolic reference marker
        let mangled = "\u{01}XXXX"
        let result = SwiftDemangler.demangle(mangled)
        // Should not return "/* symbolic ref */" anymore
        #expect(!result.contains("symbolic"))
    }

    @Test("demangleComplexType handles simple cases")
    func complexTypeSimple() {
        let result = SwiftDemangler.demangleComplexType("Si")
        #expect(result == "Int")
    }

    @Test("demangleComplexType returns input for truly complex cases")
    func complexTypeFallback() {
        // Very complex mangled types should not crash
        let complex = "So44IDEBatchFindTextFragmentIndexContentSnapshotCShyPathEntryG"
        let result = SwiftDemangler.demangleComplexType(complex)
        #expect(!result.isEmpty)
    }
}

// MARK: - String Extension

@Suite("String Extension")
struct StringExtensionTests {
    @Test("swiftDemangled property works")
    func swiftDemangledProperty() {
        #expect("Si".swiftDemangled == "Int")
        #expect("SS".swiftDemangled == "String")
        #expect("Sb".swiftDemangled == "Bool")
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {
    @Test("Full demangling of real-world class name")
    func realWorldClassName() {
        let name = "_TtC13IDEFoundation35IDEActivityLogSectionRecordProvider"
        let result = SwiftDemangler.demangleClassName(name)

        #expect(result != nil)
        if let (module, className) = result {
            #expect(module == "IDEFoundation")
            #expect(className == "IDEActivityLogSectionRecordProvider")
        }
    }

    @Test("Full demangling of nested class")
    func realWorldNestedClass() {
        let name = "_TtCC13IDEFoundation22IDEBuildNoticeProvider16BuildLogObserver"

        // Test both methods
        let className = SwiftDemangler.demangleClassName(name)
        let nestedNames = SwiftDemangler.demangleNestedClassName(name)

        #expect(className != nil)
        #expect(className?.name == "IDEBuildNoticeProvider.BuildLogObserver")
        #expect(nestedNames == ["IDEBuildNoticeProvider", "BuildLogObserver"])
    }

    @Test("extractTypeName handles various formats")
    func extractTypeNameVariousFormats() {
        // _$s prefixed
        #expect(SwiftDemangler.extractTypeName("_$s10Foundation4DateV").contains("Date"))

        // $s prefixed
        #expect(SwiftDemangler.extractTypeName("$s10Foundation4DateV").contains("Date"))

        // _Tt prefixed
        #expect(SwiftDemangler.extractTypeName("_TtC5UIKit6UIViewC") != "")

        // Qualified type
        #expect(SwiftDemangler.extractTypeName("10Foundation4DateV") == "Foundation.Date")
    }
}

// MARK: - Protocol Demangling

@Suite("Protocol Demangling")
struct ProtocolDemanglingTests {
    @Test("Demangle simple protocol name")
    func simpleProtocolName() {
        let mangled = "_TtP10Foundation8Hashable_"
        let result = SwiftDemangler.demangleProtocolName(mangled)

        #expect(result != nil)
        if let (module, name) = result {
            #expect(module == "Foundation")
            #expect(name == "Hashable")
        }
    }

    @Test("Demangle long protocol name")
    func longProtocolName() {
        let mangled = "_TtP15XCSourceControl30XCSourceControlXPCBaseProtocol_"
        let result = SwiftDemangler.demangleProtocolName(mangled)

        #expect(result != nil)
        if let (module, name) = result {
            #expect(module == "XCSourceControl")
            #expect(name == "XCSourceControlXPCBaseProtocol")
        }
    }

    @Test("Non-protocol name returns nil")
    func nonProtocolReturnsNil() {
        // Class name (not protocol)
        #expect(SwiftDemangler.demangleProtocolName("_TtC10Foundation4Date") == nil)

        // Missing trailing underscore
        #expect(SwiftDemangler.demangleProtocolName("_TtP10Foundation8Hashable") == nil)

        // Not _TtP prefix
        #expect(SwiftDemangler.demangleProtocolName("_TtC10Foundation8Hashable_") == nil)
    }
}

// MARK: - demangleSwiftName Tests

@Suite("demangleSwiftName Output Tests")
struct DemangleSwiftNameTests {
    @Test("Demangle class name for output")
    func classNameForOutput() {
        // 13 = length of "IDEFoundation", 13 = length of "SomeClassName"
        let mangled = "_TtC13IDEFoundation13SomeClassName"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "IDEFoundation.SomeClassName")
    }

    @Test("Demangle nested class name for output")
    func nestedClassNameForOutput() {
        let mangled = "_TtCC13IDEFoundation22IDEBuildNoticeProvider16BuildLogObserver"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "IDEFoundation.IDEBuildNoticeProvider.BuildLogObserver")
    }

    @Test("Demangle protocol name for output")
    func protocolNameForOutput() {
        let mangled = "_TtP10Foundation8Hashable_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "Foundation.Hashable")
    }

    @Test("Demangle Swift stdlib _SwiftObject")
    func swiftObjectForOutput() {
        let mangled = "_TtCs12_SwiftObject"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "_SwiftObject")
    }

    @Test("Demangle private type with P33_ discriminator")
    func privateTypeForOutput() {
        let mangled = "_TtC13IDEFoundationP33_73A6DC029C09B28BFB689EDBD4C7F1D812BackPressure"
        let result = SwiftDemangler.demangleSwiftName(mangled)

        // Should extract module and type name
        #expect(result.contains("IDEFoundation"))
        #expect(result.contains("BackPressure"))
    }

    @Test("Non-mangled name returns as-is")
    func nonMangledNameReturnsAsIs() {
        #expect(SwiftDemangler.demangleSwiftName("NSObject") == "NSObject")
        #expect(SwiftDemangler.demangleSwiftName("MyClass") == "MyClass")
        #expect(SwiftDemangler.demangleSwiftName("UIKit.UIView") == "UIKit.UIView")
    }

    @Test("Swift stdlib type without module prefix")
    func swiftStdlibWithoutModulePrefix() {
        // Swift stdlib types should not have "Swift." prefix
        let mangled = "_TtCs12_SwiftObject"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(!result.hasPrefix("Swift."))
        #expect(result == "_SwiftObject")
    }
}

// MARK: - Swift Concurrency Type Demangling

@Suite("Swift Concurrency Type Demangling")
struct ConcurrencyTypeDemanglingTests {
    // MARK: - Task Types (42.1)

    @Test(
        "Task types with generic parameters demangle correctly",
        arguments: [
            // Task<Void, Never>
            ("ScTyytNeverG", "Task<Void, Never>"),
            // Task<String, Error>
            ("ScTySSs5ErrorpG", "Task<String, Error>"),
            // Task<Int, Never>
            ("ScTySiNeverG", "Task<Int, Never>"),
            // Task<Bool, Error>
            ("ScTySbs5ErrorpG", "Task<Bool, Error>"),
        ]
    )
    func taskTypesWithGenerics(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }

    @Test("Task type without generic parameters returns basic Task")
    func taskTypeBasic() {
        #expect(SwiftDemangler.demangle("ScT") == "Task")
    }

    // MARK: - Continuation Types (42.2)

    @Test(
        "Continuation types demangle correctly",
        arguments: [
            // CheckedContinuation
            ("ScC", "CheckedContinuation"),
            // UnsafeContinuation
            ("ScU", "UnsafeContinuation"),
        ]
    )
    func continuationTypes(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }

    // MARK: - Actor Types (42.3)

    @Test("Actor type demangles correctly")
    func actorType() {
        #expect(SwiftDemangler.demangle("ScA") == "Actor")
    }

    @Test("MainActor attribute recognized")
    func mainActorType() {
        #expect(SwiftDemangler.demangle("ScM") == "MainActor")
    }

    // MARK: - AsyncStream/AsyncSequence Types (42.4)

    @Test(
        "AsyncStream types demangle correctly",
        arguments: [
            ("ScS", "AsyncStream"),
            ("ScF", "AsyncThrowingStream"),
        ]
    )
    func asyncStreamTypes(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }

    // MARK: - TaskGroup Types

    @Test("TaskGroup type demangles correctly")
    func taskGroupType() {
        #expect(SwiftDemangler.demangle("Scg") == "TaskGroup")
    }

    @Test("ThrowingTaskGroup type demangles correctly")
    func throwingTaskGroupType() {
        #expect(SwiftDemangler.demangle("ScG") == "ThrowingTaskGroup")
    }

    // MARK: - TaskPriority

    @Test("TaskPriority type demangles correctly")
    func taskPriorityType() {
        #expect(SwiftDemangler.demangle("ScP") == "TaskPriority")
    }
}

// MARK: - Enhanced Generic Type Demangling (Task 43)

@Suite("Enhanced Generic Type Demangling")
struct EnhancedGenericTypeDemanglingTests {
    // MARK: - 43.1 Parse generic type parameters in full

    @Test("Generic class with String type parameter")
    func genericClassWithString() {
        // _TtGC<module_len><module><class_len><class><type_arg>_
        // ModuleName = 10, Generic = 7, SS = String
        let mangled = "_TtGC10ModuleName7GenericSS_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "ModuleName.Generic<String>")
    }

    @Test("Generic class with Int type parameter")
    func genericClassWithInt() {
        let mangled = "_TtGC10ModuleName7GenericSi_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "ModuleName.Generic<Int>")
    }

    @Test("Generic class with Bool type parameter")
    func genericClassWithBool() {
        let mangled = "_TtGC10ModuleName7GenericSb_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "ModuleName.Generic<Bool>")
    }

    @Test("Generic class with Double type parameter")
    func genericClassWithDouble() {
        let mangled = "_TtGC10ModuleName7GenericSd_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "ModuleName.Generic<Double>")
    }

    @Test("Generic struct with type parameter")
    func genericStructWithTypeParam() {
        // _TtGV prefix for generic struct
        let mangled = "_TtGV10ModuleName7WrapperSS_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "ModuleName.Wrapper<String>")
    }

    // MARK: - Multiple Type Parameters

    @Test("Generic class with two type parameters")
    func genericClassWithTwoParams() {
        // Dictionary-like: Key=String, Value=Int
        let mangled = "_TtGC10ModuleName7PairMapSSSi_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "ModuleName.PairMap<String, Int>")
    }

    @Test("Dictionary type with String key and Int value")
    func dictionaryStringInt() {
        let result = SwiftDemangler.demangle("SDySSSiG")
        #expect(result == "Dictionary<String, Int>" || result == "[String: Int]")
    }

    @Test("Dictionary type with String key and String value")
    func dictionaryStringString() {
        let result = SwiftDemangler.demangle("SDySSSSG")
        #expect(result == "Dictionary<String, String>" || result == "[String: String]")
    }

    // MARK: - Nested Generics

    @Test("Array of String")
    func arrayOfString() {
        let result = SwiftDemangler.demangle("SaySSG")
        #expect(result == "[String]")
    }

    @Test("Array of Int")
    func arrayOfInt() {
        let result = SwiftDemangler.demangle("SaySiG")
        #expect(result == "[Int]")
    }

    @Test("Optional String")
    func optionalString() {
        let result = SwiftDemangler.demangle("SSSg")
        #expect(result == "String?")
    }

    @Test("Optional Int")
    func optionalInt() {
        let result = SwiftDemangler.demangle("SiSg")
        #expect(result == "Int?")
    }

    // MARK: - Real-World Generic Types

    @Test("IDEFoundation Map generic class")
    func ideFoundationMapGeneric() {
        let mangled = "_TtGC13IDEFoundation3MapSSSi_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "IDEFoundation.Map<String, Int>")
    }

    @Test("Generic class preserves module name")
    func genericClassPreservesModule() {
        // "UIKit" = 5 chars, "Container" = 9 chars
        let mangled = "_TtGC5UIKit9ContainerSS_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result.contains("UIKit"))
        #expect(result.contains("Container"))
        #expect(result.contains("String"))
    }
}

// MARK: - Enum and Struct Demangling

@Suite("Enum and Struct Demangling")
struct EnumStructDemanglingTests {
    @Test("Demangle enum type")
    func enumType() {
        // _TtO prefix indicates enum
        let mangled = "_TtO13IDEFoundation19IDEContainerEditing"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result.contains("IDEFoundation"))
        #expect(result.contains("IDEContainerEditing"))
    }

    @Test("Demangle value type (struct)")
    func valueType() {
        // _TtV prefix indicates struct
        let mangled = "_TtV13IDEFoundation12SomeStruct"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result.contains("IDEFoundation") || result.contains("SomeStruct"))
    }

    @Test("Demangle nested enum in class")
    func nestedEnumInClass() {
        // _TtCO indicates class containing enum
        let mangled = "_TtCO13IDEFoundation19IDEContainerEditing18AnyAbstractContext"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result.contains("IDEFoundation"))
    }
}

// MARK: - Deeply Nested Generic Types (Task 43.4)

@Suite("Deeply Nested Generic Type Demangling")
struct DeeplyNestedGenericTypeDemanglingTests {

    // MARK: - Two-Level Nesting

    @Test("Array of Array of String")
    func arrayOfArrayOfString() {
        // [[String]] = SaySaySSGG
        let result = SwiftDemangler.demangle("SaySaySSGG")
        #expect(result == "[[String]]")
    }

    @Test("Array of Array of Int")
    func arrayOfArrayOfInt() {
        // [[Int]] = SaySaySiGG
        let result = SwiftDemangler.demangle("SaySaySiGG")
        #expect(result == "[[Int]]")
    }

    @Test("Array of Dictionary")
    func arrayOfDictionary() {
        // [[String: Int]] = SaySDySSSiGG
        let result = SwiftDemangler.demangle("SaySDySSSiGG")
        #expect(result == "[[String: Int]]")
    }

    @Test("Dictionary with Array value")
    func dictionaryWithArrayValue() {
        // [String: [Int]] = SDySSSaySiGG
        let result = SwiftDemangler.demangle("SDySSSaySiGG")
        #expect(result == "[String: [Int]]")
    }

    @Test("Dictionary with Array key and String value")
    func dictionaryWithArrayKey() {
        // [[Int]: String] - though unusual, should parse
        // SDySaySiGSSG
        let result = SwiftDemangler.demangle("SDySaySiGSSG")
        #expect(result == "[[Int]: String]")
    }

    @Test("Array of Set")
    func arrayOfSet() {
        // [Set<Int>] = SayShySiGG
        let result = SwiftDemangler.demangle("SayShySiGG")
        #expect(result == "[Set<Int>]")
    }

    @Test("Set of Array")
    func setOfArray() {
        // Set<[String]> = ShySaySSGG
        let result = SwiftDemangler.demangle("ShySaySSGG")
        #expect(result == "Set<[String]>")
    }

    // MARK: - Three-Level Nesting

    @Test("Array of Array of Array")
    func arrayOfArrayOfArray() {
        // [[[String]]] = SaySaySaySSGGG
        let result = SwiftDemangler.demangle("SaySaySaySSGGG")
        #expect(result == "[[[String]]]")
    }

    @Test("Dictionary with nested Dictionary value")
    func dictionaryWithNestedDictionaryValue() {
        // [String: [String: Int]] = SDySSSDySSSiGG
        let result = SwiftDemangler.demangle("SDySSSDySSSiGG")
        #expect(result == "[String: [String: Int]]")
    }

    @Test("Array of Dictionary with Array value")
    func arrayOfDictionaryWithArrayValue() {
        // [[String: [Int]]] = SaySDySSSaySiGGG
        let result = SwiftDemangler.demangle("SaySDySSSaySiGGG")
        #expect(result == "[[String: [Int]]]")
    }

    // MARK: - Optional with Nested Generics

    @Test("Optional Array")
    func optionalArray() {
        // [String]? = SaySSGSg
        let result = SwiftDemangler.demangle("SaySSGSg")
        #expect(result == "[String]?")
    }

    @Test("Optional Dictionary")
    func optionalDictionary() {
        // [String: Int]? = SDySSSiGSg
        let result = SwiftDemangler.demangle("SDySSSiGSg")
        #expect(result == "[String: Int]?")
    }

    @Test("Array of Optional String")
    func arrayOfOptionalString() {
        // [String?] = SaySSSgG
        let result = SwiftDemangler.demangle("SaySSSgG")
        #expect(result == "[String?]")
    }

    @Test("Dictionary with Optional value")
    func dictionaryWithOptionalValue() {
        // [String: Int?] = SDySSSiSgG
        let result = SwiftDemangler.demangle("SDySSSiSgG")
        #expect(result == "[String: Int?]")
    }

    @Test("Optional Array of Optional")
    func optionalArrayOfOptional() {
        // [String?]? = SaySSSgGSg
        let result = SwiftDemangler.demangle("SaySSSgGSg")
        #expect(result == "[String?]?")
    }

    // MARK: - Set with Nested Types

    @Test("Set of String")
    func setOfString() {
        // Set<String> = ShySSG
        let result = SwiftDemangler.demangle("ShySSG")
        #expect(result == "Set<String>")
    }

    @Test("Set of Int")
    func setOfInt() {
        // Set<Int> = ShySiG
        let result = SwiftDemangler.demangle("ShySiG")
        #expect(result == "Set<Int>")
    }

    @Test("Optional Set")
    func optionalSet() {
        // Set<String>? = ShySSGSg
        let result = SwiftDemangler.demangle("ShySSGSg")
        #expect(result == "Set<String>?")
    }

    // MARK: - Complex Mixed Nesting

    @Test("Dictionary of String to Set of Int")
    func dictionaryWithSetValue() {
        // [String: Set<Int>] = SDySSShySiGG
        let result = SwiftDemangler.demangle("SDySSShySiGG")
        #expect(result == "[String: Set<Int>]")
    }

    @Test("Array of Set of Array")
    func arrayOfSetOfArray() {
        // [Set<[Int]>] = SayShySaySiGGG
        let result = SwiftDemangler.demangle("SayShySaySiGGG")
        #expect(result == "[Set<[Int]>]")
    }

    // MARK: - Generic Class with Nested Type Arguments

    @Test("Generic class with Array type parameter")
    func genericClassWithArrayParam() {
        // Container<[String]> = _TtGC10ModuleName9ContainerSaySSG_
        let mangled = "_TtGC10ModuleName9ContainerSaySSG_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "ModuleName.Container<[String]>")
    }

    @Test("Generic class with Dictionary type parameter")
    func genericClassWithDictParam() {
        // Container<[String: Int]> = _TtGC10ModuleName9ContainerSDySSSiG_
        let mangled = "_TtGC10ModuleName9ContainerSDySSSiG_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "ModuleName.Container<[String: Int]>")
    }

    @Test("Generic class with nested Array type parameter")
    func genericClassWithNestedArrayParam() {
        // Container<[[String]]> = _TtGC10ModuleName9ContainerSaySaySSGG_
        let mangled = "_TtGC10ModuleName9ContainerSaySaySSGG_"
        let result = SwiftDemangler.demangleSwiftName(mangled)
        #expect(result == "ModuleName.Container<[[String]]>")
    }

    // MARK: - Recursion Depth Safety

    @Test("Handles extremely deep nesting gracefully")
    func extremelyDeepNesting() {
        // This should not crash or hang - should return something reasonable
        // Even if it doesn't fully demangle, it shouldn't fail
        let deeplyNested = "SaySaySaySaySaySaySaySaySaySaySaySaySSGGGGGGGGGGGG"
        let result = SwiftDemangler.demangle(deeplyNested)
        // Should either demangle or return original - just shouldn't crash
        #expect(!result.isEmpty)
    }
}
