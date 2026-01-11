// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Protocol Loading

extension DyldCacheObjCProcessor {

    /// Load all ObjC protocols from the image.
    ///
    /// Protocols are loaded from the `__objc_protolist` section in either
    /// `__DATA` or `__DATA_CONST` segments.
    ///
    /// - Returns: Array of parsed protocols.
    /// - Throws: If reading fails.
    func loadProtocols() async throws -> [ObjCProtocol] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_protolist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_protolist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        return try await parseProtocolList(from: sectionData)
    }

    /// Parse protocol list from section data.
    ///
    /// - Parameter sectionData: The raw section data containing protocol addresses.
    /// - Returns: Array of parsed protocols.
    /// - Throws: `DataCursorError` if cursor initialization or reading fails.
    private func parseProtocolList(from sectionData: Data) async throws -> [ObjCProtocol] {
        var cursor = try DataCursor(data: sectionData)
        var protocols: [ObjCProtocol] = []

        while cursor.offset < sectionData.count {
            let rawAddress = try readPointerValue(from: &cursor)
            let address = decodePointer(rawAddress)

            if address != 0, let proto = try await loadProtocol(at: address) {
                protocols.append(proto)
            }
        }

        return protocols
    }

    /// Load a single protocol at the given address.
    ///
    /// Uses caching to avoid re-parsing the same protocol multiple times.
    ///
    /// - Parameter address: Virtual address of the protocol.
    /// - Returns: The parsed protocol, or nil if loading fails.
    /// - Throws: `DataCursorError` if reading protocol data fails.
    func loadProtocol(at address: UInt64) async throws -> ObjCProtocol? {
        guard address != 0 else { return nil }

        // Check cache first
        if let cached = protocolsByAddress.get(address) {
            return cached
        }

        // Load protocol structure
        guard let rawProtocol = try loadRawProtocol(at: address) else {
            return nil
        }

        // Resolve name
        let nameAddr = decodePointer(rawProtocol.name)
        guard let name = readString(at: nameAddr) else {
            return nil
        }

        // Create and cache protocol
        let proto = ObjCProtocol(name: name, address: address)
        protocolsByAddress.set(address, value: proto)

        // Load adopted protocols
        try await loadAdoptedProtocols(into: proto, from: rawProtocol.protocols)

        // Load methods
        try loadProtocolMethods(into: proto, from: rawProtocol)

        // Load properties
        for property in try loadProperties(at: rawProtocol.instanceProperties) {
            proto.addProperty(property)
        }

        return proto
    }

    // MARK: - Protocol Structure Loading

    /// Load the raw ObjC2Protocol structure at the given address.
    private func loadRawProtocol(at address: UInt64) throws -> ObjC2Protocol? {
        guard let offset = fileOffset(for: address) else {
            return nil
        }

        let data = try cache.file.data(at: offset, count: is64Bit ? 80 : 40)
        var cursor = try DataCursor(data: data)
        return try ObjC2Protocol(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit, ptrSize: ptrSize)
    }

    /// Load adopted protocols into the protocol object.
    private func loadAdoptedProtocols(into proto: ObjCProtocol, from address: UInt64) async throws {
        guard address != 0 else { return }

        let adoptedAddresses = try loadProtocolAddressList(at: address)
        for adoptedAddr in adoptedAddresses {
            if let adopted = try await loadProtocol(at: adoptedAddr) {
                proto.addAdoptedProtocol(adopted)
            }
        }
    }

    /// Load all method categories into the protocol.
    private func loadProtocolMethods(into proto: ObjCProtocol, from rawProtocol: ObjC2Protocol) throws {
        // Instance methods
        for method in try loadMethods(at: rawProtocol.instanceMethods) {
            proto.addInstanceMethod(method)
        }

        // Class methods
        for method in try loadMethods(at: rawProtocol.classMethods) {
            proto.addClassMethod(method)
        }

        // Optional instance methods
        for method in try loadMethods(at: rawProtocol.optionalInstanceMethods) {
            proto.addOptionalInstanceMethod(method)
        }

        // Optional class methods
        for method in try loadMethods(at: rawProtocol.optionalClassMethods) {
            proto.addOptionalClassMethod(method)
        }
    }

    // MARK: - Protocol Address List

    /// Load a list of protocol addresses from a protocol_list_t structure.
    ///
    /// The structure format is:
    /// - count: uintptr_t (number of protocols)
    /// - list[count]: Protocol* (array of protocol pointers)
    ///
    /// - Parameter address: Address of the protocol list.
    /// - Returns: Array of protocol addresses.
    /// - Throws: `DataCursorError` if reading protocol list data fails.
    func loadProtocolAddressList(at address: UInt64) throws -> [UInt64] {
        guard address != 0 else { return [] }

        let decodedAddress = decodePointer(address)
        guard let offset = fileOffset(for: decodedAddress) else {
            return []
        }

        // Read count
        let count = try readProtocolListCount(at: offset)
        guard count > 0 && count < 10000 else {
            return []
        }

        // Read protocol addresses
        return try readProtocolAddresses(at: offset + ptrSize, count: Int(count))
    }

    /// Read the count from a protocol list header.
    private func readProtocolListCount(at offset: Int) throws -> UInt64 {
        let countData = try cache.file.data(at: offset, count: ptrSize)
        var cursor = try DataCursor(data: countData)

        let rawCount: UInt64
        if is64Bit {
            rawCount = try cursor.readLittleInt64()
        }
        else {
            rawCount = UInt64(try cursor.readLittleInt32())
        }

        return decodePointer(rawCount)
    }

    /// Read an array of protocol addresses.
    private func readProtocolAddresses(at offset: Int, count: Int) throws -> [UInt64] {
        let listData = try cache.file.data(at: offset, count: count * ptrSize)
        var cursor = try DataCursor(data: listData)

        var addresses: [UInt64] = []
        addresses.reserveCapacity(count)

        for _ in 0..<count {
            let rawAddr = try readPointerValue(from: &cursor)
            let addr = decodePointer(rawAddr)
            if addr != 0 {
                addresses.append(addr)
            }
        }

        return addresses
    }

    // MARK: - Pointer Reading Helpers

    /// Read a pointer value from a cursor based on pointer size.
    func readPointerValue(from cursor: inout DataCursor) throws -> UInt64 {
        guard is64Bit else {
            return UInt64(try cursor.readLittleInt32())
        }
        return try cursor.readLittleInt64()
    }
}
