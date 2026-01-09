// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Swift Generic Types in Property Declarations

@Suite("Swift Generic Type Formatting")
struct SwiftGenericTypeFormattingTests {
    @Test("Format Swift generic class type with demangling")
    func formatGenericClassWithDemangling() {
        // _TtGC<module_len><module><class_len><class><type_arg>_
        // "ModuleName" = 10 chars, "Container" = 9 chars
        let type = ObjCType.id(className: "_TtGC10ModuleName9ContainerSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("ModuleName.Container<String>"))
    }

    @Test("Format Swift generic class with Int type argument")
    func formatGenericClassWithInt() {
        let type = ObjCType.id(className: "_TtGC10ModuleName7WrapperSi_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("ModuleName.Wrapper<Int>"))
    }

    @Test("Format Swift generic struct type")
    func formatGenericStructType() {
        // _TtGV prefix for generic struct
        let type = ObjCType.id(className: "_TtGV10ModuleName7WrapperSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("ModuleName.Wrapper<String>"))
    }

    @Test("Format Swift generic with multiple type parameters")
    func formatGenericWithMultipleParams() {
        // PairMap<String, Int>: "PairMap" = 7 chars
        let type = ObjCType.id(className: "_TtGC10ModuleName7PairMapSSSi_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("ModuleName.PairMap<String, Int>"))
    }

    @Test("Format Swift class without demangling when style is none")
    func formatSwiftClassNoDemangling() {
        let type = ObjCType.id(className: "_TtGC10ModuleName9ContainerSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .none)
        let result = type.formatted(options: options)
        #expect(result.contains("_TtGC10ModuleName9ContainerSS_"))
    }

    @Test("Format Swift generic class with ObjC style strips module")
    func formatGenericClassObjCStyle() {
        let type = ObjCType.id(className: "_TtGC10ModuleName9ContainerSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .objc)
        let result = type.formatted(options: options)
        #expect(result.contains("Container<String>"))
        #expect(!result.contains("ModuleName."))
    }

    @Test("Format simple Swift class type")
    func formatSimpleSwiftClass() {
        // _TtC<module_len><module><class_len><class>
        // "MyModule" = 8 chars, "MyClass" = 7 chars
        let type = ObjCType.id(className: "_TtC8MyModule7MyClass", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("MyModule.MyClass"))
    }

    @Test("Format property with Swift generic class name and variable")
    func formatPropertyWithGenericClass() {
        let type = ObjCType.id(className: "_TtGC10ModuleName9ContainerSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(variableName: "_items", options: options)
        #expect(result.contains("ModuleName.Container<String>"))
        #expect(result.contains("_items"))
    }

    @Test("Regular ObjC class type unchanged")
    func formatRegularObjCClass() {
        let type = ObjCType.id(className: "NSArray", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result == "NSArray *")
    }

    // MARK: - Optional Type Formatting

    @Test("Format Optional String type")
    func formatOptionalString() {
        // SSSg = Optional<String>: SS=String, Sg=Optional suffix
        let type = ObjCType.id(className: "_TtSSSg", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        // Should show "String?" instead of "Optional<String>"
        #expect(result.contains("String?"))
    }

    @Test("Format Optional Int type")
    func formatOptionalInt() {
        // SiSg = Optional<Int>
        let type = ObjCType.id(className: "_TtSiSg", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("Int?"))
    }

    @Test("Format Array of String type")
    func formatArrayOfString() {
        // SaySS_G = Array<String>
        let type = ObjCType.id(className: "_TtSaySSG", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        // Should show "[String]"
        #expect(result.contains("[String]"))
    }

    @Test("Format Dictionary String to Int type")
    func formatDictionaryStringToInt() {
        // SDySSSiG = Dictionary<String, Int>
        let type = ObjCType.id(className: "_TtSDySSSiG", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        // Should show "[String: Int]"
        #expect(result.contains("[String: Int]"))
    }

    @Test("Format Result type")
    func formatResultType() {
        // Result<String, Error> - typically mangled as custom module type
        // This is a placeholder for when we encounter Result in real binaries
        let type = ObjCType.id(className: "NSObject", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result == "NSObject *")
    }
}
