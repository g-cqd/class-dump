// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Method loading extensions for ObjC2Processor.
///
/// This extension provides pure parsing functions for loading ObjC methods
/// from both regular and small method formats. All parsing logic is implemented
/// as pure functions that take input data and return parsed results.
extension ObjC2Processor {

    // MARK: - Method Loading

    /// Load methods from a method list at the given address.
    ///
    /// This function handles both regular and small method formats automatically
    /// by inspecting the list header flags.
    ///
    /// - Parameters:
    ///   - address: Virtual address of the method list.
    ///   - extendedTypesAddress: Optional address of extended method types.
    /// - Returns: Array of parsed methods.
    /// - Throws: `DataCursorError` if reading method list data fails.
    func loadMethods(at address: UInt64, extendedTypesAddress: UInt64 = 0) throws -> [ObjCMethod] {
        guard address != 0 else { return [] }

        let decodedAddress = decodeChainedFixupPointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        let listHeader = try ObjC2ListHeader(cursor: &cursor, byteOrder: byteOrder)

        // Dispatch to appropriate loader based on method format
        guard listHeader.usesSmallMethods else {
            return try loadRegularMethods(
                cursor: &cursor,
                count: listHeader.count,
                extendedTypesAddress: extendedTypesAddress
            )
        }
        return try loadSmallMethods(at: decodedAddress, listHeader: listHeader)
    }

    // MARK: - Regular Method Loading

    /// Load methods using the regular method format (absolute pointers).
    ///
    /// Pure parsing function that reads method entries from the cursor position.
    ///
    /// - Parameters:
    ///   - cursor: Data cursor positioned after the list header.
    ///   - count: Number of methods to read.
    ///   - extendedTypesAddress: Optional address of extended type encodings.
    /// - Returns: Array of parsed methods in reverse order (matching original behavior).
    /// - Throws: `DataCursorError` if reading method data fails.
    private func loadRegularMethods(
        cursor: inout DataCursor,
        count: UInt32,
        extendedTypesAddress: UInt64
    ) throws -> [ObjCMethod] {
        // Set up extended types cursor if available
        var extendedTypesCursor: DataCursor? = nil
        if extendedTypesAddress != 0, let extOffset = fileOffset(for: extendedTypesAddress) {
            extendedTypesCursor = try DataCursor(data: data, offset: extOffset)
        }

        let methods: [ObjCMethod] = try (0..<count)
            .compactMap { _ in
                try parseRegularMethod(
                    cursor: &cursor,
                    extendedTypesCursor: &extendedTypesCursor
                )
            }

        return methods.reversed()
    }

    /// Parse a single regular method entry.
    ///
    /// Pure parsing function for a single method.
    ///
    /// - Parameters:
    ///   - cursor: Data cursor at the method entry position.
    ///   - extendedTypesCursor: Optional cursor for extended types (modified in place).
    /// - Returns: Parsed method or nil if invalid.
    /// - Throws: `DataCursorError` if reading method entry fails.
    private func parseRegularMethod(
        cursor: inout DataCursor,
        extendedTypesCursor: inout DataCursor?
    ) throws -> ObjCMethod? {
        let rawMethod = try ObjC2Method(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Decode the name pointer (may be a chained fixup)
        let nameAddr = decodeChainedFixupPointer(rawMethod.name)
        guard let name = readString(at: nameAddr) else { return nil }

        // Try extended types first, then fall back to regular types
        let typeString = try readMethodTypeString(
            rawMethod: rawMethod,
            extendedTypesCursor: &extendedTypesCursor
        )

        return ObjCMethod(
            name: name,
            typeString: typeString,
            address: rawMethod.imp
        )
    }

    /// Read the type string for a method, preferring extended types.
    ///
    /// - Parameters:
    ///   - rawMethod: The raw method structure.
    ///   - extendedTypesCursor: Optional cursor for extended types.
    /// - Returns: The method type encoding string.
    /// - Throws: `DataCursorError` if reading type data fails.
    private func readMethodTypeString(
        rawMethod: ObjC2Method,
        extendedTypesCursor: inout DataCursor?
    ) throws -> String {
        // Try extended types first
        if var extCursor = extendedTypesCursor {
            let extTypesAddr: UInt64
            if is64Bit {
                extTypesAddr =
                    byteOrder == .little
                    ? try extCursor.readLittleInt64()
                    : try extCursor.readBigInt64()
            }
            else {
                let value =
                    byteOrder == .little
                    ? try extCursor.readLittleInt32()
                    : try extCursor.readBigInt32()
                extTypesAddr = UInt64(value)
            }
            extendedTypesCursor = extCursor

            let decodedExtTypes = decodeChainedFixupPointer(extTypesAddr)
            if let typeString = readString(at: decodedExtTypes) {
                return typeString
            }
        }

        // Fall back to regular types
        let typesAddr = decodeChainedFixupPointer(rawMethod.types)
        return readString(at: typesAddr) ?? ""
    }

    // MARK: - Small Method Loading

    /// Load methods using the small method format (relative offsets).
    ///
    /// Used in iOS 14+ / macOS 11+ binaries. Small methods use 12-byte entries
    /// with relative offsets instead of absolute pointers for better code sharing.
    ///
    /// - Parameters:
    ///   - listAddress: Virtual address of the method list.
    ///   - listHeader: The parsed list header.
    /// - Returns: Array of parsed methods in reverse order.
    /// - Throws: `DataCursorError` if reading small method data fails.
    func loadSmallMethods(at listAddress: UInt64, listHeader: ObjC2ListHeader) throws -> [ObjCMethod] {
        guard let offset = fileOffset(for: listAddress) else { return [] }

        // Skip the header (8 bytes)
        var cursor = try DataCursor(data: data, offset: offset + 8)

        let methods: [ObjCMethod] = try (0..<listHeader.count)
            .compactMap { index in
                try parseSmallMethod(
                    cursor: &cursor,
                    listAddress: listAddress,
                    methodIndex: index
                )
            }

        return methods.reversed()
    }

    /// Parse a single small method entry.
    ///
    /// Small methods use relative offsets from the field address to the target.
    /// This enables position-independent code in shared caches.
    ///
    /// - Parameters:
    ///   - cursor: Data cursor at the method entry position.
    ///   - listAddress: Base address of the method list.
    ///   - methodIndex: Index of this method in the list.
    /// - Returns: Parsed method or nil if invalid.
    /// - Throws: `DataCursorError` if reading small method entry fails.
    private func parseSmallMethod(
        cursor: inout DataCursor,
        listAddress: UInt64,
        methodIndex: UInt32
    ) throws -> ObjCMethod? {
        let smallMethod = try ObjC2SmallMethod(cursor: &cursor, byteOrder: byteOrder)

        // Calculate VM addresses using relative offset formula
        let addresses = calculateSmallMethodAddresses(
            listAddress: listAddress,
            methodIndex: methodIndex,
            smallMethod: smallMethod
        )

        // Resolve the selector name
        guard let name = resolveSmallMethodSelector(at: addresses.selectorRef) else {
            return nil
        }

        // Read the type string
        let typeString = readString(at: addresses.types) ?? ""

        return ObjCMethod(
            name: name,
            typeString: typeString,
            address: addresses.imp
        )
    }

    // MARK: - Small Method Address Calculation

    /// Addresses calculated for a small method entry.
    struct SmallMethodAddresses {
        let selectorRef: UInt64
        let types: UInt64
        let imp: UInt64
    }

    /// Calculate the resolved addresses for a small method.
    ///
    /// Pure function that applies relative offset calculation.
    ///
    /// Small method entries are 12 bytes:
    /// - Bytes 0-3: nameOffset (relative to field address at offset 0)
    /// - Bytes 4-7: typesOffset (relative to field address at offset 4)
    /// - Bytes 8-11: impOffset (relative to field address at offset 8)
    ///
    /// - Parameters:
    ///   - listAddress: Base address of the method list.
    ///   - methodIndex: Index of this method in the list.
    ///   - smallMethod: The raw small method structure.
    /// - Returns: Resolved addresses for selector, types, and implementation.
    private func calculateSmallMethodAddresses(
        listAddress: UInt64,
        methodIndex: UInt32,
        smallMethod: ObjC2SmallMethod
    ) -> SmallMethodAddresses {
        // Each small method is 12 bytes, starting after the 8-byte header
        let methodEntryVMAddr = listAddress + 8 + UInt64(methodIndex) * 12

        // The name offset is relative to the name field's address (offset 0)
        let nameFieldVMAddr = methodEntryVMAddr
        let selectorRefVMAddr = UInt64(Int64(nameFieldVMAddr) + Int64(smallMethod.nameOffset))

        // The types offset is relative to the types field's address (offset 4)
        let typesFieldVMAddr = methodEntryVMAddr + 4
        let typesVMAddr = UInt64(Int64(typesFieldVMAddr) + Int64(smallMethod.typesOffset))

        // The imp offset is relative to the imp field's address (offset 8)
        let impFieldVMAddr = methodEntryVMAddr + 8
        let impVMAddr = UInt64(Int64(impFieldVMAddr) + Int64(smallMethod.impOffset))

        return SmallMethodAddresses(
            selectorRef: selectorRefVMAddr,
            types: typesVMAddr,
            imp: impVMAddr
        )
    }

    /// Resolve a selector name from a selector reference address.
    ///
    /// For small methods, the name offset points to a selector reference in
    /// `__objc_selrefs`, which contains a pointer to the actual string in
    /// `__objc_methname`. We try pointer dereference first, then direct read.
    ///
    /// - Parameter address: Virtual address of the selector reference.
    /// - Returns: The selector name string or nil.
    private func resolveSmallMethodSelector(at address: UInt64) -> String? {
        guard let selectorRefOffset = fileOffset(for: address) else {
            return nil
        }

        // Try to read as a pointer first (for __objc_selrefs entries)
        if let name = readSelectorViaPointer(at: selectorRefOffset) {
            return name
        }

        // Fall back to reading as direct string
        return readString(at: address)
    }

    /// Read a selector by dereferencing a pointer at the given offset.
    ///
    /// - Parameter offset: File offset of the selector pointer.
    /// - Returns: The selector string or nil.
    private func readSelectorViaPointer(at offset: Int) -> String? {
        guard var selectorCursor = try? DataCursor(data: data, offset: offset) else {
            return nil
        }

        guard
            let rawSelectorPtr = try?
                (byteOrder == .little
                ? selectorCursor.readLittleInt64()
                : selectorCursor.readBigInt64())
        else {
            return nil
        }

        let selectorAddr = decodeChainedFixupPointer(rawSelectorPtr)
        guard selectorAddr != 0 else { return nil }

        return readString(at: selectorAddr)
    }
}
