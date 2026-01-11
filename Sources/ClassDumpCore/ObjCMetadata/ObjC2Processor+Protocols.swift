// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Protocol loading extensions for ObjC2Processor.
///
/// This extension provides functions for loading ObjC protocols from the
/// binary. Protocols are loaded first during processing because they may
/// be referenced by classes and categories.
extension ObjC2Processor {

    // MARK: - Protocol Collection

    /// Collect all protocol addresses from the binary.
    ///
    /// Reads the `__objc_protolist` section to get pointers to all protocol
    /// definitions in the binary.
    ///
    /// - Returns: Array of protocol virtual addresses.
    func collectProtocolAddresses() throws -> [UInt64] {
        try collectAddresses(
            fromSection: "__objc_protolist",
            inSegments: ["__DATA", "__DATA_CONST"]
        )
    }

    /// Load all protocols in parallel using structured concurrency.
    ///
    /// Uses TaskGroup for parallel loading with thread-safe caching via Mutex.
    ///
    /// - Returns: Array of loaded protocols.
    func loadProtocolsAsync() async throws -> [ObjCProtocol] {
        let addresses = try collectProtocolAddresses()

        return try await withThrowingTaskGroup(
            of: ObjCProtocol?.self,
            returning: [ObjCProtocol].self
        ) { group in
            for address in addresses {
                group.addTask {
                    try await self.loadProtocolAsync(at: address)
                }
            }

            var protocols: [ObjCProtocol] = []
            protocols.reserveCapacity(addresses.count)

            for try await proto in group {
                if let proto = proto {
                    protocols.append(proto)
                }
            }

            return protocols
        }
    }

    // MARK: - Protocol Loading

    /// Load a protocol at the given address.
    ///
    /// Handles caching to ensure protocols are only loaded once, which is
    /// important for handling circular references between protocols.
    ///
    /// - Parameter address: Virtual address of the protocol.
    /// - Returns: The loaded protocol or nil if invalid.
    /// - Throws: `DataCursorError` if reading protocol data fails.
    func loadProtocolAsync(at address: UInt64) async throws -> ObjCProtocol? {
        guard address != 0 else { return nil }

        // Check Mutex cache first (sync)
        if let cached = protocolsByAddress.get(address) {
            return cached
        }

        guard let offset = fileOffset(for: address) else {
            return nil
        }

        var cursor = try DataCursor(data: data, offset: offset)
        let rawProtocol = try ObjC2Protocol(
            cursor: &cursor,
            byteOrder: byteOrder,
            is64Bit: is64Bit,
            ptrSize: ptrSize
        )

        // Decode name address (may be a chained fixup)
        let nameAddr = decodeChainedFixupPointer(rawProtocol.name)
        guard let name = readString(at: nameAddr) else {
            return nil
        }

        let proto = ObjCProtocol(name: name, address: address)

        // Cache immediately to handle circular references (sync)
        protocolsByAddress.set(address, value: proto)

        // Load protocol components
        try await loadProtocolComponents(
            into: proto,
            from: rawProtocol
        )

        return proto
    }

    // MARK: - Protocol Component Loading

    /// Load all components of a protocol (adopted protocols, methods, properties).
    ///
    /// - Parameters:
    ///   - proto: The protocol to populate.
    ///   - rawProtocol: The raw protocol structure.
    /// - Throws: `DataCursorError` if reading protocol component data fails.
    private func loadProtocolComponents(
        into proto: ObjCProtocol,
        from rawProtocol: ObjC2Protocol
    ) async throws {
        // Load adopted protocols
        if rawProtocol.protocols != 0 {
            let adoptedAddresses = try loadProtocolAddressList(at: rawProtocol.protocols)
            for adoptedAddr in adoptedAddresses {
                if let adoptedProto = try await loadProtocolAsync(at: adoptedAddr) {
                    proto.addAdoptedProtocol(adoptedProto)
                }
            }
        }

        // Load required methods
        for method in try loadMethods(
            at: rawProtocol.instanceMethods,
            extendedTypesAddress: rawProtocol.extendedMethodTypes
        ) {
            proto.addInstanceMethod(method)
        }

        for method in try loadMethods(
            at: rawProtocol.classMethods,
            extendedTypesAddress: rawProtocol.extendedMethodTypes
        ) {
            proto.addClassMethod(method)
        }

        // Load optional methods
        for method in try loadMethods(at: rawProtocol.optionalInstanceMethods, extendedTypesAddress: 0) {
            proto.addOptionalInstanceMethod(method)
        }

        for method in try loadMethods(at: rawProtocol.optionalClassMethods, extendedTypesAddress: 0) {
            proto.addOptionalClassMethod(method)
        }

        // Load properties
        for property in try loadProperties(at: rawProtocol.instanceProperties) {
            proto.addProperty(property)
        }
    }

    // MARK: - Protocol Address List Loading

    /// Load a list of protocol addresses from a protocol list pointer.
    ///
    /// Protocol lists start with a count, followed by that many protocol pointers.
    ///
    /// - Parameter address: Virtual address of the protocol list.
    /// - Returns: Array of protocol addresses.
    /// - Throws: `DataCursorError` if reading protocol list data fails.
    func loadProtocolAddressList(at address: UInt64) throws -> [UInt64] {
        guard address != 0 else { return [] }

        let decodedAddress = decodeChainedFixupPointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)

        // First entry is the count
        let count = try readPointerSizedValue(cursor: &cursor)

        // Read protocol addresses
        return try (0..<count)
            .compactMap { _ in
                let rawAddr = try readPointerSizedValue(cursor: &cursor)
                let addr = decodeChainedFixupPointer(rawAddr)
                return addr != 0 ? addr : nil
            }
    }

    /// Read a pointer-sized value from the cursor.
    ///
    /// Pure parsing function that handles both 32-bit and 64-bit formats.
    ///
    /// - Parameter cursor: The data cursor.
    /// - Returns: The read value.
    /// - Throws: `DataCursorError` if reading fails.
    private func readPointerSizedValue(cursor: inout DataCursor) throws -> UInt64 {
        guard is64Bit else {
            let value =
                byteOrder == .little
                ? try cursor.readLittleInt32()
                : try cursor.readBigInt32()
            return UInt64(value)
        }
        return byteOrder == .little
            ? try cursor.readLittleInt64()
            : try cursor.readBigInt64()
    }
}

// MARK: - Protocol Analysis Utilities

/// Pure functions for analyzing ObjC protocols.
public enum ObjCProtocolAnalyzer {

    /// Extract the inheritance chain of a protocol.
    ///
    /// Pure function that collects all adopted protocols recursively.
    ///
    /// - Parameter proto: The protocol to analyze.
    /// - Returns: Set of all protocol names in the inheritance chain.
    public static func inheritanceChain(of proto: ObjCProtocol) -> Set<String> {
        var result = Set<String>()
        collectInheritance(of: proto, into: &result)
        return result
    }

    /// Recursive helper for collecting inheritance.
    private static func collectInheritance(
        of proto: ObjCProtocol,
        into result: inout Set<String>
    ) {
        for adopted in proto.adoptedProtocols where result.insert(adopted.name).inserted {
            collectInheritance(of: adopted, into: &result)
        }
    }

    /// Count total methods in a protocol (including inherited).
    ///
    /// Pure function for protocol complexity analysis.
    ///
    /// - Parameter proto: The protocol to analyze.
    /// - Returns: Total method count.
    public static func totalMethodCount(of proto: ObjCProtocol) -> Int {
        let direct =
            proto.instanceMethods.count
            + proto.classMethods.count
            + proto.optionalInstanceMethods.count
            + proto.optionalClassMethods.count

        let inherited = proto.adoptedProtocols.reduce(0) { sum, adopted in
            sum + totalMethodCount(of: adopted)
        }

        return direct + inherited
    }

    /// Check if a protocol has any optional methods.
    ///
    /// Pure predicate function.
    ///
    /// - Parameter proto: The protocol to check.
    /// - Returns: True if the protocol has optional methods.
    public static func hasOptionalMethods(_ proto: ObjCProtocol) -> Bool {
        !proto.optionalInstanceMethods.isEmpty || !proto.optionalClassMethods.isEmpty
    }

    /// Get all method selectors defined in a protocol.
    ///
    /// Pure function that extracts selector names.
    ///
    /// - Parameter proto: The protocol to analyze.
    /// - Returns: Set of selector names.
    public static func allSelectors(in proto: ObjCProtocol) -> Set<String> {
        var selectors = Set<String>()

        for method in proto.instanceMethods {
            selectors.insert(method.name)
        }
        for method in proto.classMethods {
            selectors.insert(method.name)
        }
        for method in proto.optionalInstanceMethods {
            selectors.insert(method.name)
        }
        for method in proto.optionalClassMethods {
            selectors.insert(method.name)
        }

        return selectors
    }
}
