import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for SymbolGraphVisitor (DocC Symbol Graph output).
@Suite("Symbol Graph Visitor Tests")
struct SymbolGraphVisitorTests {

    // MARK: - Basic Output Tests

    @Test("Symbol Graph visitor produces valid JSON")
    func producesValidJSON() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestProtocol")
        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)

        // Manually trigger JSON generation
        visitor.didEndVisiting()

        // Parse JSON to verify it's valid
        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["metadata"] != nil)
        #expect(json["module"] != nil)
        #expect(json["symbols"] != nil)
        #expect(json["relationships"] != nil)
    }

    @Test("Symbol Graph includes correct format version")
    func includesFormatVersion() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let metadata = json["metadata"] as! [String: Any]
        let formatVersion = metadata["formatVersion"] as! [String: Any]

        #expect(formatVersion["major"] as? Int == 0)
        #expect(formatVersion["minor"] as? Int == 6)
        #expect(formatVersion["patch"] as? Int == 0)
        #expect(metadata["generator"] as? String == "class-dump")
    }

    @Test("Symbol Graph includes module info")
    func includesModuleInfo() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let module = json["module"] as! [String: Any]

        #expect(module["name"] != nil)
        #expect(module["platform"] != nil)
    }

    // MARK: - Protocol Tests

    @Test("Symbol Graph formats protocol as symbol")
    func formatsProtocolAsSymbol() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestProtocol")
        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]

        #expect(symbols.count == 1)

        let symbol = symbols[0]
        let identifier = symbol["identifier"] as! [String: Any]
        let kind = symbol["kind"] as! [String: Any]
        let names = symbol["names"] as! [String: Any]

        #expect(identifier["interfaceLanguage"] as? String == "objective-c")
        #expect(identifier["precise"] as? String == "c:objc(pl)TestProtocol")
        #expect(kind["identifier"] as? String == "protocol")
        #expect(names["title"] as? String == "TestProtocol")
        #expect(symbol["accessLevel"] as? String == "public")
    }

    @Test("Symbol Graph includes protocol conformance relationships")
    func includesProtocolConformanceRelationships() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestProtocol")
        let nsObjectProto = ObjCProtocol(name: "NSObject")
        proto.addAdoptedProtocol(nsObjectProto)

        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let relationships = json["relationships"] as! [[String: Any]]

        #expect(relationships.count == 1)
        #expect(relationships[0]["kind"] as? String == "conformsTo")
        #expect(relationships[0]["source"] as? String == "c:objc(pl)TestProtocol")
        #expect(relationships[0]["target"] as? String == "c:objc(pl)NSObject")
    }

    // MARK: - Class Tests

    @Test("Symbol Graph formats class as symbol")
    func formatsClassAsSymbol() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]

        #expect(symbols.count == 1)

        let symbol = symbols[0]
        let identifier = symbol["identifier"] as! [String: Any]
        let kind = symbol["kind"] as! [String: Any]
        let names = symbol["names"] as! [String: Any]

        #expect(identifier["interfaceLanguage"] as? String == "objective-c")
        #expect(identifier["precise"] as? String == "c:objc(cs)TestClass")
        #expect(kind["identifier"] as? String == "class")
        #expect(names["title"] as? String == "TestClass")
    }

    @Test("Symbol Graph includes inheritance relationships")
    func includesInheritanceRelationships() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let relationships = json["relationships"] as! [[String: Any]]

        let inheritsFrom = relationships.first { $0["kind"] as? String == "inheritsFrom" }
        #expect(inheritsFrom != nil)
        #expect(inheritsFrom?["source"] as? String == "c:objc(cs)TestClass")
        #expect(inheritsFrom?["target"] as? String == "c:objc(cs)NSObject")
    }

    @Test("Symbol Graph includes class protocol conformance")
    func includesClassProtocolConformance() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        let nscodingProto = ObjCProtocol(name: "NSCoding")
        objcClass.addAdoptedProtocol(nscodingProto)

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let relationships = json["relationships"] as! [[String: Any]]

        let conformsTo = relationships.first { $0["kind"] as? String == "conformsTo" }
        #expect(conformsTo != nil)
        #expect(conformsTo?["target"] as? String == "c:objc(pl)NSCoding")
    }

    // MARK: - Method Tests

    @Test("Symbol Graph formats class method as symbol")
    func formatsClassMethodAsSymbol() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "sharedInstance", typeString: "@16@0:8")
        visitor.visitClassMethod(method)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]

        // Should have class + method
        #expect(symbols.count == 2)

        let methodSymbol = symbols.first {
            ($0["kind"] as? [String: Any])?["identifier"] as? String == "typeMethod"
        }
        #expect(methodSymbol != nil)

        let identifier = methodSymbol?["identifier"] as? [String: Any]
        #expect(identifier?["precise"] as? String == "c:objc(cs)TestClass(cm)sharedInstance")
    }

    @Test("Symbol Graph formats instance method as symbol")
    func formatsInstanceMethodAsSymbol() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "doSomething", typeString: "v16@0:8")
        visitor.visitInstanceMethod(method, propertyState: VisitorPropertyState(properties: []))

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]

        let methodSymbol = symbols.first {
            ($0["kind"] as? [String: Any])?["identifier"] as? String == "method"
        }
        #expect(methodSymbol != nil)

        let identifier = methodSymbol?["identifier"] as? [String: Any]
        #expect(identifier?["precise"] as? String == "c:objc(cs)TestClass(im)doSomething")
    }

    @Test("Symbol Graph includes method memberOf relationships")
    func includesMethodMemberOfRelationships() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "test", typeString: "v16@0:8")
        visitor.visitClassMethod(method)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let relationships = json["relationships"] as! [[String: Any]]

        let memberOf = relationships.first { $0["kind"] as? String == "memberOf" }
        #expect(memberOf != nil)
        #expect(memberOf?["source"] as? String == "c:objc(cs)TestClass(cm)test")
        #expect(memberOf?["target"] as? String == "c:objc(cs)TestClass")
    }

    // MARK: - Protocol Method Tests

    @Test("Symbol Graph formats protocol required method")
    func formatsProtocolRequiredMethod() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestDelegate")
        visitor.willVisitProtocol(proto)

        let method = ObjCMethod(name: "delegateDidFinish", typeString: "v16@0:8")
        visitor.visitInstanceMethod(method, propertyState: VisitorPropertyState(properties: []))

        visitor.didVisitProtocol(proto)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let relationships = json["relationships"] as! [[String: Any]]

        let requirementOf = relationships.first { $0["kind"] as? String == "requirementOf" }
        #expect(requirementOf != nil)
        #expect(requirementOf?["target"] as? String == "c:objc(pl)TestDelegate")
    }

    @Test("Symbol Graph formats protocol optional method")
    func formatsProtocolOptionalMethod() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestDelegate")
        visitor.willVisitProtocol(proto)

        visitor.willVisitOptionalMethods()
        let method = ObjCMethod(name: "optionalCallback", typeString: "v16@0:8")
        visitor.visitInstanceMethod(method, propertyState: VisitorPropertyState(properties: []))
        visitor.didVisitOptionalMethods()

        visitor.didVisitProtocol(proto)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let relationships = json["relationships"] as! [[String: Any]]

        let optionalRequirementOf = relationships.first { $0["kind"] as? String == "optionalRequirementOf" }
        #expect(optionalRequirementOf != nil)
    }

    // MARK: - Property Tests

    @Test("Symbol Graph formats property as symbol")
    func formatsPropertyAsSymbol() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let property = ObjCProperty(name: "title", attributeString: "T@\"NSString\",C,N,V_title")
        visitor.visitProperty(property)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]

        let propertySymbol = symbols.first {
            ($0["kind"] as? [String: Any])?["identifier"] as? String == "property"
        }
        #expect(propertySymbol != nil)

        let identifier = propertySymbol?["identifier"] as? [String: Any]
        #expect(identifier?["precise"] as? String == "c:objc(cs)TestClass(py)title")
    }

    // MARK: - Instance Variable Tests

    @Test("Symbol Graph formats ivar as symbol")
    func formatsIvarAsSymbol() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let ivar = ObjCInstanceVariable(name: "_count", typeEncoding: "i", offset: 8)
        visitor.visitIvar(ivar)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]

        let ivarSymbol = symbols.first {
            ($0["kind"] as? [String: Any])?["identifier"] as? String == "ivar"
        }
        #expect(ivarSymbol != nil)

        let identifier = ivarSymbol?["identifier"] as? [String: Any]
        #expect(identifier?["precise"] as? String == "c:objc(cs)TestClass(ivar)_count")
        #expect(ivarSymbol?["accessLevel"] as? String == "internal")
    }

    // MARK: - Declaration Fragments Tests

    @Test("Symbol Graph includes declaration fragments for protocol")
    func includesDeclarationFragmentsForProtocol() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestProtocol")
        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]
        let fragments = symbols[0]["declarationFragments"] as? [[String: Any]]

        #expect(fragments != nil)
        #expect(fragments?.count ?? 0 > 0)

        // Should start with @protocol keyword
        let keywordFragment = fragments?.first { $0["kind"] as? String == "keyword" }
        #expect(keywordFragment?["spelling"] as? String == "@protocol")
    }

    @Test("Symbol Graph includes declaration fragments for class")
    func includesDeclarationFragmentsForClass() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")
        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]
        let fragments = symbols[0]["declarationFragments"] as? [[String: Any]]

        #expect(fragments != nil)

        // Should have @interface keyword
        let keywordFragment = fragments?.first { $0["kind"] as? String == "keyword" }
        #expect(keywordFragment?["spelling"] as? String == "@interface")

        // Should have type identifier for superclass
        let typeFragment = fragments?.first { $0["kind"] as? String == "typeIdentifier" }
        #expect(typeFragment?["spelling"] as? String == "NSObject")
    }

    // MARK: - Demangling Tests

    @Test("Symbol Graph demangles Swift class names")
    func demanglesSwiftClassNames() throws {
        var options = ClassDumpVisitorOptions()
        options.demangleStyle = .swift

        let visitor = SymbolGraphVisitor(options: options)
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "_TtC10TestModule9TestClass")
        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]
        let names = symbols[0]["names"] as! [String: Any]

        #expect(names["title"] as? String == "TestModule.TestClass")
    }

    @Test("Symbol Graph preserves raw names when demangling disabled")
    func preservesRawNamesWhenDemanglingDisabled() throws {
        var options = ClassDumpVisitorOptions()
        options.demangleStyle = .none

        let visitor = SymbolGraphVisitor(options: options)
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "_TtC10TestModule9TestClass")
        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]
        let names = symbols[0]["names"] as! [String: Any]

        #expect(names["title"] as? String == "_TtC10TestModule9TestClass")
    }

    // MARK: - Codable Tests

    @Test("Symbol Graph is decodable back to structures")
    func isDecodable() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")
        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)

        let proto = ObjCProtocol(name: "TestProtocol")
        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)

        visitor.didEndVisiting()

        // Decode the JSON back to our structures
        let data = visitor.resultString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SymbolGraph.self, from: data)

        #expect(decoded.metadata.formatVersion.major == 0)
        #expect(decoded.metadata.formatVersion.minor == 6)
        #expect(decoded.metadata.generator == "class-dump")
        #expect(decoded.symbols.count == 2)  // class + protocol
        #expect(decoded.relationships.count >= 1)  // at least inheritsFrom
    }

    // MARK: - Category Tests

    @Test("Symbol Graph handles categories by adding to base class")
    func handlesCategoriesByAddingToBaseClass() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let category = ObjCCategory(name: "Additions")
        category.classRef = ObjCClassReference(name: "NSString")

        visitor.willVisitCategory(category)

        let method = ObjCMethod(name: "addedMethod", typeString: "v16@0:8")
        visitor.visitInstanceMethod(method, propertyState: VisitorPropertyState(properties: []))

        visitor.didVisitCategory(category)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]
        let relationships = json["relationships"] as! [[String: Any]]

        // Should have method symbol
        #expect(symbols.count == 1)

        let methodSymbol = symbols[0]
        let identifier = methodSymbol["identifier"] as! [String: Any]
        #expect(identifier["precise"] as? String == "c:objc(cs)NSString(im)addedMethod")

        // Method should be memberOf NSString
        let memberOf = relationships.first { $0["kind"] as? String == "memberOf" }
        #expect(memberOf?["target"] as? String == "c:objc(cs)NSString")
    }

    // MARK: - Path Components Tests

    @Test("Symbol Graph includes correct path components")
    func includesCorrectPathComponents() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "doSomething:withValue:", typeString: "v16@0:8@16i24")
        visitor.visitClassMethod(method)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let symbols = json["symbols"] as! [[String: Any]]

        let classSymbol = symbols.first {
            ($0["kind"] as? [String: Any])?["identifier"] as? String == "class"
        }
        let methodSymbol = symbols.first {
            ($0["kind"] as? [String: Any])?["identifier"] as? String == "typeMethod"
        }

        #expect(classSymbol?["pathComponents"] as? [String] == ["TestClass"])
        #expect(methodSymbol?["pathComponents"] as? [String] == ["TestClass", "doSomething:withValue:"])
    }

    // MARK: - Merging Tests

    @Test("SymbolGraph.merge combines symbols from multiple graphs")
    func mergeCombinesSymbols() throws {
        // Create first graph with a class
        let visitor1 = SymbolGraphVisitor(options: .init())
        visitor1.willBeginVisiting()
        let class1 = ObjCClass(name: "ClassFromModule1")
        visitor1.willVisitClass(class1)
        visitor1.didVisitClass(class1)
        visitor1.didEndVisiting()

        let graph1 = try SymbolGraph.from(jsonData: visitor1.resultString.data(using: .utf8)!)

        // Create second graph with a different class
        let visitor2 = SymbolGraphVisitor(options: .init())
        visitor2.willBeginVisiting()
        let class2 = ObjCClass(name: "ClassFromModule2")
        visitor2.willVisitClass(class2)
        visitor2.didVisitClass(class2)
        visitor2.didEndVisiting()

        let graph2 = try SymbolGraph.from(jsonData: visitor2.resultString.data(using: .utf8)!)

        // Merge the graphs
        let merged = SymbolGraph.merge([graph1, graph2], moduleName: "MergedModule")

        #expect(merged.symbols.count == 2)
        #expect(merged.module.name == "MergedModule")

        let symbolNames = merged.symbols.map { $0.names.title }
        #expect(symbolNames.contains("ClassFromModule1"))
        #expect(symbolNames.contains("ClassFromModule2"))
    }

    @Test("SymbolGraph.merge deduplicates identical symbols")
    func mergeDeduplicatesSymbols() throws {
        // Create two graphs with the same class
        let visitor1 = SymbolGraphVisitor(options: .init())
        visitor1.willBeginVisiting()
        let class1 = ObjCClass(name: "SharedClass")
        visitor1.willVisitClass(class1)
        visitor1.didVisitClass(class1)
        visitor1.didEndVisiting()

        let graph1 = try SymbolGraph.from(jsonData: visitor1.resultString.data(using: .utf8)!)

        let visitor2 = SymbolGraphVisitor(options: .init())
        visitor2.willBeginVisiting()
        let class2 = ObjCClass(name: "SharedClass")
        visitor2.willVisitClass(class2)
        visitor2.didVisitClass(class2)
        visitor2.didEndVisiting()

        let graph2 = try SymbolGraph.from(jsonData: visitor2.resultString.data(using: .utf8)!)

        // Merge the graphs
        let merged = SymbolGraph.merge([graph1, graph2])

        // Should have only one symbol (deduplicated)
        #expect(merged.symbols.count == 1)
        #expect(merged.symbols[0].names.title == "SharedClass")
    }

    @Test("SymbolGraph.merge combines relationships")
    func mergeCombinesRelationships() throws {
        // Create first graph with inheritance
        let visitor1 = SymbolGraphVisitor(options: .init())
        visitor1.willBeginVisiting()
        let class1 = ObjCClass(name: "ChildClass1")
        class1.superclassRef = ObjCClassReference(name: "BaseClass")
        visitor1.willVisitClass(class1)
        visitor1.didVisitClass(class1)
        visitor1.didEndVisiting()

        let graph1 = try SymbolGraph.from(jsonData: visitor1.resultString.data(using: .utf8)!)

        // Create second graph with different inheritance
        let visitor2 = SymbolGraphVisitor(options: .init())
        visitor2.willBeginVisiting()
        let class2 = ObjCClass(name: "ChildClass2")
        class2.superclassRef = ObjCClassReference(name: "BaseClass")
        visitor2.willVisitClass(class2)
        visitor2.didVisitClass(class2)
        visitor2.didEndVisiting()

        let graph2 = try SymbolGraph.from(jsonData: visitor2.resultString.data(using: .utf8)!)

        // Merge the graphs
        let merged = SymbolGraph.merge([graph1, graph2])

        // Should have 2 inheritance relationships
        let inheritanceRels = merged.relationships.filter { $0.kind == "inheritsFrom" }
        #expect(inheritanceRels.count == 2)
    }

    @Test("SymbolGraph.merge tracks bystander modules")
    func mergeTracksBystanderModules() throws {
        // Create two graphs
        let visitor1 = SymbolGraphVisitor(options: .init())
        visitor1.willBeginVisiting()
        visitor1.didEndVisiting()

        var graph1 = try SymbolGraph.from(jsonData: visitor1.resultString.data(using: .utf8)!)
        // Manually set module name (normally set by processor)
        graph1 = SymbolGraph(
            metadata: graph1.metadata,
            module: SymbolGraph.Module(
                name: "Module1",
                platform: graph1.module.platform,
                bystanders: nil
            ),
            symbols: graph1.symbols,
            relationships: graph1.relationships
        )

        var graph2 = try SymbolGraph.from(jsonData: visitor1.resultString.data(using: .utf8)!)
        graph2 = SymbolGraph(
            metadata: graph2.metadata,
            module: SymbolGraph.Module(
                name: "Module2",
                platform: graph2.module.platform,
                bystanders: nil
            ),
            symbols: graph2.symbols,
            relationships: graph2.relationships
        )

        // Merge the graphs
        let merged = SymbolGraph.merge([graph1, graph2], moduleName: "MergedModule")

        // Bystanders should contain both original module names
        #expect(merged.module.bystanders?.contains("Module1") == true)
        #expect(merged.module.bystanders?.contains("Module2") == true)
    }

    @Test("SymbolGraph.merge handles empty input")
    func mergeHandlesEmptyInput() {
        let merged = SymbolGraph.merge([])

        #expect(merged.symbols.isEmpty)
        #expect(merged.relationships.isEmpty)
        #expect(merged.module.name == "Combined")
    }

    // MARK: - JSON Utilities Tests

    @Test("SymbolGraph round-trips through JSON")
    func roundTripsJSON() throws {
        let visitor = SymbolGraphVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "test", typeString: "v16@0:8")
        visitor.visitClassMethod(method)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        // Round-trip through JSON
        let original = try SymbolGraph.from(jsonData: visitor.resultString.data(using: .utf8)!)
        let jsonString = try original.jsonString()
        let restored = try SymbolGraph.from(jsonData: jsonString.data(using: .utf8)!)

        #expect(original.symbols.count == restored.symbols.count)
        #expect(original.relationships.count == restored.relationships.count)
        #expect(original.module.name == restored.module.name)
    }

    @Test("SymbolGraph.recommendedFilename follows Apple convention")
    func recommendedFilenameFollowsConvention() {
        let graph = SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.SemanticVersion(major: 0, minor: 6, patch: 0),
                generator: "class-dump"
            ),
            module: SymbolGraph.Module(
                name: "MyFramework",
                platform: SymbolGraph.Platform(operatingSystem: nil, architecture: nil, vendor: "apple"),
                bystanders: nil
            ),
            symbols: [],
            relationships: []
        )

        #expect(graph.recommendedFilename() == "MyFramework.symbols.json")
        #expect(graph.recommendedFilename(extendedModule: "Foundation") == "MyFramework@Foundation.symbols.json")
    }
}
