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
