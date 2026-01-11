// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Class Loading

extension DyldCacheObjCProcessor {

    /// Load all ObjC classes from the image.
    ///
    /// Classes are loaded from the `__objc_classlist` section in either
    /// `__DATA` or `__DATA_CONST` segments.
    ///
    /// - Returns: Array of parsed classes.
    /// - Throws: If reading fails.
    func loadClasses() async throws -> [ObjCClass] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_classlist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_classlist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        return try await parseClassList(from: sectionData)
    }

    /// Parse class list from section data.
    ///
    /// Uses resilient loading to continue past individual class failures.
    ///
    /// - Parameter sectionData: The raw section data containing class addresses.
    /// - Returns: Array of successfully parsed classes.
    /// - Throws: `DataCursorError` if cursor initialization or reading fails.
    private func parseClassList(from sectionData: Data) async throws -> [ObjCClass] {
        var cursor = try DataCursor(data: sectionData)
        var classes: [ObjCClass] = []

        while cursor.offset < sectionData.count {
            let rawAddress = try readPointerValue(from: &cursor)
            let address = decodePointer(rawAddress)

            if address != 0 {
                // Wrap individual class loading to continue on errors
                do {
                    if let cls = try await loadClass(at: address) {
                        classes.append(cls)
                    }
                }
                catch {
                    // Skip this class but continue with others
                    continue
                }
            }
        }

        return classes
    }

    /// Load a single class at the given address.
    ///
    /// Uses caching to avoid re-parsing the same class multiple times.
    ///
    /// - Parameter address: Virtual address of the class.
    /// - Returns: The parsed class, or nil if loading fails.
    /// - Throws: `DataCursorError` if reading class data fails.
    func loadClass(at address: UInt64) async throws -> ObjCClass? {
        guard address != 0 else { return nil }

        // Check cache first
        if let cached = classesByAddress.get(address) {
            return cached
        }

        // Load class and class_ro_t structures
        guard let (rawClass, classROData) = try loadRawClassData(at: address) else {
            return nil
        }

        // Resolve class name
        let namePointer = decodePointer(classROData.name)
        guard let name = readString(at: namePointer) else {
            return nil
        }

        // Create and cache class
        let cls = ObjCClass(name: name, address: address)
        cls.isSwiftClass = rawClass.isSwiftClass
        cls.classDataAddress = rawClass.dataPointer
        cls.metaclassAddress = rawClass.isa
        classesByAddress.set(address, value: cls)

        // Load superclass
        try await loadSuperclass(into: cls, from: rawClass.superclass)

        // Load members
        try await loadClassMembers(into: cls, from: classROData, metaclassAddress: rawClass.isa)

        return cls
    }

    // MARK: - Class Structure Loading

    /// Load the raw class and class_ro_t data at the given address.
    private func loadRawClassData(at address: UInt64) throws -> (ObjC2Class, ObjC2ClassROData)? {
        guard let offset = fileOffset(for: address) else {
            return nil
        }

        // Load objc_class structure
        let classSize = is64Bit ? 64 : 32
        let classData = try cache.file.data(at: offset, count: classSize)
        var cursor = try DataCursor(data: classData)
        let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Load class_ro_t
        let dataPointerCleared = DyldCachePointerFlags.clearObjCDataFlags(rawClass.data)
        let dataPointer = decodePointer(dataPointerCleared)

        guard dataPointer != 0, let dataOffset = fileOffset(for: dataPointer) else {
            return nil
        }

        let roSize = is64Bit ? 80 : 48
        let roData = try cache.file.data(at: dataOffset, count: roSize)
        var roCursor = try DataCursor(data: roData)
        let classROData = try ObjC2ClassROData(cursor: &roCursor, byteOrder: byteOrder, is64Bit: is64Bit)

        return (rawClass, classROData)
    }

    /// Load the superclass reference into the class.
    private func loadSuperclass(into cls: ObjCClass, from superclassPointer: UInt64) async throws {
        let superclassAddr = decodePointer(superclassPointer)
        guard superclassAddr != 0 else { return }

        // Try to load as local class first
        if let superclass = try await loadClass(at: superclassAddr) {
            cls.superclassRef = ObjCClassReference(name: superclass.name, address: superclassAddr)
            return
        }

        // Try as external class
        if let superName = readExternalClassName(at: superclassAddr) {
            cls.superclassRef = ObjCClassReference(name: superName, address: superclassAddr)
        }
    }

    /// Load all members (methods, ivars, protocols, properties) into the class.
    private func loadClassMembers(
        into cls: ObjCClass,
        from classROData: ObjC2ClassROData,
        metaclassAddress: UInt64
    ) async throws {
        // Instance methods
        for method in try loadMethods(at: classROData.baseMethods) {
            cls.addInstanceMethod(method)
        }

        // Class methods from metaclass
        let metaclassAddr = decodePointer(metaclassAddress)
        if metaclassAddr != 0 {
            for method in try loadClassMethods(at: metaclassAddr) {
                cls.addClassMethod(method)
            }
        }

        // Instance variables
        for ivar in try loadInstanceVariables(at: classROData.ivars) {
            cls.addInstanceVariable(ivar)
        }

        // Protocols
        let protocolAddresses = try loadProtocolAddressList(at: classROData.baseProtocols)
        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress.get(protoAddr) {
                cls.addAdoptedProtocol(proto)
            }
            else if let proto = try? await loadProtocol(at: protoAddr) {
                cls.addAdoptedProtocol(proto)
            }
        }

        // Properties
        for property in try loadProperties(at: classROData.baseProperties) {
            cls.addProperty(property)
        }
    }

    // MARK: - Metaclass Methods

    /// Load class methods from a metaclass.
    ///
    /// - Parameter metaclassAddress: Address of the metaclass.
    /// - Returns: Array of class methods.
    /// - Throws: `DataCursorError` if reading metaclass data fails.
    func loadClassMethods(at metaclassAddress: UInt64) throws -> [ObjCMethod] {
        guard metaclassAddress != 0 else { return [] }
        guard let offset = fileOffset(for: metaclassAddress) else { return [] }

        // Load metaclass structure
        let classSize = is64Bit ? 64 : 32
        let classData = try cache.file.data(at: offset, count: classSize)
        var cursor = try DataCursor(data: classData)
        let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Load metaclass's class_ro_t
        let dataPointer = decodePointer(rawClass.dataPointer) & ~0x7
        guard dataPointer != 0, let dataOffset = fileOffset(for: dataPointer) else {
            return []
        }

        let roSize = is64Bit ? 80 : 48
        let roData = try cache.file.data(at: dataOffset, count: roSize)
        var roCursor = try DataCursor(data: roData)
        let classROData = try ObjC2ClassROData(cursor: &roCursor, byteOrder: byteOrder, is64Bit: is64Bit)

        return try loadMethods(at: classROData.baseMethods)
    }

    // MARK: - External Class Resolution

    /// Read an external class name from another framework in the cache.
    ///
    /// When a class references a superclass from another framework, we need to
    /// follow the class structure to read its name.
    ///
    /// - Parameter address: Address of the external class.
    /// - Returns: The class name, or nil if reading fails.
    func readExternalClassName(at address: UInt64) -> String? {
        guard let offset = fileOffset(for: address) else {
            return nil
        }

        do {
            let classSize = is64Bit ? 64 : 32
            let classData = try cache.file.data(at: offset, count: classSize)
            var cursor = try DataCursor(data: classData)
            let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

            let dataPointer = decodePointer(rawClass.dataPointer) & ~0x7
            guard dataPointer != 0, let dataOffset = fileOffset(for: dataPointer) else {
                return nil
            }

            let roSize = is64Bit ? 80 : 48
            let roData = try cache.file.data(at: dataOffset, count: roSize)
            var roCursor = try DataCursor(data: roData)
            let classROData = try ObjC2ClassROData(cursor: &roCursor, byteOrder: byteOrder, is64Bit: is64Bit)

            let namePointer = decodePointer(classROData.name)
            return readString(at: namePointer)
        }
        catch {
            return nil
        }
    }
}
