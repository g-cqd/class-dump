import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjCMethod Tests", .serialized)
struct ObjCMethodTests {
    @Test("Method argument count")
    func argumentCount() {
        let method1 = ObjCMethod(name: "init", typeString: "@16@0:8")
        #expect(method1.argumentCount == 0)
        #expect(method1.isUnary)

        let method2 = ObjCMethod(name: "initWithFrame:", typeString: "@40@0:8{CGRect=dddd}16")
        #expect(method2.argumentCount == 1)
        #expect(!method2.isUnary)

        let method3 = ObjCMethod(name: "tableView:cellForRowAtIndexPath:", typeString: "@32@0:8@16@24")
        #expect(method3.argumentCount == 2)
    }

    @Test("Method comparison")
    func comparison() {
        let method1 = ObjCMethod(name: "aMethod", typeString: "v16@0:8")
        let method2 = ObjCMethod(name: "bMethod", typeString: "v16@0:8")
        #expect(method1 < method2)
    }
}

@Suite("ObjCProperty Tests", .serialized)
struct ObjCPropertyTests {
    @Test("Parse property attributes")
    func parseAttributes() {
        let property = ObjCProperty(name: "name", attributeString: "T@\"NSString\",C,N,V_name")
        #expect(property.name == "name")
        #expect(property.encodedType == "@\"NSString\"")
        #expect(property.isCopy)
        #expect(property.isNonatomic)
        #expect(!property.isReadOnly)
        #expect(!property.isWeak)
        #expect(property.ivarName == "_name")
    }

    @Test("Parse readonly property")
    func parseReadonly() {
        let property = ObjCProperty(name: "count", attributeString: "TQ,R,N")
        #expect(property.name == "count")
        #expect(property.encodedType == "Q")
        #expect(property.isReadOnly)
        #expect(property.isNonatomic)
        #expect(property.setter == nil)
    }

    @Test("Parse weak property")
    func parseWeak() {
        let property = ObjCProperty(name: "delegate", attributeString: "T@\"NSObject\",W,N,V_delegate")
        #expect(property.isWeak)
        #expect(!property.isRetain)
    }

    @Test("Custom getter and setter")
    func customAccessors() {
        let property = ObjCProperty(name: "enabled", attributeString: "TB,GisEnabled,SsetEnabled:,N")
        #expect(property.getter == "isEnabled")
        #expect(property.setter == "setEnabled:")
    }

    @Test("Default getter and setter")
    func defaultAccessors() {
        let property = ObjCProperty(name: "title", attributeString: "T@\"NSString\",&,N,V_title")
        #expect(property.getter == "title")
        #expect(property.setter == "setTitle:")
    }
}

@Suite("ObjCInstanceVariable Tests", .serialized)
struct ObjCInstanceVariableTests {
    @Test("Basic ivar")
    func basicIvar() {
        let ivar = ObjCInstanceVariable(name: "_name", typeString: "@\"NSString\"", offset: 8)
        #expect(ivar.name == "_name")
        #expect(ivar.typeString == "@\"NSString\"")
        #expect(ivar.offset == 8)
        #expect(ivar.isSynthesized)
    }

    @Test("Non-synthesized ivar")
    func nonSynthesized() {
        let ivar = ObjCInstanceVariable(name: "count", typeString: "Q", offset: 16)
        #expect(!ivar.isSynthesized)
    }

    @Test("Ivar comparison by offset")
    func comparison() {
        let ivar1 = ObjCInstanceVariable(name: "_a", typeString: "i", offset: 8)
        let ivar2 = ObjCInstanceVariable(name: "_b", typeString: "i", offset: 16)
        #expect(ivar1 < ivar2)
    }
}

@Suite("ObjCProtocol Tests", .serialized)
struct ObjCProtocolTests {
    @Test("Protocol creation")
    func creation() {
        let proto = ObjCProtocol(name: "NSCopying", address: 0x1000)
        #expect(proto.name == "NSCopying")
        #expect(proto.address == 0x1000)
    }

    @Test("Adding methods")
    func addMethods() {
        let proto = ObjCProtocol(name: "TestProtocol", address: 0)

        let instanceMethod = ObjCMethod(name: "doSomething", typeString: "v16@0:8")
        proto.addInstanceMethod(instanceMethod)

        let classMethod = ObjCMethod(name: "sharedInstance", typeString: "@16@0:8")
        proto.addClassMethod(classMethod)

        let optInstanceMethod = ObjCMethod(name: "optionalMethod", typeString: "v16@0:8")
        proto.addOptionalInstanceMethod(optInstanceMethod)

        #expect(proto.instanceMethods.count == 1)
        #expect(proto.classMethods.count == 1)
        #expect(proto.optionalInstanceMethods.count == 1)
        #expect(proto.hasMethods)
        #expect(proto.allMethods.count == 3)
    }

    @Test("Adopted protocols")
    func adoptedProtocols() {
        let proto = ObjCProtocol(name: "NSCopying", address: 0)
        let adopted = ObjCProtocol(name: "NSObject", address: 0)
        proto.addAdoptedProtocol(adopted)

        #expect(proto.adoptedProtocolNames == ["NSObject"])
        #expect(proto.adoptedProtocolsString == "<NSObject>")
    }
}

@Suite("ObjCClass Tests", .serialized)
struct ObjCClassTests {
    @Test("Class creation")
    func creation() {
        let aClass = ObjCClass(name: "MyClass", address: 0x2000)
        #expect(aClass.name == "MyClass")
        #expect(aClass.address == 0x2000)
        #expect(aClass.superclassName == nil)
    }

    @Test("Superclass reference")
    func superclass() {
        let aClass = ObjCClass(name: "MyClass", address: 0)
        aClass.superclassRef = ObjCClassReference(name: "NSObject", address: 0x1000)

        #expect(aClass.superclassName == "NSObject")
    }

    @Test("Adding members")
    func addMembers() {
        let aClass = ObjCClass(name: "TestClass", address: 0)

        let ivar = ObjCInstanceVariable(name: "_value", typeString: "Q", offset: 8)
        aClass.addInstanceVariable(ivar)

        let method = ObjCMethod(name: "doWork", typeString: "v16@0:8")
        aClass.addInstanceMethod(method)

        let classMethod = ObjCMethod(name: "className", typeString: "@16@0:8")
        aClass.addClassMethod(classMethod)

        let property = ObjCProperty(name: "value", attributeString: "TQ,N,V_value")
        aClass.addProperty(property)

        #expect(aClass.instanceVariables.count == 1)
        #expect(aClass.instanceMethods.count == 1)
        #expect(aClass.classMethods.count == 1)
        #expect(aClass.properties.count == 1)
        #expect(aClass.hasMethods)
        #expect(aClass.allMethods.count == 2)
    }

    @Test("Class description")
    func description() {
        let aClass = ObjCClass(name: "MyView", address: 0)
        aClass.superclassRef = ObjCClassReference(name: "UIView", address: 0)

        #expect(aClass.description.contains("@interface MyView : UIView"))
    }
}

@Suite("ObjCCategory Tests", .serialized)
struct ObjCCategoryTests {
    @Test("Category creation")
    func creation() {
        let category = ObjCCategory(name: "Private", address: 0x3000)
        #expect(category.name == "Private")
        #expect(category.address == 0x3000)
        #expect(category.className == nil)
    }

    @Test("Class reference")
    func classRef() {
        let category = ObjCCategory(name: "Additions", address: 0)
        category.classRef = ObjCClassReference(name: "NSString", address: 0)

        #expect(category.className == "NSString")
    }

    @Test("Category description")
    func description() {
        let category = ObjCCategory(name: "Private", address: 0)
        category.classRef = ObjCClassReference(name: "NSObject", address: 0)

        #expect(category.description.contains("@interface NSObject (Private)"))
    }
}

@Suite("ObjCClassReference Tests", .serialized)
struct ObjCClassReferenceTests {
    @Test("Internal reference")
    func internalRef() {
        let ref = ObjCClassReference(name: "MyClass", address: 0x1000)
        #expect(!ref.isExternal)
        #expect(ref.name == "MyClass")
    }

    @Test("External reference")
    func externalRef() {
        let ref = ObjCClassReference(name: "NSObject", address: 0)
        #expect(ref.isExternal)
    }
}

@Suite("ObjC2RuntimeStructs Tests", .serialized)
struct ObjC2RuntimeStructsTests {
    @Test("ObjC2ListHeader parsing")
    func listHeader() throws {
        var data = Data()
        // entsize = 24, count = 5
        data.append(contentsOf: [0x18, 0x00, 0x00, 0x00])  // entsize
        data.append(contentsOf: [0x05, 0x00, 0x00, 0x00])  // count

        var cursor = try DataCursor(data: data, offset: 0)
        let header = try ObjC2ListHeader(cursor: &cursor, byteOrder: .little)

        #expect(header.entsize == 24)
        #expect(header.count == 5)
        #expect(header.actualEntsize == 24)
    }

    @Test("ObjC2ListHeader with flags")
    func listHeaderWithFlags() throws {
        var data = Data()
        // entsize = 24 with flag bits set
        data.append(contentsOf: [0x1B, 0x00, 0x00, 0x00])  // entsize (24 | 3)
        data.append(contentsOf: [0x03, 0x00, 0x00, 0x00])  // count

        var cursor = try DataCursor(data: data, offset: 0)
        let header = try ObjC2ListHeader(cursor: &cursor, byteOrder: .little)

        #expect(header.entsize == 0x1B)
        #expect(header.actualEntsize == 24)  // flags masked out
        #expect(header.count == 3)
    }

    @Test("ObjC2ImageInfo parsing")
    func imageInfo() throws {
        var data = Data()
        // version = 0, flags = 0x42 (supports GC, signed class RO)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])  // version
        data.append(contentsOf: [0x42, 0x00, 0x00, 0x00])  // flags

        var cursor = try DataCursor(data: data, offset: 0)
        let imageInfo = try ObjC2ImageInfo(cursor: &cursor, byteOrder: .little)

        #expect(imageInfo.version == 0)
        #expect(imageInfo.flags == 0x42)
        #expect(imageInfo.parsedFlags.contains(.supportsGC))
    }

    @Test("ObjC2Class Swift flag")
    func classSwiftFlag() throws {
        var data = Data()
        // 64-bit class structure with Swift bit set in data pointer
        for _ in 0..<4 {  // isa, superclass, cache, vtable
            data.append(contentsOf: [0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        }
        // data pointer with Swift bit (bit 0) set
        data.append(contentsOf: [0x01, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // reserved1, reserved2, reserved3
        for _ in 0..<3 {
            data.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        }

        var cursor = try DataCursor(data: data, offset: 0)
        let objc2Class = try ObjC2Class(cursor: &cursor, byteOrder: .little, is64Bit: true)

        #expect(objc2Class.isSwiftClass)
        #expect(objc2Class.dataPointer == 0x2000)  // bits stripped
    }
}

@Suite("ObjCMetadata Tests", .serialized)
struct ObjCMetadataTests {
    @Test("Empty metadata")
    func emptyMetadata() {
        let metadata = ObjCMetadata()
        #expect(metadata.classes.isEmpty)
        #expect(metadata.protocols.isEmpty)
        #expect(metadata.categories.isEmpty)
        #expect(metadata.imageInfo == nil)
    }

    @Test("Sorted metadata")
    func sortedMetadata() {
        let class1 = ObjCClass(name: "ZClass", address: 0)
        let class2 = ObjCClass(name: "AClass", address: 0)

        let proto1 = ObjCProtocol(name: "ZProtocol", address: 0)
        let proto2 = ObjCProtocol(name: "AProtocol", address: 0)

        let metadata = ObjCMetadata(
            classes: [class1, class2],
            protocols: [proto1, proto2],
            categories: []
        )

        let sorted = metadata.sorted()
        #expect(sorted.classes[0].name == "AClass")
        #expect(sorted.classes[1].name == "ZClass")
        #expect(sorted.protocols[0].name == "AProtocol")
        #expect(sorted.protocols[1].name == "ZProtocol")
    }
}
