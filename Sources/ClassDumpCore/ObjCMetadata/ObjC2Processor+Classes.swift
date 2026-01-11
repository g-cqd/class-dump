// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Class loading extensions for ObjC2Processor.
///
/// This extension provides functions for loading ObjC classes from the binary.
/// Classes are loaded after protocols since they may adopt them. The loader
/// handles both regular ObjC classes and Swift classes exposed to ObjC.
extension ObjC2Processor {

    // MARK: - Class Collection

    /// Collect all class addresses from the binary.
    ///
    /// Reads the `__objc_classlist` section to get pointers to all class
    /// definitions in the binary.
    ///
    /// - Returns: Array of class virtual addresses.
    func collectClassAddresses() throws -> [UInt64] {
        try collectAddresses(
            fromSection: "__objc_classlist",
            inSegments: ["__DATA", "__DATA_CONST"]
        )
    }

    /// Load all classes in parallel using structured concurrency.
    ///
    /// Uses TaskGroup for parallel loading with thread-safe caching via Mutex.
    ///
    /// - Returns: Array of loaded classes.
    func loadClassesAsync() async throws -> [ObjCClass] {
        let addresses = try collectClassAddresses()

        return try await withThrowingTaskGroup(
            of: ObjCClass?.self,
            returning: [ObjCClass].self
        ) { group in
            for address in addresses {
                group.addTask {
                    try await self.loadClassAsync(at: address)
                }
            }

            var classes: [ObjCClass] = []
            classes.reserveCapacity(addresses.count)

            for try await aClass in group {
                if let aClass = aClass {
                    classes.append(aClass)
                }
            }

            return classes
        }
    }

    // MARK: - Class Loading

    /// Load a class at the given address.
    ///
    /// Handles caching to ensure classes are only loaded once, which is
    /// important for handling circular references through superclasses.
    ///
    /// - Parameter address: Virtual address of the class.
    /// - Returns: The loaded class or nil if invalid.
    /// - Throws: `DataCursorError` if reading class data fails.
    func loadClassAsync(at address: UInt64) async throws -> ObjCClass? {
        guard address != 0 else { return nil }

        // Check Mutex cache first (sync)
        if let cached = classesByAddress.get(address) {
            return cached
        }

        guard let offset = fileOffset(for: address) else {
            return nil
        }

        var cursor = try DataCursor(data: data, offset: offset)
        let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Load class data (class_ro_t)
        guard let classData = try loadClassROData(from: rawClass) else {
            return nil
        }

        // Read class name
        let namePointer = decodeChainedFixupPointer(classData.name)
        guard let name = readString(at: namePointer) else {
            return nil
        }

        let aClass = ObjCClass(name: name, address: address)
        aClass.isSwiftClass = rawClass.isSwiftClass
        aClass.classDataAddress = rawClass.dataPointer
        aClass.metaclassAddress = rawClass.isa

        // Cache immediately to handle circular references (sync)
        classesByAddress.set(address, value: aClass)

        // Load class components
        try await loadClassComponents(
            into: aClass,
            from: rawClass,
            classData: classData
        )

        return aClass
    }

    // MARK: - Class RO Data Loading

    /// Load the class_ro_t structure for a class.
    ///
    /// The class structure contains a pointer to class_ro_t which holds
    /// the class name, methods, ivars, properties, and protocol list.
    ///
    /// - Parameter rawClass: The raw class structure.
    /// - Returns: The class RO data or nil if invalid.
    /// - Throws: `DataCursorError` if reading class RO data fails.
    private func loadClassROData(from rawClass: ObjC2Class) throws -> ObjC2ClassROData? {
        let rawDataPointer = rawClass.dataPointer
        let decodedDataPointer = decodeChainedFixupPointer(rawDataPointer)
        let dataPointerClean = decodedDataPointer & Self.pointerAlignmentMask

        guard dataPointerClean != 0 else { return nil }
        guard let dataOffset = fileOffset(for: dataPointerClean) else { return nil }

        var dataCursor = try DataCursor(data: data, offset: dataOffset)
        return try ObjC2ClassROData(cursor: &dataCursor, byteOrder: byteOrder, is64Bit: is64Bit)
    }

    // MARK: - Class Component Loading

    /// Load all components of a class (superclass, methods, ivars, protocols, properties).
    ///
    /// - Parameters:
    ///   - aClass: The class to populate.
    ///   - rawClass: The raw class structure.
    ///   - classData: The class RO data.
    /// - Throws: `DataCursorError` if reading class component data fails.
    private func loadClassComponents(
        into aClass: ObjCClass,
        from rawClass: ObjC2Class,
        classData: ObjC2ClassROData
    ) async throws {
        // Load superclass
        aClass.superclassRef = try await loadSuperclassReference(from: rawClass)

        // Load instance methods
        for method in try loadMethods(at: classData.baseMethods) {
            aClass.addInstanceMethod(method)
        }

        // Load class methods from metaclass
        let isaAddr = decodeChainedFixupPointer(rawClass.isa)
        if isaAddr != 0 {
            for method in try loadClassMethods(at: isaAddr) {
                aClass.addClassMethod(method)
            }
        }

        // Load instance variables (async - uses actor-based Swift resolver)
        for ivar in try await loadInstanceVariables(
            at: classData.ivars,
            className: aClass.name,
            isSwiftClass: aClass.isSwiftClass
        ) {
            aClass.addInstanceVariable(ivar)
        }

        // Load protocols using Mutex cache (sync)
        let protocolAddresses = try loadProtocolAddressList(at: classData.baseProtocols)
        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress.get(protoAddr) {
                aClass.addAdoptedProtocol(proto)
            }
            else if let proto = try? await loadProtocolAsync(at: protoAddr) {
                aClass.addAdoptedProtocol(proto)
            }
        }

        // Link Swift protocol conformances
        if aClass.isSwiftClass, let swift = swiftMetadata {
            let conformances = swift.conformances(forType: aClass.name)
            for conformance in conformances where !conformance.protocolName.isEmpty {
                aClass.addSwiftConformance(conformance.protocolName)
            }
        }

        // Load properties
        for property in try loadProperties(at: classData.baseProperties) {
            aClass.addProperty(property)
        }
    }

    // MARK: - Superclass Loading

    /// Load the superclass reference for a class.
    ///
    /// The superclass may be an address to another class in the binary,
    /// or a bind to an external symbol (like NSObject from Foundation).
    ///
    /// - Parameter rawClass: The raw class structure.
    /// - Returns: The superclass reference or nil.
    /// - Throws: `DataCursorError` if reading superclass data fails.
    private func loadSuperclassReference(from rawClass: ObjC2Class) async throws -> ObjCClassReference? {
        let superclassResult = decodePointerWithBindInfo(rawClass.superclass)

        switch superclassResult {
            case .address(let superclassAddr):
                guard superclassAddr != 0 else { return nil }
                if let superclass = try await loadClassAsync(at: superclassAddr) {
                    return ObjCClassReference(name: superclass.name, address: superclassAddr)
                }
                return nil

            case .bindSymbol(let symbolName):
                let className = extractClassName(from: symbolName)
                return ObjCClassReference(name: className, address: 0)

            case .bindOrdinal(let ordinal):
                return ObjCClassReference(name: "/* bind ordinal \(ordinal) */", address: 0)
        }
    }

    /// Extract the class name from a symbol name.
    ///
    /// Pure function that strips the OBJC_CLASS_$_ prefix.
    ///
    /// - Parameter symbolName: The symbol name.
    /// - Returns: The extracted class name.
    private func extractClassName(from symbolName: String) -> String {
        if symbolName.hasPrefix("OBJC_CLASS_$_") {
            return String(symbolName.dropFirst("OBJC_CLASS_$_".count))
        }
        return symbolName
    }

    // MARK: - Metaclass Method Loading

    /// Load class methods from a metaclass.
    ///
    /// Class methods are stored in the metaclass's method list, not the
    /// class's method list.
    ///
    /// - Parameter metaclassAddress: Virtual address of the metaclass.
    /// - Returns: Array of class methods.
    /// - Throws: `DataCursorError` if reading metaclass data fails.
    func loadClassMethods(at metaclassAddress: UInt64) throws -> [ObjCMethod] {
        guard metaclassAddress != 0 else { return [] }
        guard let offset = fileOffset(for: metaclassAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Decode dataPointer (may be chained fixup) and mask Swift flags
        let decodedDataPointer = decodeChainedFixupPointer(rawClass.dataPointer)
        let dataPointerClean = decodedDataPointer & Self.pointerAlignmentMask
        guard dataPointerClean != 0 else { return [] }
        guard let dataOffset = fileOffset(for: dataPointerClean) else { return [] }

        var dataCursor = try DataCursor(data: data, offset: dataOffset)
        let classData = try ObjC2ClassROData(cursor: &dataCursor, byteOrder: byteOrder, is64Bit: is64Bit)

        return try loadMethods(at: classData.baseMethods)
    }
}

// MARK: - Class Analysis Utilities

/// Pure functions for analyzing ObjC classes.
public enum ObjCClassAnalyzer {

    /// Compute the inheritance depth of a class.
    ///
    /// Pure function that counts superclass chain length.
    ///
    /// - Parameter cls: The class to analyze.
    /// - Returns: The inheritance depth (0 for root classes).
    public static func inheritanceDepth(of cls: ObjCClass) -> Int {
        guard cls.superclassRef != nil else { return 0 }
        // Note: Without access to the superclass object, we can only count 1
        // For full depth, you'd need the class cache
        return 1
    }

    /// Check if a class is a Swift class based on its name or flags.
    ///
    /// Pure predicate function.
    ///
    /// - Parameter cls: The class to check.
    /// - Returns: True if the class is a Swift class.
    public static func isSwiftClass(_ cls: ObjCClass) -> Bool {
        cls.isSwiftClass || cls.name.hasPrefix("_Tt") || cls.name.hasPrefix("_$s")
    }

    /// Get all method selectors defined in a class.
    ///
    /// Pure function that extracts selector names.
    ///
    /// - Parameter cls: The class to analyze.
    /// - Returns: Set of selector names.
    public static func allSelectors(in cls: ObjCClass) -> Set<String> {
        var selectors = Set<String>()
        for method in cls.instanceMethods {
            selectors.insert(method.name)
        }
        for method in cls.classMethods {
            selectors.insert(method.name)
        }
        return selectors
    }

    /// Get all property names in a class.
    ///
    /// Pure function that extracts property names.
    ///
    /// - Parameter cls: The class to analyze.
    /// - Returns: Set of property names.
    public static func allProperties(in cls: ObjCClass) -> Set<String> {
        Set(cls.properties.map(\.name))
    }

    /// Count total members in a class.
    ///
    /// Pure function for class complexity analysis.
    ///
    /// - Parameter cls: The class to analyze.
    /// - Returns: Total member count.
    public static func totalMemberCount(of cls: ObjCClass) -> Int {
        cls.instanceMethods.count
            + cls.classMethods.count
            + cls.properties.count
            + cls.instanceVariables.count
    }

    /// Check if a class conforms to a protocol by name.
    ///
    /// Pure predicate function.
    ///
    /// - Parameters:
    ///   - cls: The class to check.
    ///   - protocolName: The protocol name to look for.
    /// - Returns: True if the class adopts the protocol.
    public static func conformsToProtocol(_ cls: ObjCClass, named protocolName: String) -> Bool {
        cls.adoptedProtocols.contains { $0.name == protocolName }
            || cls.swiftConformances.contains(protocolName)
    }
}
