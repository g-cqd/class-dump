// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

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

// MARK: - demangleSwiftName Output Tests

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
