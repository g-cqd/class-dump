import Testing

@testable import ClassDumpCore

@Suite("MethodSignatureRegistry Tests")
struct MethodSignatureRegistryTests {

    // MARK: - Basic Registration

    @Test("Register and lookup method by selector")
    func registerAndLookup() {
        let registry = MethodSignatureRegistry()

        let method = ObjCMethod(
            name: "fetchWithCompletion:",
            typeString: "@24@0:8@?<v@?@>16",  // Block with signature
            address: 0
        )

        registry.registerMethod(method, source: .protocol("TestProtocol"))

        #expect(registry.hasSelector("fetchWithCompletion:"))
        #expect(!registry.hasSelector("nonExistentMethod"))
    }

    @Test("Get all selectors")
    func getAllSelectors() {
        let registry = MethodSignatureRegistry()

        let method1 = ObjCMethod(name: "method1:", typeString: "@24@0:8@16", address: 0)
        let method2 = ObjCMethod(name: "method2:", typeString: "@24@0:8@16", address: 0)

        registry.registerMethod(method1, source: .protocol("P"))
        registry.registerMethod(method2, source: .class("C"))

        let selectors = registry.allSelectors
        #expect(selectors.contains("method1:"))
        #expect(selectors.contains("method2:"))
        #expect(selectors.count == 2)
    }

    @Test("Method count reflects total registrations")
    func methodCount() {
        let registry = MethodSignatureRegistry()

        #expect(registry.methodCount == 0)

        let method = ObjCMethod(name: "test", typeString: "v16@0:8", address: 0)
        registry.registerMethod(method, source: .protocol("P"))

        #expect(registry.methodCount == 1)

        // Registering same selector from different source adds another entry
        registry.registerMethod(method, source: .class("C"))
        #expect(registry.methodCount == 2)
    }

    // MARK: - Block Signature Resolution

    @Test("Look up block signature for selector at argument position")
    func blockSignatureLookup() {
        let registry = MethodSignatureRegistry()

        // Method with block at argument position 0: void (^)(id)
        // Type encoding: @24@0:8@?<v@?@>16
        // - @ = return id
        // - @ = self
        // - : = _cmd
        // - @?<v@?@> = block returning void, taking block self and id
        let method = ObjCMethod(
            name: "fetchWithCompletion:",
            typeString: "@24@0:8@?<v@?@>16",
            address: 0
        )

        registry.registerMethod(method, source: .protocol("DataFetching"))

        let blockTypes = registry.blockSignature(forSelector: "fetchWithCompletion:", argumentIndex: 0)
        #expect(blockTypes != nil)
        #expect(blockTypes?.count == 3)  // void, @?, @

        // Check the types
        if let types = blockTypes {
            #expect(types[0] == .void)  // Return type
            #expect(types[1] == .block(types: nil))  // Block self
            #expect(types[2] == .id(className: nil, protocols: []))  // id parameter
        }
    }

    @Test("Block signature returns nil for non-block argument")
    func blockSignatureNonBlock() {
        let registry = MethodSignatureRegistry()

        // Method with id argument (not block)
        let method = ObjCMethod(
            name: "processObject:",
            typeString: "@24@0:8@16",  // Just id, no block
            address: 0
        )

        registry.registerMethod(method, source: .protocol("P"))

        let blockTypes = registry.blockSignature(forSelector: "processObject:", argumentIndex: 0)
        #expect(blockTypes == nil)
    }

    @Test("Block signature returns nil for unknown selector")
    func blockSignatureUnknownSelector() {
        let registry = MethodSignatureRegistry()

        let blockTypes = registry.blockSignature(forSelector: "unknownSelector:", argumentIndex: 0)
        #expect(blockTypes == nil)
    }

    @Test("Block signature returns nil for block without signature in registry")
    func blockSignatureEmptyBlockInRegistry() {
        let registry = MethodSignatureRegistry()

        // Method with block but no signature: @?
        let method = ObjCMethod(
            name: "doSomething:",
            typeString: "@24@0:8@?16",  // @? without <...>
            address: 0
        )

        registry.registerMethod(method, source: .protocol("P"))

        // Registry has the selector but the block has no signature
        let blockTypes = registry.blockSignature(forSelector: "doSomething:", argumentIndex: 0)
        #expect(blockTypes == nil)
    }

    // MARK: - Protocol Registration

    @Test("Register protocol registers all methods")
    func registerProtocol() {
        let registry = MethodSignatureRegistry()

        let proto = ObjCProtocol(name: "TestProtocol")
        proto.addClassMethod(ObjCMethod(name: "classMethod", typeString: "v16@0:8", address: 0))
        proto.addInstanceMethod(ObjCMethod(name: "instanceMethod:", typeString: "@24@0:8@16", address: 0))
        proto.addOptionalClassMethod(ObjCMethod(name: "optionalClass", typeString: "v16@0:8", address: 0))
        proto.addOptionalInstanceMethod(ObjCMethod(name: "optionalInstance:", typeString: "@24@0:8@16", address: 0))

        registry.registerProtocol(proto)

        #expect(registry.hasSelector("classMethod"))
        #expect(registry.hasSelector("instanceMethod:"))
        #expect(registry.hasSelector("optionalClass"))
        #expect(registry.hasSelector("optionalInstance:"))
        #expect(registry.methodCount == 4)
    }

    // MARK: - Source Priority

    @Test("Protocol sources are preferred over class sources")
    func protocolSourcePriority() {
        let registry = MethodSignatureRegistry()

        // Class has block without signature
        let classMethod = ObjCMethod(
            name: "fetchData:",
            typeString: "@24@0:8@?16",  // @? without signature
            address: 0
        )
        registry.registerMethod(classMethod, source: .class("DataManager"))

        // Protocol has block with signature
        let protoMethod = ObjCMethod(
            name: "fetchData:",
            typeString: "@24@0:8@?<v@?@\"NSData\">16",  // Block with NSData param
            address: 0
        )
        registry.registerMethod(protoMethod, source: .protocol("DataFetching"))

        // Should return the protocol's richer signature
        let blockTypes = registry.blockSignature(forSelector: "fetchData:", argumentIndex: 0)
        #expect(blockTypes != nil)
        #expect(blockTypes?.count == 3)
    }

    // MARK: - Method Types Lookup

    @Test("Lookup full method types for selector")
    func methodTypesLookup() {
        let registry = MethodSignatureRegistry()

        let method = ObjCMethod(
            name: "initWithFrame:",
            typeString: "@32@0:8{CGRect=dddd}16",
            address: 0
        )

        registry.registerMethod(method, source: .protocol("UIView"))

        let types = registry.methodTypes(forSelector: "initWithFrame:")
        #expect(types != nil)
        #expect(types?.count == 4)  // return (@), self (@), _cmd (:), arg1 ({CGRect})
    }

    @Test("Method types returns nil for unknown selector")
    func methodTypesUnknown() {
        let registry = MethodSignatureRegistry()

        let types = registry.methodTypes(forSelector: "unknownMethod:")
        #expect(types == nil)
    }

    // MARK: - Formatter Integration

    @Test("Formatter enhances empty block type using registry")
    func formatterEnhancesBlockType() {
        let registry = MethodSignatureRegistry()

        // Protocol has rich block signature
        let protoMethod = ObjCMethod(
            name: "fetchWithCompletion:",
            typeString: "@24@0:8@?<v@?@>16",  // Block: void (^)(id)
            address: 0
        )
        registry.registerMethod(protoMethod, source: .protocol("DataFetching"))

        // Formatter with registry
        var formatter = ObjCTypeFormatter()
        formatter.methodSignatureRegistry = registry

        // Method with empty block signature
        let classTypeString = "@24@0:8@?16"  // @? without <...>

        let result = formatter.formatMethodName("fetchWithCompletion:", typeString: classTypeString)
        #expect(result != nil)

        // The enhanced output should have the full block signature, not just "id /* block */"
        #expect(result!.contains("void (^)(id)"))
    }

    @Test("Formatter preserves existing block signature")
    func formatterPreservesExistingSignature() {
        let registry = MethodSignatureRegistry()

        // Protocol has one signature
        let protoMethod = ObjCMethod(
            name: "doWork:",
            typeString: "@24@0:8@?<v@?@>16",  // Block: void (^)(id)
            address: 0
        )
        registry.registerMethod(protoMethod, source: .protocol("P"))

        var formatter = ObjCTypeFormatter()
        formatter.methodSignatureRegistry = registry

        // Class method already has a (different) full block signature
        let classTypeString = "@24@0:8@?<v@?@@>16"  // Block: void (^)(id, id)

        let result = formatter.formatMethodName("doWork:", typeString: classTypeString)
        #expect(result != nil)

        // Should use the class's own signature, not the protocol's
        #expect(result!.contains("void (^)(id, id)"))
    }

    @Test("Formatter without registry shows block as id")
    func formatterWithoutRegistryShowsBlockAsId() {
        let formatter = ObjCTypeFormatter()

        // Method with empty block signature
        let typeString = "@24@0:8@?16"

        let result = formatter.formatMethodName("fetchWithCompletion:", typeString: typeString)
        #expect(result != nil)

        // Without registry, should show "id /* block */"
        #expect(result!.contains("id /* block */"))
    }
}
