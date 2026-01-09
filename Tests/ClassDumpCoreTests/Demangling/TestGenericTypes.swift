// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

// MARK: - Generic Type Demangling

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
