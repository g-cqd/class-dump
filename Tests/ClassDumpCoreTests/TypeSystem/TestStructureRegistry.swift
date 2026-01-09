// SPDX-License-Identifier: MIT
// Copyright (C) 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Structure Registry Tests

@Suite("Structure Registry")
struct StructureRegistryTests {

    // MARK: - Registration Tests

    @Test("Register forward-declared structure")
    func registerForwardDeclaration() {
        let registry = StructureRegistry()
        let forwardDecl = ObjCType.structure(
            name: ObjCTypeName(name: "CGRect"),
            members: []
        )

        registry.register(forwardDecl)

        #expect(registry.count == 1)
        #expect(registry.definedCount == 0)
        #expect(registry.unresolvedStructureNames.contains("CGRect"))
    }

    @Test("Register full structure definition")
    func registerFullDefinition() {
        let registry = StructureRegistry()
        let fullDef = ObjCType.structure(
            name: ObjCTypeName(name: "CGPoint"),
            members: [
                ObjCTypedMember(type: .double, name: "x"),
                ObjCTypedMember(type: .double, name: "y"),
            ]
        )

        registry.register(fullDef)

        #expect(registry.count == 1)
        #expect(registry.definedCount == 1)
        #expect(registry.hasDefinition(for: "CGPoint"))
        #expect(registry.unresolvedStructureNames.isEmpty)
    }

    @Test("Full definition replaces forward declaration")
    func fullDefinitionReplacesForward() {
        let registry = StructureRegistry()

        // First register forward declaration
        let forwardDecl = ObjCType.structure(
            name: ObjCTypeName(name: "CGSize"),
            members: []
        )
        registry.register(forwardDecl)
        #expect(registry.unresolvedStructureNames.contains("CGSize"))

        // Then register full definition
        let fullDef = ObjCType.structure(
            name: ObjCTypeName(name: "CGSize"),
            members: [
                ObjCTypedMember(type: .double, name: "width"),
                ObjCTypedMember(type: .double, name: "height"),
            ]
        )
        registry.register(fullDef)

        #expect(registry.count == 1)
        #expect(registry.definedCount == 1)
        #expect(registry.unresolvedStructureNames.isEmpty)
        #expect(registry.hasDefinition(for: "CGSize"))
    }

    @Test("Keep definition with most members")
    func keepMostCompleteDefinition() {
        let registry = StructureRegistry()

        // Register partial definition
        let partial = ObjCType.structure(
            name: ObjCTypeName(name: "MyStruct"),
            members: [
                ObjCTypedMember(type: .int, name: "a")
            ]
        )
        registry.register(partial)

        // Register more complete definition
        let complete = ObjCType.structure(
            name: ObjCTypeName(name: "MyStruct"),
            members: [
                ObjCTypedMember(type: .int, name: "a"),
                ObjCTypedMember(type: .int, name: "b"),
                ObjCTypedMember(type: .int, name: "c"),
            ]
        )
        registry.register(complete)

        // Verify we kept the more complete one
        if let def = registry.definition(for: "MyStruct"),
            case .structure(_, let members) = def
        {
            #expect(members.count == 3)
        } else {
            Issue.record("Expected structure definition with 3 members")
        }
    }

    @Test("Register nested structures recursively")
    func registerNestedStructures() {
        let registry = StructureRegistry()

        // CGRect contains CGPoint and CGSize
        let cgRect = ObjCType.structure(
            name: ObjCTypeName(name: "CGRect"),
            members: [
                ObjCTypedMember(
                    type: .structure(
                        name: ObjCTypeName(name: "CGPoint"),
                        members: [
                            ObjCTypedMember(type: .double, name: "x"),
                            ObjCTypedMember(type: .double, name: "y"),
                        ]
                    ),
                    name: "origin"
                ),
                ObjCTypedMember(
                    type: .structure(
                        name: ObjCTypeName(name: "CGSize"),
                        members: [
                            ObjCTypedMember(type: .double, name: "width"),
                            ObjCTypedMember(type: .double, name: "height"),
                        ]
                    ),
                    name: "size"
                ),
            ]
        )

        registry.register(cgRect)

        #expect(registry.count == 3)  // CGRect, CGPoint, CGSize
        #expect(registry.definedCount == 3)
        #expect(registry.hasDefinition(for: "CGRect"))
        #expect(registry.hasDefinition(for: "CGPoint"))
        #expect(registry.hasDefinition(for: "CGSize"))
    }

    // MARK: - Resolution Tests

    @Test("Resolve forward declaration to full definition")
    func resolveForwardDeclaration() {
        let registry = StructureRegistry()

        // Register full definition
        let fullDef = ObjCType.structure(
            name: ObjCTypeName(name: "CGPoint"),
            members: [
                ObjCTypedMember(type: .double, name: "x"),
                ObjCTypedMember(type: .double, name: "y"),
            ]
        )
        registry.register(fullDef)

        // Try to resolve a forward declaration
        let forwardDecl = ObjCType.structure(
            name: ObjCTypeName(name: "CGPoint"),
            members: []
        )
        let resolved = registry.resolve(forwardDecl)

        if case .structure(_, let members) = resolved {
            #expect(members.count == 2)
            #expect(members[0].name == "x")
            #expect(members[1].name == "y")
        } else {
            Issue.record("Expected resolved structure")
        }
    }

    @Test("Resolve nested forward declarations")
    func resolveNestedForwardDeclarations() {
        let registry = StructureRegistry()

        // Register definitions for CGPoint and CGSize
        registry.register(
            ObjCType.structure(
                name: ObjCTypeName(name: "CGPoint"),
                members: [
                    ObjCTypedMember(type: .double, name: "x"),
                    ObjCTypedMember(type: .double, name: "y"),
                ]
            ))
        registry.register(
            ObjCType.structure(
                name: ObjCTypeName(name: "CGSize"),
                members: [
                    ObjCTypedMember(type: .double, name: "width"),
                    ObjCTypedMember(type: .double, name: "height"),
                ]
            ))

        // Try to resolve CGRect with nested forward declarations
        let cgRect = ObjCType.structure(
            name: ObjCTypeName(name: "CGRect"),
            members: [
                ObjCTypedMember(
                    type: .structure(name: ObjCTypeName(name: "CGPoint"), members: []),
                    name: "origin"
                ),
                ObjCTypedMember(
                    type: .structure(name: ObjCTypeName(name: "CGSize"), members: []),
                    name: "size"
                ),
            ]
        )

        let resolved = registry.resolve(cgRect)

        if case .structure(_, let members) = resolved {
            #expect(members.count == 2)

            // Check origin was resolved
            if case .structure(_, let originMembers) = members[0].type {
                #expect(originMembers.count == 2)
            } else {
                Issue.record("Expected origin to be resolved")
            }

            // Check size was resolved
            if case .structure(_, let sizeMembers) = members[1].type {
                #expect(sizeMembers.count == 2)
            } else {
                Issue.record("Expected size to be resolved")
            }
        } else {
            Issue.record("Expected resolved structure")
        }
    }

    @Test("Returns original type if no definition available")
    func noResolutionWhenUndefined() {
        let registry = StructureRegistry()

        let forwardDecl = ObjCType.structure(
            name: ObjCTypeName(name: "UnknownStruct"),
            members: []
        )

        let resolved = registry.resolve(forwardDecl)

        #expect(resolved == forwardDecl)
    }

    @Test("Resolve through pointer types")
    func resolveThroughPointer() {
        let registry = StructureRegistry()

        registry.register(
            ObjCType.structure(
                name: ObjCTypeName(name: "Node"),
                members: [
                    ObjCTypedMember(type: .int, name: "value")
                ]
            ))

        let pointerToForward = ObjCType.pointer(
            .structure(name: ObjCTypeName(name: "Node"), members: [])
        )

        let resolved = registry.resolve(pointerToForward)

        if case .pointer(let pointee) = resolved,
            case .structure(_, let members) = pointee
        {
            #expect(members.count == 1)
        } else {
            Issue.record("Expected resolved pointer to structure")
        }
    }

    @Test("Handle circular structure references")
    func handleCircularReferences() {
        let registry = StructureRegistry()

        // Self-referential structure (like a linked list node)
        let node = ObjCType.structure(
            name: ObjCTypeName(name: "ListNode"),
            members: [
                ObjCTypedMember(type: .int, name: "value"),
                ObjCTypedMember(
                    type: .pointer(.structure(name: ObjCTypeName(name: "ListNode"), members: [])),
                    name: "next"
                ),
            ]
        )

        registry.register(node)

        // Should not infinite loop
        let resolved = registry.resolve(node)

        if case .structure(_, let members) = resolved {
            #expect(members.count == 2)
        } else {
            Issue.record("Expected resolved structure")
        }
    }

    // MARK: - Union Tests

    @Test("Register and resolve union types")
    func registerAndResolveUnion() {
        let registry = StructureRegistry()

        let unionDef = ObjCType.union(
            name: ObjCTypeName(name: "MyUnion"),
            members: [
                ObjCTypedMember(type: .int, name: "intValue"),
                ObjCTypedMember(type: .float, name: "floatValue"),
            ]
        )

        registry.register(unionDef)
        #expect(registry.hasDefinition(for: "MyUnion"))

        let forwardDecl = ObjCType.union(
            name: ObjCTypeName(name: "MyUnion"),
            members: []
        )

        let resolved = registry.resolve(forwardDecl)

        if case .union(_, let members) = resolved {
            #expect(members.count == 2)
        } else {
            Issue.record("Expected resolved union")
        }
    }

    // MARK: - ObjCType Extension Tests

    @Test("isForwardDeclaredStructure returns true for empty members")
    func isForwardDeclaredStructure() {
        let forward = ObjCType.structure(
            name: ObjCTypeName(name: "Test"),
            members: []
        )
        let full = ObjCType.structure(
            name: ObjCTypeName(name: "Test"),
            members: [ObjCTypedMember(type: .int, name: "x")]
        )

        #expect(forward.isForwardDeclaredStructure == true)
        #expect(full.isForwardDeclaredStructure == false)
    }

    @Test("structureName extracts name from structure")
    func structureNameExtraction() {
        let structure = ObjCType.structure(
            name: ObjCTypeName(name: "CGRect"),
            members: []
        )
        let notStructure = ObjCType.int

        #expect(structure.structureName == "CGRect")
        #expect(notStructure.structureName == nil)
    }

    @Test("hasCompleteDefinition returns true for non-empty members")
    func hasCompleteDefinition() {
        let forward = ObjCType.structure(
            name: ObjCTypeName(name: "Test"),
            members: []
        )
        let full = ObjCType.structure(
            name: ObjCTypeName(name: "Test"),
            members: [ObjCTypedMember(type: .int, name: "x")]
        )

        #expect(forward.hasCompleteDefinition == false)
        #expect(full.hasCompleteDefinition == true)
    }

    @Test("resolved(using:) convenience method works")
    func resolvedConvenienceMethod() {
        let registry = StructureRegistry()
        registry.register(
            ObjCType.structure(
                name: ObjCTypeName(name: "Point"),
                members: [
                    ObjCTypedMember(type: .double, name: "x"),
                    ObjCTypedMember(type: .double, name: "y"),
                ]
            ))

        let forward = ObjCType.structure(name: ObjCTypeName(name: "Point"), members: [])
        let resolved = forward.resolved(using: registry)

        if case .structure(_, let members) = resolved {
            #expect(members.count == 2)
        } else {
            Issue.record("Expected resolved structure")
        }
    }

    // MARK: - Typedef Tests

    @Test("Register and resolve typedefs")
    func typedefResolution() {
        let registry = StructureRegistry()

        registry.registerTypedef(alias: "MyTypedef", underlyingType: "int")

        #expect(registry.resolveTypedef("MyTypedef") == "int")
        #expect(registry.resolveTypedef("unknown") == nil)
    }

    @Test("Builtin typedefs are pre-populated")
    func builtinTypedefs() {
        let registry = StructureRegistry()

        // CGFloat should be pre-populated
        #expect(registry.resolveTypedef("CGFloat") == "double")

        // NSInteger/NSUInteger should be pre-populated
        #expect(registry.resolveTypedef("NSInteger") == "long")
        #expect(registry.resolveTypedef("NSUInteger") == "unsigned long")

        // Time interval types
        #expect(registry.resolveTypedef("CFTimeInterval") == "double")
        #expect(registry.resolveTypedef("NSTimeInterval") == "double")

        // CFIndex type
        #expect(registry.resolveTypedef("CFIndex") == "long")

        // OSStatus
        #expect(registry.resolveTypedef("OSStatus") == "int")
    }

    @Test("Check builtin typedef detection")
    func isBuiltinTypedef() {
        let registry = StructureRegistry()

        #expect(registry.isBuiltinTypedef("CGFloat"))
        #expect(registry.isBuiltinTypedef("NSInteger"))
        #expect(registry.isBuiltinTypedef("CFTimeInterval"))
        #expect(!registry.isBuiltinTypedef("CustomTypedef"))
    }

    @Test("Get all typedefs includes builtins and custom")
    func allTypedefs() {
        let registry = StructureRegistry()

        // Add a custom typedef
        registry.registerTypedef(alias: "MyType", underlyingType: "struct MyStruct")

        let all = registry.allTypedefs
        #expect(all["CGFloat"] == "double")
        #expect(all["MyType"] == "struct MyStruct")
    }

    // MARK: - Merge Tests

    @Test("Merge two registries")
    func mergeRegistries() {
        let registry1 = StructureRegistry()
        let registry2 = StructureRegistry()

        registry1.register(
            ObjCType.structure(
                name: ObjCTypeName(name: "StructA"),
                members: [ObjCTypedMember(type: .int, name: "a")]
            ))

        registry2.register(
            ObjCType.structure(
                name: ObjCTypeName(name: "StructB"),
                members: [ObjCTypedMember(type: .int, name: "b")]
            ))

        registry1.merge(registry2)

        #expect(registry1.definedCount == 2)
        #expect(registry1.hasDefinition(for: "StructA"))
        #expect(registry1.hasDefinition(for: "StructB"))
    }

    @Test("Merge keeps more complete definition")
    func mergeKeepsMoreComplete() {
        let registry1 = StructureRegistry()
        let registry2 = StructureRegistry()

        registry1.register(
            ObjCType.structure(
                name: ObjCTypeName(name: "MyStruct"),
                members: [ObjCTypedMember(type: .int, name: "a")]
            ))

        registry2.register(
            ObjCType.structure(
                name: ObjCTypeName(name: "MyStruct"),
                members: [
                    ObjCTypedMember(type: .int, name: "a"),
                    ObjCTypedMember(type: .int, name: "b"),
                ]
            ))

        registry1.merge(registry2)

        if let def = registry1.definition(for: "MyStruct"),
            case .structure(_, let members) = def
        {
            #expect(members.count == 2)
        } else {
            Issue.record("Expected merged definition with 2 members")
        }
    }

    // MARK: - Output Generation Tests

    @Test("Generate structure definitions output")
    func generateStructureDefinitions() {
        let registry = StructureRegistry()

        registry.register(
            ObjCType.structure(
                name: ObjCTypeName(name: "CGPoint"),
                members: [
                    ObjCTypedMember(type: .double, name: "x"),
                    ObjCTypedMember(type: .double, name: "y"),
                ]
            ))

        let output = registry.generateStructureDefinitions()

        #expect(output.contains("typedef"))
        #expect(output.contains("struct CGPoint"))
        #expect(output.contains("CGPoint"))
    }

    @Test("Empty registry generates empty output")
    func emptyRegistryOutput() {
        let registry = StructureRegistry()
        let output = registry.generateStructureDefinitions()
        #expect(output.isEmpty)
    }

    // MARK: - Thread Safety Tests

    @Test("Concurrent registration is thread-safe")
    func concurrentRegistration() async {
        let registry = StructureRegistry()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let structure = ObjCType.structure(
                        name: ObjCTypeName(name: "Struct\(i)"),
                        members: [ObjCTypedMember(type: .int, name: "value")]
                    )
                    registry.register(structure)
                }
            }
        }

        #expect(registry.definedCount == 100)
    }
}
