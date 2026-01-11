// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Method Loading

extension DyldCacheObjCProcessor {

    /// Load methods from a method list at the given address.
    ///
    /// Handles both regular (pointer-based) and small (relative offset) method formats.
    ///
    /// - Parameter address: Address of the method list.
    /// - Returns: Array of parsed methods.
    /// - Throws: `DataCursorError` if reading method list data fails.
    func loadMethods(at address: UInt64) throws -> [ObjCMethod] {
        guard address != 0 else { return [] }

        let decodedAddress = decodePointer(address)
        guard let offset = fileOffset(for: decodedAddress) else {
            return []
        }

        // Read list header
        let listHeader = try loadListHeader(at: offset)

        // Dispatch based on method format
        if listHeader.usesSmallMethods {
            return try loadSmallMethods(
                at: decodedAddress,
                listHeader: listHeader,
                usesDirectSelectors: listHeader.usesDirectSelectors
            )
        }

        return try loadRegularMethods(at: offset, count: Int(listHeader.count))
    }

    /// Load regular (pointer-based) methods.
    private func loadRegularMethods(at offset: Int, count: Int) throws -> [ObjCMethod] {
        let entrySize = is64Bit ? 24 : 12
        let listData = try cache.file.data(at: offset + 8, count: count * entrySize)
        var cursor = try DataCursor(data: listData)

        var methods: [ObjCMethod] = []
        methods.reserveCapacity(count)

        for _ in 0..<count {
            if let method = try parseRegularMethod(from: &cursor) {
                methods.append(method)
            }
        }

        return methods.reversed()
    }

    /// Parse a single regular method entry.
    private func parseRegularMethod(from cursor: inout DataCursor) throws -> ObjCMethod? {
        let rawMethod = try ObjC2Method(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        let nameAddr = decodePointer(rawMethod.name)
        guard let name = readString(at: nameAddr) else {
            return nil
        }

        let typesAddr = decodePointer(rawMethod.types)
        let typeString = readString(at: typesAddr) ?? ""

        return ObjCMethod(name: name, typeString: typeString, address: rawMethod.imp)
    }

    // MARK: - Small Method Loading

    /// Load methods using the small method format (relative offsets).
    ///
    /// Small methods use a compact 12-byte format with relative offsets:
    /// - `nameOffset`: Int32 relative offset to selector
    /// - `typesOffset`: Int32 relative offset to type encoding
    /// - `impOffset`: Int32 relative offset to implementation
    ///
    /// - Parameters:
    ///   - listAddress: Virtual address of the method list.
    ///   - listHeader: The parsed list header.
    ///   - usesDirectSelectors: Whether selectors use direct offsets (iOS 16+).
    /// - Returns: Array of parsed methods.
    /// - Throws: `DataCursorError` if reading method data fails.
    func loadSmallMethods(
        at listAddress: UInt64,
        listHeader: ObjC2ListHeader,
        usesDirectSelectors: Bool
    ) throws -> [ObjCMethod] {
        guard let offset = fileOffset(for: listAddress) else {
            return []
        }

        // Early exit if direct selectors are required but base is unavailable
        if usesDirectSelectors && relativeMethodSelectorBase == nil {
            return []
        }

        let entrySize = 12
        let listData = try cache.file.data(at: offset + 8, count: Int(listHeader.count) * entrySize)
        var cursor = try DataCursor(data: listData)

        var methods: [ObjCMethod] = []
        methods.reserveCapacity(Int(listHeader.count))

        for i in 0..<listHeader.count {
            let smallMethod = try ObjC2SmallMethod(cursor: &cursor, byteOrder: byteOrder)
            let methodEntryVMAddr = listAddress + 8 + UInt64(i) * 12

            if let method = try parseSmallMethod(
                smallMethod,
                at: methodEntryVMAddr,
                usesDirectSelectors: usesDirectSelectors
            ) {
                methods.append(method)
            }
        }

        return methods.reversed()
    }

    /// Parse a single small method entry.
    private func parseSmallMethod(
        _ smallMethod: ObjC2SmallMethod,
        at methodEntryVMAddr: UInt64,
        usesDirectSelectors: Bool
    ) throws -> ObjCMethod? {
        // Resolve selector name
        let name: String?

        if usesDirectSelectors {
            // iOS 16+: Direct offset from selector base
            guard let selectorBase = relativeMethodSelectorBase else {
                return nil
            }
            let selectorAddr = UInt64(Int64(selectorBase) + Int64(smallMethod.nameOffset))
            name = readString(at: selectorAddr)
        }
        else {
            // Pre-iOS 16: Indirect selector reference
            name = try resolveIndirectSelector(smallMethod.nameOffset, at: methodEntryVMAddr)
        }

        guard let selectorName = name, !selectorName.isEmpty else {
            return nil
        }

        // Resolve type encoding
        let typesFieldVMAddr = methodEntryVMAddr + 4
        let typesVMAddr = UInt64(Int64(typesFieldVMAddr) + Int64(smallMethod.typesOffset))
        let typeString = readString(at: typesVMAddr) ?? ""

        // Resolve implementation address
        let impFieldVMAddr = methodEntryVMAddr + 8
        let impVMAddr = UInt64(Int64(impFieldVMAddr) + Int64(smallMethod.impOffset))

        return ObjCMethod(name: selectorName, typeString: typeString, address: impVMAddr)
    }

    /// Resolve an indirect selector reference (pre-iOS 16 format).
    private func resolveIndirectSelector(_ nameOffset: Int32, at methodEntryVMAddr: UInt64) throws -> String? {
        let nameFieldVMAddr = methodEntryVMAddr
        let selectorRefVMAddr = UInt64(Int64(nameFieldVMAddr) + Int64(nameOffset))

        guard let selectorRefOffset = fileOffset(for: selectorRefVMAddr) else {
            return nil
        }

        // Read pointer dereference
        let refData = try cache.file.data(at: selectorRefOffset, count: is64Bit ? 8 : 4)
        var refCursor = try DataCursor(data: refData)

        let rawSelectorPtr = try readPointerValue(from: &refCursor)
        let selectorAddr = decodePointer(rawSelectorPtr)

        if selectorAddr != 0 {
            return readString(at: selectorAddr)
        }

        // Fallback: try reading directly as a string
        return readString(at: selectorRefVMAddr)
    }

    // MARK: - List Header Loading

    /// Load an ObjC2ListHeader from the given file offset.
    func loadListHeader(at offset: Int) throws -> ObjC2ListHeader {
        let headerData = try cache.file.data(at: offset, count: 8)
        var cursor = try DataCursor(data: headerData)
        return try ObjC2ListHeader(cursor: &cursor, byteOrder: byteOrder)
    }
}

// MARK: - Instance Variable Loading

extension DyldCacheObjCProcessor {

    /// Load instance variables from an ivar list at the given address.
    ///
    /// - Parameter address: Address of the ivar list.
    /// - Returns: Array of parsed instance variables.
    /// - Throws: `DataCursorError` if reading ivar list data fails.
    func loadInstanceVariables(at address: UInt64) throws -> [ObjCInstanceVariable] {
        guard address != 0 else { return [] }

        let decodedAddress = decodePointer(address)
        guard let offset = fileOffset(for: decodedAddress) else {
            return []
        }

        let listHeader = try loadListHeader(at: offset)
        let entrySize = is64Bit ? 32 : 20
        let listData = try cache.file.data(at: offset + 8, count: Int(listHeader.count) * entrySize)
        var cursor = try DataCursor(data: listData)

        var ivars: [ObjCInstanceVariable] = []
        ivars.reserveCapacity(Int(listHeader.count))

        for _ in 0..<listHeader.count {
            if let ivar = try parseInstanceVariable(from: &cursor) {
                ivars.append(ivar)
            }
        }

        return ivars
    }

    /// Parse a single instance variable entry.
    private func parseInstanceVariable(from cursor: inout DataCursor) throws -> ObjCInstanceVariable? {
        let rawIvar = try ObjC2Ivar(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Resolve name
        let nameAddr = decodePointer(rawIvar.name)
        guard nameAddr != 0, let name = readString(at: nameAddr) else {
            return nil
        }

        // Resolve type encoding
        let typeAddr = decodePointer(rawIvar.type)
        let typeEncoding = readString(at: typeAddr) ?? ""

        // Read actual offset value
        let actualOffset = try readIvarOffset(from: rawIvar.offset)

        return ObjCInstanceVariable(
            name: name,
            typeEncoding: typeEncoding,
            typeString: "",
            offset: actualOffset,
            size: UInt64(rawIvar.size),
            alignment: rawIvar.alignment
        )
    }

    /// Read the actual ivar offset value from the offset pointer.
    private func readIvarOffset(from offsetPointer: UInt64) throws -> UInt64 {
        let offsetAddr = decodePointer(offsetPointer)
        guard offsetAddr != 0, let offsetPtr = fileOffset(for: offsetAddr) else {
            return 0
        }

        let offsetData = try cache.file.data(at: offsetPtr, count: is64Bit ? 8 : 4)
        var cursor = try DataCursor(data: offsetData)

        if is64Bit {
            let value = try cursor.readLittleInt64()
            return UInt64(UInt32(truncatingIfNeeded: value))
        }
        return UInt64(try cursor.readLittleInt32())
    }
}

// MARK: - Property Loading

extension DyldCacheObjCProcessor {

    /// Load properties from a property list at the given address.
    ///
    /// - Parameter address: Address of the property list.
    /// - Returns: Array of parsed properties.
    /// - Throws: `DataCursorError` if reading property list data fails.
    func loadProperties(at address: UInt64) throws -> [ObjCProperty] {
        guard address != 0 else { return [] }

        let decodedAddress = decodePointer(address)
        guard let offset = fileOffset(for: decodedAddress) else {
            return []
        }

        let listHeader = try loadListHeader(at: offset)
        let entrySize = is64Bit ? 16 : 8
        let listData = try cache.file.data(at: offset + 8, count: Int(listHeader.count) * entrySize)
        var cursor = try DataCursor(data: listData)

        var properties: [ObjCProperty] = []
        properties.reserveCapacity(Int(listHeader.count))

        for _ in 0..<listHeader.count {
            if let property = try parseProperty(from: &cursor) {
                properties.append(property)
            }
        }

        return properties
    }

    /// Parse a single property entry.
    private func parseProperty(from cursor: inout DataCursor) throws -> ObjCProperty? {
        let rawProperty = try ObjC2Property(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Resolve name
        let nameAddr = decodePointer(rawProperty.name)
        guard let name = readString(at: nameAddr) else {
            return nil
        }

        // Resolve attributes
        let attrAddr = decodePointer(rawProperty.attributes)
        let attributeString = readString(at: attrAddr) ?? ""

        return ObjCProperty(name: name, attributeString: attributeString)
    }
}
