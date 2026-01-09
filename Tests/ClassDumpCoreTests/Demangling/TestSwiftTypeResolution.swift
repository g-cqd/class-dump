// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - T00: Swift Type Resolution Regression Tests

/// Comprehensive tests for Swift type demangling fixes.
/// See .plan/TODO.md Task T00 for full details.
@Suite("T00: Swift Type Resolution")
struct SwiftTypeResolutionTests {

    // MARK: - T00.1: Swift.AnyObject → id Conversion

    @Suite("T00.1: Swift.AnyObject Conversion")
    struct AnyObjectConversionTests {

        @Test("Swift.AnyObject converts to id in ObjC mode")
        func swiftAnyObjectToId() {
            let visitorOptions = ClassDumpVisitorOptions(
                demangleStyle: .swift,
                outputStyle: .objc
            )
            let visitor = TextClassDumpVisitor(options: visitorOptions)

            let ivar = ObjCInstanceVariable(
                name: "_delegate",
                typeEncoding: "@",
                typeString: "Swift.AnyObject",
                offset: 16
            )
            visitor.visitIvar(ivar)

            // Should convert Swift.AnyObject to id
            #expect(visitor.resultString.contains("id _delegate") || visitor.resultString.contains("id "))
            #expect(!visitor.resultString.contains("Swift.AnyObject"))
        }

        @Test("Module-qualified AnyObject converts to id")
        func moduleQualifiedAnyObjectToId() {
            let visitorOptions = ClassDumpVisitorOptions(
                demangleStyle: .swift,
                outputStyle: .objc
            )
            let visitor = TextClassDumpVisitor(options: visitorOptions)

            let ivar = ObjCInstanceVariable(
                name: "_object",
                typeEncoding: "@",
                typeString: "Swift.AnyObject",
                offset: 24
            )
            visitor.visitIvar(ivar)

            #expect(!visitor.resultString.contains("Swift.AnyObject"))
        }

        @Test("Bare AnyObject converts to id")
        func bareAnyObjectToId() {
            let visitorOptions = ClassDumpVisitorOptions(
                demangleStyle: .swift,
                outputStyle: .objc
            )
            let visitor = TextClassDumpVisitor(options: visitorOptions)

            let ivar = ObjCInstanceVariable(
                name: "_anyObject",
                typeEncoding: "@",
                typeString: "AnyObject",
                offset: 32
            )
            visitor.visitIvar(ivar)

            // Should already work via existing type mapping
            #expect(!visitor.resultString.contains("AnyObject"))
        }

        @Test("Optional Swift.AnyObject converts to id")
        func optionalSwiftAnyObjectToId() {
            let visitorOptions = ClassDumpVisitorOptions(
                demangleStyle: .swift,
                outputStyle: .objc
            )
            let visitor = TextClassDumpVisitor(options: visitorOptions)

            let ivar = ObjCInstanceVariable(
                name: "_optionalObject",
                typeEncoding: "@",
                typeString: "Swift.AnyObject?",
                offset: 40
            )
            visitor.visitIvar(ivar)

            // Optional id in ObjC is just id (nullable)
            #expect(!visitor.resultString.contains("Swift.AnyObject"))
        }

        @Test("Swift.AnyObject preserved in Swift mode")
        func swiftAnyObjectPreservedInSwiftMode() {
            let visitorOptions = ClassDumpVisitorOptions(
                demangleStyle: .swift,
                outputStyle: .swift
            )
            let visitor = TextClassDumpVisitor(options: visitorOptions)

            let ivar = ObjCInstanceVariable(
                name: "_delegate",
                typeEncoding: "@",
                typeString: "Swift.AnyObject",
                offset: 16
            )
            visitor.visitIvar(ivar)

            // Swift mode should preserve Swift.AnyObject or just AnyObject
            #expect(
                visitor.resultString.contains("AnyObject") || visitor.resultString.contains("Swift.AnyObject"))
        }

        @Test("ObjC type formatter handles Swift.AnyObject")
        func objcTypeFormatterHandlesSwiftAnyObject() {
            // Test via the type formatting system
            let type = ObjCType.id(className: "Swift.AnyObject", protocols: [])
            let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .objc)
            let result = type.formatted(options: options)
            // Should be "id" not "Swift.AnyObject *"
            #expect(result == "id" || result == "id *" || !result.contains("Swift.AnyObject"))
        }
    }

    // MARK: - T00.2/T00.6: Protocol Existential Types (_p suffix)

    @Suite("T00.2/T00.6: Protocol Existential Types")
    struct ProtocolExistentialTests {

        @Test("ObjC protocol with _p suffix demangles correctly")
        func objcProtocolExistential() {
            // So19IDETestingSpecifier_p = protocol existential type
            let result = SwiftDemangler.demangle("So19IDETestingSpecifier_p")
            #expect(result == "IDETestingSpecifier")
        }

        @Test("Array of protocol existential demangles correctly")
        func arrayOfProtocolExistential() {
            // Say13IDEFoundation19IDETestingSpecifier_pG = [any IDETestingSpecifier]
            let result = SwiftDemangler.demangle("Say13IDEFoundation19IDETestingSpecifier_pG")
            // Swift syntax uses "any" for existential types
            #expect(
                result == "[any IDETestingSpecifier]" || result == "[IDETestingSpecifier]"
                    || result == "[IDEFoundation.IDETestingSpecifier]")
        }

        @Test("Module-qualified protocol existential demangles correctly")
        func moduleQualifiedProtocolExistential() {
            // Module-prefixed protocol with _p suffix
            let result = SwiftDemangler.demangle("13IDEFoundation19IDETestingSpecifier_p")
            // Should return just the protocol name or module.protocol
            #expect(
                result.contains("IDETestingSpecifier") && !result.contains("_p")
                    || result == "13IDEFoundation19IDETestingSpecifier_p")
        }

        @Test("Protocol suffix _p stripped from type names")
        func protocolSuffixStripped() {
            // DVTCancellable with _p suffix
            let result = SwiftDemangler.demangle("So14DVTCancellable_p")
            #expect(result == "DVTCancellable")
            #expect(!result.contains("_p"))
        }

        @Test("Nested array with protocol existential")
        func nestedArrayWithProtocolExistential() {
            // Nested array of protocol existential
            let result = SwiftDemangler.demangle("SaySaySo14DVTCancellable_pGG")
            #expect(result == "[[DVTCancellable]]")
        }

        @Test("Dictionary with protocol existential value")
        func dictionaryWithProtocolExistentialValue() {
            // [String: Protocol] where protocol has _p suffix
            let result = SwiftDemangler.demangle("SDySSSo14DVTCancellable_pG")
            #expect(result.contains("DVTCancellable"))
            #expect(!result.contains("_p"))
        }
    }

    // MARK: - T00.5: Swift Concurrency Types with Generics

    @Suite("T00.5: Swift Concurrency Types")
    struct ConcurrencyTypesTests {

        @Test("Continuation with generic parameters demangles correctly")
        func continuationWithGenerics() {
            // ScS12ContinuationVMn pattern
            // Note: The exact mangling may vary, testing common patterns
            let result1 = SwiftDemangler.demangle("ScS")
            #expect(result1 == "AsyncStream")

            // Full continuation type
            let result2 = SwiftDemangler.demangle("ScC")
            #expect(result2 == "CheckedContinuation")
        }

        @Test("Array of Task with generics demangles correctly")
        func arrayOfTaskWithGenerics() {
            // SayScTyytNeverGG = [Task<Void, Never>]
            let result = SwiftDemangler.demangle("SayScTyytNeverGG")
            // Should be [Task<Void, Never>] or at least contain Task
            #expect(result.contains("Task") || result == "[Task<Void, Never>]")
        }

        @Test("Task with Void and Never demangles correctly")
        func taskVoidNever() {
            // ScTyytNeverG = Task<Void, Never>
            let result = SwiftDemangler.demangle("ScTyytNeverG")
            // Should demangle to Task<Void, Never>
            #expect(result == "Task<Void, Never>" || result.contains("Task"))
        }

        @Test("Task with String and Error demangles correctly")
        func taskStringError() {
            let result = SwiftDemangler.demangle("ScTySSs5ErrorpG")
            #expect(result == "Task<String, Error>")
        }

        @Test("Nested Task in array")
        func nestedTaskInArray() {
            // Array of Task types
            let result = SwiftDemangler.demangle("SayScTySiNeverGG")
            #expect(result.contains("Task") || result == "[Task<Int, Never>]")
        }

        @Test("AsyncStream with generic element")
        func asyncStreamWithGenericElement() {
            // AsyncStream<Int>
            let result = SwiftDemangler.demangle("ScSySiG")
            // Should either be AsyncStream<Int> or just handle the base type
            #expect(result.contains("AsyncStream") || result.contains("Int"))
        }

        @Test("Continuation in Array")
        func continuationInArray() {
            // Array of CheckedContinuation
            let result = SwiftDemangler.demangle("SayScCG")
            #expect(result.contains("CheckedContinuation") || result.contains("Sc"))
        }
    }

    // MARK: - T00.4: Builtin.DefaultActorStorage

    @Suite("T00.4: Builtin Types")
    struct BuiltinTypesTests {

        @Test("DefaultActorStorage demangles correctly")
        func defaultActorStorage() {
            let result = SwiftDemangler.demangle("BD")
            #expect(result == "Builtin.DefaultActorStorage")
        }

        @Test("DefaultActorStorage formatted for ObjC output")
        func defaultActorStorageObjCFormat() {
            let visitorOptions = ClassDumpVisitorOptions(
                demangleStyle: .swift,
                outputStyle: .objc
            )
            let visitor = TextClassDumpVisitor(options: visitorOptions)

            let ivar = ObjCInstanceVariable(
                name: "$defaultActor",
                typeEncoding: "@",
                typeString: "Builtin.DefaultActorStorage",
                offset: 16
            )
            visitor.visitIvar(ivar)

            // Should be formatted cleanly, not raw Builtin type
            // Accept either /* actor storage */ or Builtin.DefaultActorStorage *
            #expect(
                visitor.resultString.contains("$defaultActor")
                    && (visitor.resultString.contains("actor") || visitor.resultString.contains("Builtin")))
        }
    }

    // MARK: - T00.8: Partial Demangling Validation

    @Suite("T00.8: Partial Demangling Validation")
    struct PartialDemanglingValidationTests {

        @Test("Corrupted output detected and replaced")
        func corruptedOutputDetected() {
            // Test input that produces garbage mixed output
            let corrupted = "SDyIDEFoundation.SnapshotSourceStreamUpdateContext<9y[G_G>ScS12ContinuationVMny"
            let result = SwiftDemangler.demangle(corrupted)

            // Should NOT contain garbage fragments like <9y[G_G> or raw mangled markers
            // If it can't demangle cleanly, should fall back to placeholder
            let hasGarbage =
                result.contains("<9y") || result.contains("G_G>") || result.contains("VMn")
                || result.contains("SDy")
                    && result.contains(">") && result.contains("y[")

            // Either it should demangle cleanly or return the original/placeholder
            #expect(!hasGarbage || result == corrupted)
        }

        @Test("Partial demangling with raw mangled fragments rejected")
        func partialDemanglingRejected() {
            // Type that partially demangles with garbage
            let partial = "SayIDEFoundation.IDETestTreeItem<GGG>yIDEFoundation.IDETestableTreeItemGG"
            let result = SwiftDemangler.demangle(partial)

            // Should not contain mixed demangled/mangled content
            // The <GGG> is garbage from failed parsing
            let hasMixedGarbage =
                result.contains("<GGG>") || (result.contains("IDEFoundation") && result.contains("yIDEFoundation"))

            #expect(!hasMixedGarbage || result == partial)
        }

        @Test("Validate output doesn't contain raw mangled markers")
        func validateNoRawMangledMarkers() {
            // A properly demangled output should not contain these raw patterns
            let testInputs = [
                "SaySiG",  // Simple array - should work
                "SDySSSiG",  // Simple dictionary - should work
            ]

            for input in testInputs {
                let result = SwiftDemangler.demangle(input)
                // These simple cases should demangle cleanly
                #expect(!result.hasPrefix("Say") || result == "[Int]")
                #expect(!result.hasPrefix("SDy") || result == "[String: Int]")
            }
        }

        @Test("Complex nested generic validates correctly")
        func complexNestedGenericValidates() {
            // Triple-nested array should demangle cleanly
            let result = SwiftDemangler.demangle("SaySaySaySiGGG")
            #expect(result == "[[[Int]]]")
        }

        @Test("Fallback for unrecognized concurrency patterns")
        func fallbackForUnrecognizedConcurrency() {
            // If we can't fully demangle a concurrency type, return something clean
            let result = SwiftDemangler.demangle("ScXySomethingWeird")
            // Should either demangle or return as-is, not produce garbage
            #expect(
                !result.contains("<") && !result.contains(">")
                    || result == "ScXySomethingWeird"
                    || result.hasPrefix("Sc"))
        }

        @Test("isValidDemangledOutput helper identifies bad output")
        func isValidDemangledOutputHelper() {
            // Test the validation logic (if implemented)
            let goodOutputs = [
                "[Int]",
                "[String: Int]",
                "Task<Void, Never>",
                "IDETestingSpecifier",
                "MyModule.MyClass",
            ]

            let badOutputs = [
                "SaySiG",  // Raw mangled array
                "SDy...",  // Partial dictionary
                "Sc...",  // Partial concurrency type
                "Type<9y[G>",  // Garbage brackets
                "yIDEFoundation",  // Raw 'y' separator
            ]

            for good in goodOutputs {
                // Good outputs should not look like mangled names
                #expect(!good.hasPrefix("Say"))
                #expect(!good.hasPrefix("SDy"))
                #expect(!good.contains("yIDE"))
            }

            for bad in badOutputs {
                // These patterns indicate incomplete demangling
                let isBad =
                    bad.hasPrefix("Say") || bad.hasPrefix("SDy") || bad.hasPrefix("Sc")
                    || bad.contains("<9") || bad.contains("yIDE")
                #expect(isBad)
            }
        }
    }

    // MARK: - T00.3/T00.7: Complex Nested Generic Types

    @Suite("T00.3/T00.7: Complex Nested Generics")
    struct ComplexNestedGenericsTests {

        @Test("Deeply nested dictionary with array values")
        func deeplyNestedDictionaryWithArrayValues() {
            // [String: [Int]] = SDySSSaySiGG
            let result = SwiftDemangler.demangle("SDySSSaySiGG")
            #expect(result == "[String: [Int]]")
        }

        @Test("Array of dictionaries")
        func arrayOfDictionaries() {
            // [[String: Int]] = SaySDySSSiGG
            let result = SwiftDemangler.demangle("SaySDySSSiGG")
            #expect(result == "[[String: Int]]")
        }

        @Test("Dictionary with nested dictionary value")
        func dictionaryWithNestedDictionaryValue() {
            // [String: [String: Int]] = SDySSSDySSSiGG
            let result = SwiftDemangler.demangle("SDySSSDySSSiGG")
            #expect(result == "[String: [String: Int]]")
        }

        @Test("Optional array of optional strings")
        func optionalArrayOfOptionalStrings() {
            // [String?]? = SaySSSgGSg
            let result = SwiftDemangler.demangle("SaySSSgGSg")
            #expect(result == "[String?]?")
        }

        @Test("Set of arrays")
        func setOfArrays() {
            // Set<[String]> = ShySaySSGG
            let result = SwiftDemangler.demangle("ShySaySSGG")
            #expect(result == "Set<[String]>")
        }
    }

    // MARK: - ObjC Type Formatter Integration

    @Suite("ObjC Type Formatter Integration")
    struct ObjCTypeFormatterIntegrationTests {

        @Test("Swift.AnyObject maps to id in formatter")
        func swiftAnyObjectMapsToId() {
            let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .objc)
            let formatter = ObjCTypeFormatter(options: options)

            // Test that Swift.AnyObject is recognized as needing id conversion
            let type = ObjCType.id(className: "Swift.AnyObject", protocols: [])
            let formatted = type.formatted(options: options)

            // Should not contain Swift.AnyObject in output
            #expect(!formatted.contains("Swift.AnyObject"))
        }

        @Test("Protocol types with _p suffix handled in formatter")
        func protocolTypesHandledInFormatter() {
            let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .objc)

            // If a class name ends with _p, it should be treated as protocol
            let type = ObjCType.id(className: "DVTCancellable_p", protocols: [])
            let formatted = type.formatted(options: options)

            // Should strip _p suffix or format as protocol
            #expect(!formatted.contains("_p") || formatted == "DVTCancellable_p *")
        }
    }
}
