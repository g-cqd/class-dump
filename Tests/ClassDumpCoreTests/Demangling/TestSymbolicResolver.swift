// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

// MARK: - Swift Symbolic Resolver Container Type Tests

@Suite("Symbolic Resolver Container Types")
struct SymbolicResolverContainerTypeTests {
    /// Create a resolver with empty data for testing helper methods.
    func createTestResolver() -> SwiftSymbolicResolver {
        return SwiftSymbolicResolver(
            data: Data(),
            segments: [],
            byteOrder: .little
        )
    }

    // MARK: - Standard Type Shortcut Tests

    @Test(
        "resolves standard two-character types",
        arguments: [
            ("SS", "String"),
            ("Si", "Int"),
            ("Su", "UInt"),
            ("Sb", "Bool"),
            ("Sd", "Double"),
            ("Sf", "Float"),
        ]
    )
    func resolvesStandardTwoCharTypes(mangled: String, expected: String) {
        // Convert to bytes and test via demangle
        let result = SwiftDemangler.demangle(mangled)
        #expect(result == expected)
    }

    // MARK: - Array with Symbolic Ref (Say...G)

    @Test("parses Array with String element - SaySSG")
    func parsesArrayWithStringElement() {
        // SaySSG should parse as [String]
        let result = SwiftDemangler.demangle("SaySSG")
        #expect(result == "[String]")
    }

    @Test("parses Array with Int element - SaySiG")
    func parsesArrayWithIntElement() {
        let result = SwiftDemangler.demangle("SaySiG")
        #expect(result == "[Int]")
    }

    @Test("parses optional Array - SaySSGSg")
    func parsesOptionalArray() {
        let result = SwiftDemangler.demangle("SaySSGSg")
        #expect(result == "[String]?")
    }

    // MARK: - Dictionary with Symbolic Ref (SDy...G)

    @Test("parses Dictionary with String key and Int value - SDySSSiG")
    func parsesDictWithStringKeyIntValue() {
        let result = SwiftDemangler.demangle("SDySSSiG")
        #expect(result == "[String: Int]")
    }

    @Test("parses Dictionary with String key and Bool value - SDySSSbG")
    func parsesDictWithStringKeyBoolValue() {
        let result = SwiftDemangler.demangle("SDySSSbG")
        #expect(result == "[String: Bool]")
    }

    @Test("parses optional Dictionary - SDySSSiGSg")
    func parsesOptionalDictionary() {
        let result = SwiftDemangler.demangle("SDySSSiGSg")
        #expect(result == "[String: Int]?")
    }

    // MARK: - Set with Symbolic Ref (Shy...G)

    @Test("parses Set with String element - ShySSG")
    func parsesSetWithStringElement() {
        let result = SwiftDemangler.demangle("ShySSG")
        #expect(result == "Set<String>")
    }

    @Test("parses Set with Int element - ShySiG")
    func parsesSetWithIntElement() {
        let result = SwiftDemangler.demangle("ShySiG")
        #expect(result == "Set<Int>")
    }

    // MARK: - Nested Container Types

    @Test("parses nested Array - SaySaySSGG (Array of Arrays)")
    func parsesNestedArray() {
        let result = SwiftDemangler.demangle("SaySaySSGG")
        #expect(result == "[[String]]")
    }

    @Test("parses Dictionary with Array value - SDySSSaySiGG")
    func parsesDictWithArrayValue() {
        let result = SwiftDemangler.demangle("SDySSSaySiGG")
        #expect(result == "[String: [Int]]")
    }

    @Test("parses Array of Dictionaries - SaySDySSSiGG")
    func parsesArrayOfDicts() {
        let result = SwiftDemangler.demangle("SaySDySSSiGG")
        #expect(result == "[[String: Int]]")
    }

    // MARK: - Complex Type Expressions

    @Test("parses deeply nested containers")
    func parsesDeeplyNestedContainers() {
        // [[String: [Int]]]
        let result = SwiftDemangler.demangle("SaySDySSSaySiGGG")
        #expect(result == "[[String: [Int]]]")
    }

    @Test("parses Dictionary with Set value - SDySSShySiGG")
    func parsesDictWithSetValue() {
        let result = SwiftDemangler.demangle("SDySSShySiGG")
        #expect(result == "[String: Set<Int>]")
    }
}

// MARK: - Symbolic Reference Kind Tests

@Suite("Symbolic Reference Kind Tests")
struct SymbolicReferenceKindTests {
    @Test("identifies direct context marker")
    func identifiesDirectContext() {
        let kind = SwiftSymbolicReferenceKind(marker: 0x01)
        #expect(kind == .directContext)
    }

    @Test("identifies indirect context marker")
    func identifiesIndirectContext() {
        let kind = SwiftSymbolicReferenceKind(marker: 0x02)
        #expect(kind == .indirectContext)
    }

    @Test("identifies ObjC protocol marker")
    func identifiesObjCProtocol() {
        let kind = SwiftSymbolicReferenceKind(marker: 0x09)
        #expect(kind == .directObjCProtocol)
    }

    @Test("identifies unknown marker")
    func identifiesUnknownMarker() {
        let kind = SwiftSymbolicReferenceKind(marker: 0xFF)
        #expect(kind == .unknown)
    }

    @Test(
        "isSymbolicMarker returns true for valid range",
        arguments: [UInt8](0x01...0x17)
    )
    func validSymbolicMarkers(marker: UInt8) {
        #expect(SwiftSymbolicReferenceKind.isSymbolicMarker(marker))
    }

    @Test(
        "isSymbolicMarker returns false for invalid values",
        arguments: [UInt8(0x00), UInt8(0x18), UInt8(0x20), UInt8(0xFF)]
    )
    func invalidSymbolicMarkers(marker: UInt8) {
        #expect(!SwiftSymbolicReferenceKind.isSymbolicMarker(marker))
    }
}
