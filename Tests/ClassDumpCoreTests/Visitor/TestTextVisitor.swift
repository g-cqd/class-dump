// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - VisitorPropertyState Tests

@Suite("VisitorPropertyState Tests")
struct VisitorPropertyStateTests {
    @Test("Property state initialization")
    func propertyStateInit() {
        let properties = [
            ObjCProperty(name: "name", attributeString: "T@\"NSString\",R,C,V_name"),
            ObjCProperty(name: "count", attributeString: "Tq,N,V_count"),
        ]

        let state = VisitorPropertyState(properties: properties)
        #expect(state.remainingProperties.count == 2)
    }

    @Test("Property state tracks by accessor")
    func propertyStateAccessor() {
        let property = ObjCProperty(name: "name", attributeString: "T@\"NSString\",R,C,V_name")
        let state = VisitorPropertyState(properties: [property])

        // Getter should find the property
        let found = state.property(forAccessor: "name")
        #expect(found != nil)
        #expect(found?.name == "name")
    }

    @Test("Property state marks used")
    func propertyStateUsed() {
        let property = ObjCProperty(name: "test", attributeString: "Ti,V_test")
        let state = VisitorPropertyState(properties: [property])

        #expect(!state.hasUsedProperty(property))
        state.useProperty(property)
        #expect(state.hasUsedProperty(property))
        #expect(state.remainingProperties.isEmpty)
    }
}

// MARK: - VisitorMachOFileInfo Tests

@Suite("VisitorMachOFileInfo Tests")
struct VisitorMachOFileInfoTests {
    @Test("VisitorMachOFileInfo initialization")
    func machOFileInfoInit() {
        let info = VisitorMachOFileInfo(
            filename: "/path/to/file",
            archName: "arm64"
        )

        #expect(info.filename == "/path/to/file")
        #expect(info.archName == "arm64")
        #expect(info.uuid == nil)
        #expect(!info.isEncrypted)
    }

    @Test("VisitorMachOFileInfo with dylib")
    func machOFileInfoDylib() {
        let dylib = DylibInfo(
            name: "libTest.dylib",
            currentVersion: "1.0.0",
            compatibilityVersion: "1.0.0"
        )

        let info = VisitorMachOFileInfo(
            filename: "/usr/lib/libTest.dylib",
            archName: "x86_64",
            filetype: 6,  // MH_DYLIB
            dylibIdentifier: dylib
        )

        #expect(info.filetype == 6)
        #expect(info.dylibIdentifier?.name == "libTest.dylib")
    }
}

// MARK: - ObjCProcessorInfo Tests

@Suite("ObjCProcessorInfo Tests")
struct ObjCProcessorInfoTests {
    @Test("ObjCProcessorInfo creation")
    func processorInfoCreation() {
        let machOFile = VisitorMachOFileInfo(
            filename: "Test.app",
            archName: "arm64"
        )

        let info = ObjCProcessorInfo(
            machOFile: machOFile,
            hasObjectiveCRuntimeInfo: true,
            garbageCollectionStatus: nil
        )

        #expect(info.hasObjectiveCRuntimeInfo)
        #expect(info.garbageCollectionStatus == nil)
    }
}

// MARK: - ClassDumpVisitorOptions Tests

@Suite("ClassDumpVisitorOptions Tests")
struct ClassDumpVisitorOptionsTests {
    @Test("ClassDumpVisitorOptions defaults")
    func visitorOptionsDefaults() {
        let options = ClassDumpVisitorOptions()

        #expect(options.shouldShowStructureSection)
        #expect(options.shouldShowProtocolSection)
    }

    @Test("ClassDumpVisitorOptions custom")
    func visitorOptionsCustom() {
        let options = ClassDumpVisitorOptions(
            shouldShowStructureSection: false,
            shouldShowProtocolSection: false
        )

        #expect(!options.shouldShowStructureSection)
        #expect(!options.shouldShowProtocolSection)
    }
}

// MARK: - DylibInfo Tests

@Suite("DylibInfo Tests")
struct DylibInfoTests {
    @Test("DylibInfo creation")
    func dylibInfoCreation() {
        let info = DylibInfo(
            name: "MyLib",
            currentVersion: "2.5.0",
            compatibilityVersion: "1.0.0"
        )

        #expect(info.name == "MyLib")
        #expect(info.currentVersion == "2.5.0")
        #expect(info.compatibilityVersion == "1.0.0")
    }
}

// MARK: - ClassReferenceInfo Tests

@Suite("ClassReferenceInfo Tests")
struct ClassReferenceInfoTests {
    @Test("ClassReferenceInfo external")
    func classReferenceExternal() {
        let ref = ClassReferenceInfo(
            isExternal: true,
            className: "NSObject",
            frameworkName: "Foundation"
        )

        #expect(ref.isExternal)
        #expect(ref.className == "NSObject")
        #expect(ref.frameworkName == "Foundation")
    }

    @Test("ClassReferenceInfo internal")
    func classReferenceInternal() {
        let ref = ClassReferenceInfo(
            isExternal: false,
            className: "MyClass",
            frameworkName: nil
        )

        #expect(!ref.isExternal)
        #expect(ref.className == "MyClass")
        #expect(ref.frameworkName == nil)
    }
}

// MARK: - TextClassDumpVisitor Tests

@Suite("TextClassDumpVisitor Tests")
struct TextClassDumpVisitorTests {
    @Test("TextClassDumpVisitor basic output")
    func textVisitorBasicOutput() {
        let visitor = TextClassDumpVisitor()

        visitor.append("Hello")
        visitor.append(" World")

        #expect(visitor.resultString == "Hello World")
    }

    @Test("TextClassDumpVisitor clear")
    func textVisitorClear() {
        let visitor = TextClassDumpVisitor()

        visitor.append("Test")
        visitor.clearResult()

        #expect(visitor.resultString.isEmpty)
    }

    @Test("TextClassDumpVisitor newline")
    func textVisitorNewline() {
        let visitor = TextClassDumpVisitor()

        visitor.append("Line 1")
        visitor.appendNewline()
        visitor.append("Line 2")

        #expect(visitor.resultString == "Line 1\nLine 2")
    }
}

// MARK: - ClassDumpHeaderVisitor Tests

@Suite("ClassDumpHeaderVisitor Tests")
struct ClassDumpHeaderVisitorTests {
    @Test("ClassDumpHeaderVisitor header generation")
    func headerVisitorGeneration() {
        let header = ClassDumpHeaderVisitor.generateHeader(
            generatedBy: "test-tool",
            version: "1.0"
        )

        #expect(header.contains("Generated by test-tool 1.0"))
        #expect(header.contains("Copyright"))
    }

    @Test("ClassDumpHeaderVisitor without version")
    func headerVisitorNoVersion() {
        let header = ClassDumpHeaderVisitor.generateHeader(
            generatedBy: "class-dump"
        )

        #expect(header.contains("Generated by class-dump"))
        #expect(!header.contains("1.0"))
    }
}
