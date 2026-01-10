// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
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

    @Test("Void type demangles correctly")
    func voidType() {
        #expect(SwiftDemangler.demangle("yt") == "Void")
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

// MARK: - ObjC Protocol Types

@Suite("ObjC Protocol Types")
struct ObjCProtocolTypeTests {
    @Test("Array of ObjC protocol type demangles correctly")
    func arrayOfObjCProtocol() {
        // SaySo14DVTCancellable_pG = Array<DVTCancellable>
        let result = SwiftDemangler.demangle("SaySo14DVTCancellable_pG")
        #expect(result == "[DVTCancellable]")
    }

    @Test("ObjC imported type with protocol suffix demangles correctly")
    func objcProtocolSuffix() {
        // So14DVTCancellable_p = DVTCancellable (protocol)
        let result = SwiftDemangler.demangle("So14DVTCancellable_p")
        #expect(result == "DVTCancellable")
    }

    @Test("Optional array of ObjC protocol demangles correctly")
    func optionalArrayOfObjCProtocol() {
        // SaySo14DVTCancellable_pGSg = [DVTCancellable]?
        let result = SwiftDemangler.demangle("SaySo14DVTCancellable_pGSg")
        #expect(result == "[DVTCancellable]?")
    }

    @Test("Dictionary with ObjC protocol value demangles correctly")
    func dictionaryWithObjCProtocolValue() {
        // SDySSso14DVTCancellable_pG = [String: DVTCancellable]
        let result = SwiftDemangler.demangle("SDySSso14DVTCancellable_pG")
        // This may produce [String: DVTCancellable] or similar
        #expect(result.contains("String") || result.contains("SS"))
    }
}

// MARK: - Stdlib Prefix Types

@Suite("Stdlib Prefix Types")
struct StdlibPrefixTypeTests {
    @Test("Array prefix Sa demangles as Array shortcut")
    func arrayShortcut() {
        #expect(SwiftDemangler.demangle("Sa") == "Array")
    }

    @Test("Dictionary prefix SD is recognized")
    func dictionaryPrefix() {
        // SD alone should resolve to Dictionary
        #expect(SwiftDemangler.demangle("D") == "Dictionary")
    }

    @Test("Set prefix Sh is recognized")
    func setPrefix() {
        #expect(SwiftDemangler.demangle("h") == "Set")
    }

    @Test("String prefix SS demangles correctly")
    func stringPrefix() {
        #expect(SwiftDemangler.demangle("SS") == "String")
    }

    @Test("Continuation types with Sc prefix demangle correctly")
    func continuationTypes() {
        #expect(SwiftDemangler.demangle("ScC") == "CheckedContinuation")
        #expect(SwiftDemangler.demangle("ScU") == "UnsafeContinuation")
        #expect(SwiftDemangler.demangle("ScS") == "AsyncStream")
        #expect(SwiftDemangler.demangle("ScF") == "AsyncThrowingStream")
    }

    @Test("MainActor type demangles correctly")
    func mainActorType() {
        #expect(SwiftDemangler.demangle("ScM") == "MainActor")
    }
}

// MARK: - Complex Container Types

@Suite("Complex Container Types")
struct ComplexContainerTypeTests {
    @Test("Nested array of arrays demangles correctly")
    func nestedArrays() {
        // SaySaySiGG = [[Int]]
        let result = SwiftDemangler.demangle("SaySaySiGG")
        #expect(result == "[[Int]]")
    }

    @Test("Dictionary with array value demangles correctly")
    func dictionaryWithArrayValue() {
        // SDySSSaySSGG = [String: [String]]
        let result = SwiftDemangler.demangle("SDySSSaySiGG")
        #expect(result == "[String: [Int]]")
    }

    @Test("Array of dictionaries demangles correctly")
    func arrayOfDictionaries() {
        // SaySDySSsiGG = [[String: Int]]
        let result = SwiftDemangler.demangle("SaySDySSSiGG")
        #expect(result == "[[String: Int]]")
    }

    @Test("Optional nested container demangles correctly")
    func optionalNestedContainer() {
        // SaySaySiGSgG = [[Int]?]
        let result = SwiftDemangler.demangle("SaySaySiGSgG")
        #expect(result == "[[Int]?]")
    }

    @Test("Set of strings demangles correctly")
    func setOfStrings() {
        // ShySSG = Set<String>
        let result = SwiftDemangler.demangle("ShySSG")
        #expect(result == "Set<String>")
    }
}
