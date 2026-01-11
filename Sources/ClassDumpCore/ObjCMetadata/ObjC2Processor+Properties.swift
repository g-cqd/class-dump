// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Property and instance variable loading extensions for ObjC2Processor.
///
/// This extension provides parsing functions for ObjC properties and instance
/// variables. Properties have attribute strings that encode type information,
/// while ivars may need Swift type resolution for Swift classes.
extension ObjC2Processor {

    // MARK: - Property Loading

    /// Load properties from a property list at the given address.
    ///
    /// - Parameter address: Virtual address of the property list.
    /// - Returns: Array of parsed properties.
    /// - Throws: `DataCursorError` if reading property list data fails.
    func loadProperties(at address: UInt64) throws -> [ObjCProperty] {
        guard address != 0 else { return [] }

        let decodedAddress = decodeChainedFixupPointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        let listHeader = try ObjC2ListHeader(cursor: &cursor, byteOrder: byteOrder)

        return try (0..<listHeader.count)
            .compactMap { _ in
                try parseProperty(cursor: &cursor)
            }
    }

    /// Parse a single property entry.
    ///
    /// - Parameter cursor: Data cursor at the property entry position.
    /// - Returns: Parsed property or nil if invalid.
    /// - Throws: `DataCursorError` if reading property entry fails.
    private func parseProperty(cursor: inout DataCursor) throws -> ObjCProperty? {
        let rawProperty = try ObjC2Property(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Decode chained fixup pointers for name and attributes
        let nameAddr = decodeChainedFixupPointer(rawProperty.name)
        guard let name = readString(at: nameAddr) else { return nil }

        let attrAddr = decodeChainedFixupPointer(rawProperty.attributes)
        let attributeString = readString(at: attrAddr) ?? ""

        return ObjCProperty(name: name, attributeString: attributeString)
    }

    // MARK: - Instance Variable Loading

    /// Load instance variables from an ivar list at the given address.
    ///
    /// For Swift classes, this function attempts to resolve richer type
    /// information from Swift field descriptors via the symbolic resolver.
    ///
    /// - Parameters:
    ///   - address: Virtual address of the ivar list.
    ///   - className: Name of the containing class (for Swift type resolution).
    ///   - isSwiftClass: Whether the class is a Swift class.
    /// - Returns: Array of parsed instance variables.
    /// - Throws: `DataCursorError` if reading ivar list data fails.
    func loadInstanceVariables(
        at address: UInt64,
        className: String = "",
        isSwiftClass: Bool = false
    ) async throws -> [ObjCInstanceVariable] {
        guard address != 0 else { return [] }

        let decodedAddress = decodeChainedFixupPointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        let listHeader = try ObjC2ListHeader(cursor: &cursor, byteOrder: byteOrder)

        // Determine if we should try Swift type resolution
        let shouldResolveSwiftTypes = swiftMetadata != nil || isSwiftClass || self.isSwiftClass(name: className)

        var ivars: [ObjCInstanceVariable] = []
        ivars.reserveCapacity(Int(listHeader.count))

        for _ in 0..<listHeader.count {
            if let ivar = try await parseInstanceVariable(
                cursor: &cursor,
                className: className,
                resolveSwiftTypes: shouldResolveSwiftTypes
            ) {
                ivars.append(ivar)
            }
        }

        return ivars
    }

    /// Parse a single instance variable entry.
    ///
    /// - Parameters:
    ///   - cursor: Data cursor at the ivar entry position.
    ///   - className: Name of the containing class.
    ///   - resolveSwiftTypes: Whether to attempt Swift type resolution.
    /// - Returns: Parsed ivar or nil if invalid.
    /// - Throws: `DataCursorError` if reading ivar entry fails.
    private func parseInstanceVariable(
        cursor: inout DataCursor,
        className: String,
        resolveSwiftTypes: Bool
    ) async throws -> ObjCInstanceVariable? {
        let rawIvar = try ObjC2Ivar(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Decode chained fixup pointers
        let nameAddr = decodeChainedFixupPointer(rawIvar.name)
        guard nameAddr != 0 else { return nil }
        guard let name = readString(at: nameAddr) else { return nil }

        let typeAddr = decodeChainedFixupPointer(rawIvar.type)
        let typeEncoding = readString(at: typeAddr) ?? ""

        // Resolve Swift type if applicable
        var typeString = ""
        if resolveSwiftTypes {
            typeString = await resolveSwiftIvarType(className: className, ivarName: name) ?? ""
        }

        // Read the actual offset value
        let actualOffset = try readIvarOffset(rawIvar: rawIvar)

        return ObjCInstanceVariable(
            name: name,
            typeEncoding: typeEncoding,
            typeString: typeString,
            offset: actualOffset,
            size: UInt64(rawIvar.size),
            alignment: rawIvar.alignment
        )
    }

    /// Read the actual offset value from an ivar's offset pointer.
    ///
    /// The ivar structure contains a pointer to the offset value, not the
    /// offset itself. This function dereferences that pointer.
    ///
    /// - Parameter rawIvar: The raw ivar structure.
    /// - Returns: The actual byte offset of the ivar.
    /// - Throws: `DataCursorError` if reading offset data fails.
    private func readIvarOffset(rawIvar: ObjC2Ivar) throws -> UInt64 {
        let offsetAddr = decodeChainedFixupPointer(rawIvar.offset)
        guard offsetAddr != 0, let offsetPtr = fileOffset(for: offsetAddr) else {
            return 0
        }

        var offsetCursor = try DataCursor(data: data, offset: offsetPtr)

        // The offset is stored as a pointer-sized value but represents a 32-bit offset
        guard is64Bit else {
            let value =
                byteOrder == .little
                ? try offsetCursor.readLittleInt32()
                : try offsetCursor.readBigInt32()
            return UInt64(value)
        }
        let value =
            byteOrder == .little
            ? try offsetCursor.readLittleInt64()
            : try offsetCursor.readBigInt64()
        return UInt64(UInt32(truncatingIfNeeded: value))
    }
}

// MARK: - Property Attribute Parsing

/// Pure functions for parsing ObjC property attribute strings.
///
/// Property attributes encode type information, getter/setter names,
/// and other metadata in a compact string format.
public enum ObjCPropertyAttributeParser {

    /// Parse a property attribute string into components.
    ///
    /// Pure function that extracts individual attributes from the string.
    ///
    /// Format: `T<type>,<attr>,<attr>,...`
    ///
    /// - Parameter attributeString: The raw attribute string.
    /// - Returns: Dictionary mapping attribute keys to values.
    public static func parse(_ attributeString: String) -> [Character: String] {
        guard !attributeString.isEmpty else { return [:] }

        var result: [Character: String] = [:]
        let components = attributeString.split(separator: ",")

        for component in components {
            guard let firstChar = component.first else { continue }
            let value = String(component.dropFirst())
            result[firstChar] = value
        }

        return result
    }

    /// Extract the type encoding from property attributes.
    ///
    /// - Parameter attributes: Parsed attribute dictionary.
    /// - Returns: The type encoding string or nil.
    public static func typeEncoding(from attributes: [Character: String]) -> String? {
        attributes["T"]
    }

    /// Extract the getter name from property attributes.
    ///
    /// - Parameter attributes: Parsed attribute dictionary.
    /// - Returns: Custom getter name or nil for default.
    public static func getterName(from attributes: [Character: String]) -> String? {
        attributes["G"]
    }

    /// Extract the setter name from property attributes.
    ///
    /// - Parameter attributes: Parsed attribute dictionary.
    /// - Returns: Custom setter name or nil for default.
    public static func setterName(from attributes: [Character: String]) -> String? {
        attributes["S"]
    }

    /// Check if property is read-only.
    ///
    /// - Parameter attributes: Parsed attribute dictionary.
    /// - Returns: True if the property is read-only.
    public static func isReadOnly(from attributes: [Character: String]) -> Bool {
        attributes["R"] != nil
    }

    /// Check if property uses copy semantics.
    ///
    /// - Parameter attributes: Parsed attribute dictionary.
    /// - Returns: True if the property uses copy.
    public static func isCopy(from attributes: [Character: String]) -> Bool {
        attributes["C"] != nil
    }

    /// Check if property uses retain/strong semantics.
    ///
    /// - Parameter attributes: Parsed attribute dictionary.
    /// - Returns: True if the property retains.
    public static func isRetain(from attributes: [Character: String]) -> Bool {
        attributes["&"] != nil
    }

    /// Check if property is nonatomic.
    ///
    /// - Parameter attributes: Parsed attribute dictionary.
    /// - Returns: True if nonatomic.
    public static func isNonatomic(from attributes: [Character: String]) -> Bool {
        attributes["N"] != nil
    }

    /// Check if property is weak.
    ///
    /// - Parameter attributes: Parsed attribute dictionary.
    /// - Returns: True if weak reference.
    public static func isWeak(from attributes: [Character: String]) -> Bool {
        attributes["W"] != nil
    }

    /// Get the backing ivar name.
    ///
    /// - Parameter attributes: Parsed attribute dictionary.
    /// - Returns: The backing ivar name or nil.
    public static func ivarName(from attributes: [Character: String]) -> String? {
        attributes["V"]
    }
}
