// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Category Loading

extension DyldCacheObjCProcessor {

    /// Load all ObjC categories from the image.
    ///
    /// Categories are loaded from the `__objc_catlist` section in either
    /// `__DATA` or `__DATA_CONST` segments.
    ///
    /// - Returns: Array of parsed categories.
    /// - Throws: If reading fails.
    func loadCategories() async throws -> [ObjCCategory] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_catlist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_catlist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        return try await parseCategoryList(from: sectionData)
    }

    /// Parse category list from section data.
    ///
    /// - Parameter sectionData: The raw section data containing category addresses.
    /// - Returns: Array of parsed categories.
    /// - Throws: `DataCursorError` if cursor initialization or reading fails.
    private func parseCategoryList(from sectionData: Data) async throws -> [ObjCCategory] {
        var cursor = try DataCursor(data: sectionData)
        var categories: [ObjCCategory] = []

        while cursor.offset < sectionData.count {
            let rawAddress = try readPointerValue(from: &cursor)
            let address = decodePointer(rawAddress)

            if address != 0, let category = try await loadCategory(at: address) {
                categories.append(category)
            }
        }

        return categories
    }

    /// Load a single category at the given address.
    ///
    /// - Parameter address: Virtual address of the category.
    /// - Returns: The parsed category, or nil if loading fails.
    /// - Throws: `DataCursorError` if reading category data fails.
    func loadCategory(at address: UInt64) async throws -> ObjCCategory? {
        guard address != 0 else { return nil }

        // Load category structure
        guard let rawCategory = try loadRawCategory(at: address) else {
            return nil
        }

        // Resolve name
        let nameAddr = decodePointer(rawCategory.name)
        guard let name = readString(at: nameAddr) else {
            return nil
        }

        // Create category
        let category = ObjCCategory(name: name, address: address)

        // Resolve class reference
        try await loadCategoryClassRef(into: category, from: rawCategory.cls)

        // Load methods
        try loadCategoryMethods(into: category, from: rawCategory)

        // Load protocols
        try await loadCategoryProtocols(into: category, from: rawCategory.protocols)

        // Load properties
        for property in try loadProperties(at: rawCategory.instanceProperties) {
            category.addProperty(property)
        }

        return category
    }

    // MARK: - Category Structure Loading

    /// Load the raw ObjC2Category structure at the given address.
    private func loadRawCategory(at address: UInt64) throws -> ObjC2Category? {
        guard let offset = fileOffset(for: address) else {
            return nil
        }

        let catSize = is64Bit ? 48 : 24
        let catData = try cache.file.data(at: offset, count: catSize)
        var cursor = try DataCursor(data: catData)
        return try ObjC2Category(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)
    }

    /// Load the class reference for the category.
    private func loadCategoryClassRef(into category: ObjCCategory, from classPointer: UInt64) async throws {
        let clsAddr = decodePointer(classPointer)
        guard clsAddr != 0 else { return }

        // Try cached class first
        if let cls = classesByAddress.get(clsAddr) {
            category.classRef = ObjCClassReference(name: cls.name, address: clsAddr)
            return
        }

        // Try to load class
        if let cls = try? await loadClass(at: clsAddr) {
            category.classRef = ObjCClassReference(name: cls.name, address: clsAddr)
            return
        }

        // Try external class name
        if let className = readExternalClassName(at: clsAddr) {
            category.classRef = ObjCClassReference(name: className, address: clsAddr)
        }
    }

    /// Load methods into the category.
    private func loadCategoryMethods(into category: ObjCCategory, from rawCategory: ObjC2Category) throws {
        // Instance methods
        for method in try loadMethods(at: rawCategory.instanceMethods) {
            category.addInstanceMethod(method)
        }

        // Class methods
        for method in try loadMethods(at: rawCategory.classMethods) {
            category.addClassMethod(method)
        }
    }

    /// Load adopted protocols into the category.
    private func loadCategoryProtocols(into category: ObjCCategory, from protocolsPointer: UInt64) async throws {
        let protocolAddresses = try loadProtocolAddressList(at: protocolsPointer)

        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress.get(protoAddr) {
                category.addAdoptedProtocol(proto)
            }
            else if let proto = try? await loadProtocol(at: protoAddr) {
                category.addAdoptedProtocol(proto)
            }
        }
    }
}
