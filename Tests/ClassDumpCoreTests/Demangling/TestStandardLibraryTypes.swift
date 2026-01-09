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
