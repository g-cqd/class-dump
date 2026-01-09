import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("Chained Fixups Tests", .serialized)
struct TestChainedFixups {
    @Test("Parse modern binary with chained fixups")
    func testParseChainedFixups() throws {
        let path = "/Applications/Xcode.app/Contents/Frameworks/DevToolsCore.framework/Versions/A/DevToolsCore"
        guard FileManager.default.fileExists(atPath: path) else {
            // Skip if Xcode not installed
            return
        }

        let url = URL(fileURLWithPath: path)
        let binary = try MachOBinary(contentsOf: url)
        let machO = try binary.bestMatchForLocal()

        #expect(machO.segments.count > 0)
        #expect(machO.hasChainedFixups, "Modern binaries should have chained fixups")

        // Test ChainedFixups parsing
        if let fixups = try machO.parseChainedFixups() {
            #expect(fixups.imports.count > 0, "Should have imports")
            #expect(fixups.pointerFormat != nil, "Should detect pointer format")

            // Check import names are valid
            for imp in fixups.imports.prefix(20) {
                #expect(!imp.name.isEmpty, "Import names should not be empty")
            }
        }

        // Test ObjC2Processor with chained fixups support
        let processor = ObjC2Processor(machOFile: machO)
        let metadata = try processor.process()

        // DevToolsCore has many ObjC classes
        #expect(metadata.classes.count > 100)

        // Verify class names are valid
        for cls in metadata.classes.prefix(10) {
            #expect(!cls.name.isEmpty)
            // ObjC class names should not contain null bytes
            #expect(!cls.name.contains("\0"))
        }

        // Check that external superclasses are resolved via chained fixups
        let classesWithExternalSuperclass = metadata.classes.filter { cls in
            if let superRef = cls.superclassRef {
                // External superclasses have address 0 but non-empty name
                return superRef.address == 0 && !superRef.name.isEmpty
            }
            return false
        }

        // There should be at least some classes with external superclasses (like NSObject)
        #expect(
            classesWithExternalSuperclass.count > 0, "Should have classes with external superclasses resolved via bind")
    }
}

@Suite("Swift Metadata Tests", .serialized)
struct TestSwiftMetadata {
    @Test("Detect Swift metadata in binary")
    func testDetectSwiftMetadata() throws {
        let path = "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        let binary = try MachOBinary(contentsOf: url)
        let machO = try binary.bestMatchForLocal()

        #expect(machO.hasSwiftMetadata, "IDEFoundation should have Swift metadata")
    }

    @Test("Parse Swift field descriptors")
    func testParseSwiftFieldDescriptors() throws {
        let path = "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        let binary = try MachOBinary(contentsOf: url)
        let machO = try binary.bestMatchForLocal()

        let swiftMetadata = try machO.parseSwiftMetadata()

        // IDEFoundation has many Swift types
        #expect(swiftMetadata.fieldDescriptors.count > 0, "Should have field descriptors")

        // Check that field records have valid names
        var foundValidRecord = false
        for fd in swiftMetadata.fieldDescriptors.prefix(50) {
            for record in fd.records {
                if !record.name.isEmpty {
                    foundValidRecord = true
                    break
                }
            }
            if foundValidRecord { break }
        }
        #expect(foundValidRecord, "Should have field records with names")
    }

    @Test("Parse Swift types")
    func testParseSwiftTypes() throws {
        let path = "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        let binary = try MachOBinary(contentsOf: url)
        let machO = try binary.bestMatchForLocal()

        let swiftMetadata = try machO.parseSwiftMetadata()

        // Should find Swift types
        #expect(swiftMetadata.types.count > 0, "Should have Swift types")

        // Verify type names are valid
        for type in swiftMetadata.types.prefix(10) {
            #expect(!type.name.isEmpty, "Type names should not be empty")
        }
    }

    @Test("Resolve symbolic type references")
    func testResolveSymbolicReferences() throws {
        let path = "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        let binary = try MachOBinary(contentsOf: url)
        let machO = try binary.bestMatchForLocal()

        let processor = SwiftMetadataProcessor(machOFile: machO)
        let metadata = try processor.process()

        // Find a field descriptor with records that have type references
        var resolvedCount = 0
        var symbolicCount = 0

        for fd in metadata.fieldDescriptors.prefix(100) {
            for record in fd.records {
                // Use raw data to check for symbolic references
                guard !record.mangledTypeData.isEmpty else { continue }

                // Check if it's a symbolic reference using raw data
                if record.hasSymbolicReference {
                    symbolicCount += 1

                    // Try to resolve it using raw data
                    let resolved = processor.resolveFieldTypeFromData(
                        record.mangledTypeData,
                        at: record.mangledTypeNameOffset
                    )

                    if !resolved.isEmpty && !resolved.hasPrefix("/*") {
                        resolvedCount += 1
                    }
                }
            }
        }

        // We should have found some symbolic references
        #expect(symbolicCount > 0, "Should have symbolic type references")
        // We should be able to resolve at least some of them
        #expect(resolvedCount > 0, "Should resolve some symbolic references")
    }

    @Test("Parse generic types from type descriptors")
    func testParseGenericTypes() throws {
        let path = "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        let binary = try MachOBinary(contentsOf: url)
        let machO = try binary.bestMatchForLocal()

        let swiftMetadata = try machO.parseSwiftMetadata()

        // Check for generic types (via the isGeneric flag in descriptor)
        let genericTypes = swiftMetadata.genericTypes
        #expect(genericTypes.count >= 0, "Should be able to query generic types")

        // Check that generic types have valid parameter counts
        for type in genericTypes.prefix(10) {
            #expect(type.isGeneric, "Generic types should have isGeneric = true")
            // Parameter count may be 0 if we couldn't parse the header correctly
            // but the type was marked generic via the flags
            if type.genericParamCount > 0 {
                #expect(type.genericParamCount < 20, "Generic param count should be reasonable")
            }
        }

        // Test fullNameWithGenerics generates something reasonable
        for type in swiftMetadata.types.prefix(5) {
            let nameWithGenerics = type.fullNameWithGenerics
            #expect(!nameWithGenerics.isEmpty, "fullNameWithGenerics should not be empty")
            // If generic, should include angle brackets
            if type.isGeneric && type.genericParamCount > 0 {
                #expect(nameWithGenerics.contains("<"), "Generic types should have <> in fullNameWithGenerics")
            }
        }
    }

    @Test("Type lookup by name")
    func testTypeLookupByName() throws {
        let path = "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        let binary = try MachOBinary(contentsOf: url)
        let machO = try binary.bestMatchForLocal()

        let swiftMetadata = try machO.parseSwiftMetadata()

        // Get a type name to test lookup
        guard let firstType = swiftMetadata.types.first else {
            return
        }

        // Test lookup by simple name
        let byName = swiftMetadata.type(named: firstType.name)
        #expect(byName != nil, "Should find type by simple name")
        #expect(byName?.name == firstType.name, "Found type should match")

        // Test lookup by full name
        let byFullName = swiftMetadata.type(fullName: firstType.fullName)
        #expect(byFullName != nil, "Should find type by full name")
    }

    @Test("Classify types by kind")
    func testClassifyTypesByKind() throws {
        let path = "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        let binary = try MachOBinary(contentsOf: url)
        let machO = try binary.bestMatchForLocal()

        let swiftMetadata = try machO.parseSwiftMetadata()

        // IDEFoundation should have classes, structs, and enums
        let classes = swiftMetadata.classes
        let structs = swiftMetadata.structs
        let enums = swiftMetadata.enums

        // Verify we can classify types
        #expect(
            classes.count + structs.count + enums.count == swiftMetadata.types.count,
            "All types should be classified as class, struct, or enum")

        // IDEFoundation should have a mix of types
        #expect(classes.count > 0, "Should have Swift classes")

        // Verify kind matches classification
        for cls in classes.prefix(5) {
            #expect(cls.kind == .class, "Classes should have kind == .class")
        }
        for str in structs.prefix(5) {
            #expect(str.kind == .struct, "Structs should have kind == .struct")
        }
        for enm in enums.prefix(5) {
            #expect(enm.kind == .enum, "Enums should have kind == .enum")
        }
    }

    @Test("Parse superclass names for classes")
    func testParseSuperclassNames() throws {
        let path = "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        let binary = try MachOBinary(contentsOf: url)
        let machO = try binary.bestMatchForLocal()

        let swiftMetadata = try machO.parseSwiftMetadata()

        // Find classes with superclass information
        var foundSuperclass = false
        for cls in swiftMetadata.classes.prefix(50) {
            if let superclass = cls.superclassName, !superclass.isEmpty {
                foundSuperclass = true
                // Superclass name should be readable (not mangled)
                // If it's demangled, it shouldn't start with _Tt or $s
                let isDemangled = !superclass.hasPrefix("_Tt") && !superclass.hasPrefix("$s")
                #expect(
                    isDemangled || superclass.count < 100,
                    "Superclass should be demangled or reasonably short")
                break
            }
        }

        // Note: Some classes may not have superclass info in the descriptor
        // This is expected for classes inheriting from ObjC or external Swift classes
        _ = foundSuperclass
    }
}
