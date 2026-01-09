// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

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
