import Testing

@testable import ClassDumpCore

@Suite("Visitor Tests")
struct TestVisitor {
    // MARK: - VisitorPropertyState Tests

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

    // MARK: - VisitorMachOFileInfo Tests

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

    // MARK: - ObjCProcessorInfo Tests

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

    // MARK: - ClassDumpVisitorOptions Tests

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

    // MARK: - DylibInfo Tests

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

    // MARK: - ClassReferenceInfo Tests

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

    // MARK: - TextClassDumpVisitor Tests

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

    // MARK: - ClassDumpHeaderVisitor Tests

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

    // MARK: - ObjCClass Visitor Extensions

    @Test("ObjCClass protocols extension")
    func objcClassProtocols() {
        let cls = ObjCClass(name: "TestClass")
        let proto1 = ObjCProtocol(name: "NSCoding")
        let proto2 = ObjCProtocol(name: "NSCopying")
        cls.addAdoptedProtocol(proto1)
        cls.addAdoptedProtocol(proto2)

        #expect(cls.protocols.count == 2)
        #expect(cls.protocols.contains("NSCoding"))
        #expect(cls.protocols.contains("NSCopying"))
    }

    // MARK: - ObjCCategory Visitor Extensions

    @Test("ObjCCategory classNameForVisitor")
    func objcCategoryClassName() {
        let category = ObjCCategory(name: "Helper")
        category.classRef = ObjCClassReference(name: "NSString")
        #expect(category.classNameForVisitor == "NSString")

        let categoryNoClass = ObjCCategory(name: "Unknown")
        #expect(categoryNoClass.classNameForVisitor == "")
    }

    @Test("ObjCCategory protocols extension")
    func objcCategoryProtocols() {
        let category = ObjCCategory(name: "Helper")
        category.classRef = ObjCClassReference(name: "NSString")
        let proto = ObjCProtocol(name: "NSSecureCoding")
        category.addAdoptedProtocol(proto)

        #expect(category.protocols.count == 1)
        #expect(category.protocols.first == "NSSecureCoding")
    }

    // MARK: - ObjCProtocol Visitor Extensions

    @Test("ObjCProtocol protocols extension")
    func objcProtocolProtocols() {
        let proto = ObjCProtocol(name: "MyProtocol")
        let nsObjectProto = ObjCProtocol(name: "NSObject")
        proto.addAdoptedProtocol(nsObjectProto)

        #expect(proto.protocols.count == 1)
        #expect(proto.protocols.first == "NSObject")
    }

    // MARK: - ObjCMethod Visitor Extensions

    @Test("ObjCMethod typeEncoding alias")
    func methodTypeEncoding() {
        let method = ObjCMethod(name: "test", typeString: "v16@0:8")
        #expect(method.typeEncoding == "v16@0:8")
    }

    @Test("ObjCMethod parsedTypes")
    func methodParsedTypes() {
        let method = ObjCMethod(name: "test", typeString: "v16@0:8")
        let types = method.parsedTypes

        #expect(types != nil)
        #expect(types?.count == 3)
        #expect(types?[0].type == .void)
    }

    @Test("ObjCMethod returnType")
    func methodReturnType() {
        let method = ObjCMethod(name: "getValue", typeString: "i16@0:8")
        #expect(method.returnType == .int)
    }

    @Test("ObjCMethod argumentTypes")
    func methodArgumentTypes() {
        let method = ObjCMethod(name: "setValue:", typeString: "v24@0:8i16")
        let args = method.argumentTypes

        #expect(args.count == 1)
        #expect(args[0] == .int)
    }

    // MARK: - ObjCInstanceVariable Visitor Extensions

    @Test("ObjCInstanceVariable typeEncoding property")
    func ivarTypeEncoding() {
        let ivar = ObjCInstanceVariable(name: "_value", typeEncoding: "i", offset: 8)
        #expect(ivar.typeEncoding == "i")
    }

    @Test("ObjCInstanceVariable parsedType")
    func ivarParsedType() {
        let ivar = ObjCInstanceVariable(name: "_string", typeEncoding: "@\"NSString\"", offset: 8)
        #expect(ivar.parsedType == .id(className: "NSString", protocols: []))
    }

    // MARK: - ObjCProperty Visitor Extensions

    @Test("ObjCProperty parsedType")
    func propertyParsedType() {
        let property = ObjCProperty(name: "name", attributeString: "T@\"NSString\",R,C,V_name")
        let type = property.parsedType

        #expect(type == .id(className: "NSString", protocols: []))
    }

    @Test("ObjCProperty attributeComponents")
    func propertyAttributeComponents() {
        let property = ObjCProperty(name: "count", attributeString: "Tq,N,V_count")
        let components = property.attributeComponents

        #expect(components.count == 3)
        #expect(components[0] == "Tq")
        #expect(components[1] == "N")
        #expect(components[2] == "V_count")
    }

    // MARK: - Protocol Demangling in Visitor Output Tests

    @Test("Protocol names demangled in class declaration - swift style")
    func protocolDemangledInClassSwiftStyle() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        // Correct mangled format: _TtC<module_len><module><class_len><class>
        // "MyModule" = 8 chars, "MyClass" = 7 chars
        let cls = ObjCClass(name: "_TtC8MyModule7MyClass")
        // Add a Swift protocol with mangled name
        let swiftProto = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        cls.addAdoptedProtocol(swiftProto)

        visitor.willVisitClass(cls)

        // Should demangle both class name and protocol name
        #expect(visitor.resultString.contains("MyModule.MyClass"))
        #expect(visitor.resultString.contains("Foundation.Hashable"))
        #expect(!visitor.resultString.contains("_TtP"))
    }

    @Test("Protocol names demangled in class declaration - objc style")
    func protocolDemangledInClassObjCStyle() {
        let options = ClassDumpVisitorOptions(demangleStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)

        // "MyModule" = 8 chars, "MyClass" = 7 chars
        let cls = ObjCClass(name: "_TtC8MyModule7MyClass")
        let swiftProto = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        cls.addAdoptedProtocol(swiftProto)

        visitor.willVisitClass(cls)

        // ObjC style should strip module prefix
        #expect(visitor.resultString.contains("MyClass"))
        #expect(visitor.resultString.contains("Hashable"))
        #expect(!visitor.resultString.contains("MyModule."))
        #expect(!visitor.resultString.contains("Foundation."))
    }

    @Test("Protocol names not demangled when style is none")
    func protocolNotDemangledWhenStyleNone() {
        let options = ClassDumpVisitorOptions(demangleStyle: .none)
        let visitor = TextClassDumpVisitor(options: options)

        // "MyModule" = 8 chars, "MyClass" = 7 chars
        let cls = ObjCClass(name: "_TtC8MyModule7MyClass")
        let swiftProto = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        cls.addAdoptedProtocol(swiftProto)

        visitor.willVisitClass(cls)

        // Should keep mangled names
        #expect(visitor.resultString.contains("_TtC8MyModule7MyClass"))
        #expect(visitor.resultString.contains("_TtP10Foundation8Hashable_"))
    }

    @Test("Multiple protocols demangled in class declaration")
    func multipleProtocolsDemangledInClass() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let cls = ObjCClass(name: "TestClass")
        let proto1 = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        let proto2 = ObjCProtocol(name: "_TtP10Foundation9Equatable_")
        let proto3 = ObjCProtocol(name: "NSCoding")  // ObjC protocol, not mangled
        cls.addAdoptedProtocol(proto1)
        cls.addAdoptedProtocol(proto2)
        cls.addAdoptedProtocol(proto3)

        visitor.willVisitClass(cls)

        #expect(visitor.resultString.contains("Foundation.Hashable"))
        #expect(visitor.resultString.contains("Foundation.Equatable"))
        #expect(visitor.resultString.contains("NSCoding"))
    }

    @Test("Protocol parent protocols demangled")
    func protocolParentProtocolsDemangled() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let proto = ObjCProtocol(name: "_TtP8MyModule10MyProtocol_")
        let parentProto = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        proto.addAdoptedProtocol(parentProto)

        visitor.willVisitProtocol(proto)

        // Protocol name and parent protocol should both be demangled
        #expect(visitor.resultString.contains("@protocol MyModule.MyProtocol"))
        #expect(visitor.resultString.contains("<Foundation.Hashable>"))
    }

    @Test("Category protocols demangled")
    func categoryProtocolsDemangled() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let category = ObjCCategory(name: "SwiftAdditions")
        category.classRef = ObjCClassReference(name: "NSObject")
        let swiftProto = ObjCProtocol(name: "_TtP8MyModule12MyProtocol01_")
        category.addAdoptedProtocol(swiftProto)

        visitor.willVisitCategory(category)

        #expect(visitor.resultString.contains("@interface NSObject (SwiftAdditions)"))
        #expect(visitor.resultString.contains("MyModule.MyProtocol01"))
    }

    @Test("Long protocol name demangled correctly")
    func longProtocolNameDemangled() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let cls = ObjCClass(name: "TestClass")
        // Real-world example from XCSourceControl
        let proto = ObjCProtocol(name: "_TtP15XCSourceControl30XCSourceControlXPCBaseProtocol_")
        cls.addAdoptedProtocol(proto)

        visitor.willVisitClass(cls)

        #expect(visitor.resultString.contains("XCSourceControl.XCSourceControlXPCBaseProtocol"))
    }
}
