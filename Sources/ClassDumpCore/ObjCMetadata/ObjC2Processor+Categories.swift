// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Category loading extensions for ObjC2Processor.
///
/// This extension provides functions for loading ObjC categories from the binary.
/// Categories extend existing classes with additional methods and properties.
/// They are loaded last since they reference classes by address or external symbol.
extension ObjC2Processor {

    // MARK: - Category Collection

    /// Collect all category addresses from the binary.
    ///
    /// Reads the `__objc_catlist` section to get pointers to all category
    /// definitions in the binary.
    ///
    /// - Returns: Array of category virtual addresses.
    func collectCategoryAddresses() throws -> [UInt64] {
        try collectAddresses(
            fromSection: "__objc_catlist",
            inSegments: ["__DATA", "__DATA_CONST"]
        )
    }

    /// Load all categories using async processing.
    ///
    /// Categories typically have fewer entries than classes, so parallel loading
    /// provides less benefit. This uses sequential async for simplicity.
    ///
    /// - Returns: Array of loaded categories.
    func loadCategoriesAsync() async throws -> [ObjCCategory] {
        let addresses = try collectCategoryAddresses()

        var categories: [ObjCCategory] = []
        categories.reserveCapacity(addresses.count)

        for address in addresses {
            if let category = try await loadCategoryAsync(at: address) {
                categories.append(category)
            }
        }

        return categories
    }

    // MARK: - Category Loading

    /// Load a category at the given address.
    ///
    /// - Parameter address: Virtual address of the category.
    /// - Returns: The loaded category or nil if invalid.
    /// - Throws: `DataCursorError` if reading category data fails.
    func loadCategoryAsync(at address: UInt64) async throws -> ObjCCategory? {
        guard address != 0 else { return nil }
        guard let offset = fileOffset(for: address) else { return nil }

        var cursor = try DataCursor(data: data, offset: offset)
        let rawCategory = try ObjC2Category(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Decode name address (may be a chained fixup)
        let nameAddr = decodeChainedFixupPointer(rawCategory.name)
        guard let name = readString(at: nameAddr) else {
            return nil
        }

        let category = ObjCCategory(name: name, address: address)

        // Load category components
        try await loadCategoryComponents(
            into: category,
            from: rawCategory
        )

        return category
    }

    // MARK: - Category Component Loading

    /// Load all components of a category (class ref, methods, protocols, properties).
    ///
    /// - Parameters:
    ///   - category: The category to populate.
    ///   - rawCategory: The raw category structure.
    /// - Throws: `DataCursorError` if reading category component data fails.
    private func loadCategoryComponents(
        into category: ObjCCategory,
        from rawCategory: ObjC2Category
    ) async throws {
        // Set class reference
        category.classRef = try await loadCategoryClassReference(from: rawCategory)

        // Load instance methods
        for method in try loadMethods(at: rawCategory.instanceMethods) {
            category.addInstanceMethod(method)
        }

        // Load class methods
        for method in try loadMethods(at: rawCategory.classMethods) {
            category.addClassMethod(method)
        }

        // Load protocols using Mutex cache (sync)
        let protocolAddresses = try loadProtocolAddressList(at: rawCategory.protocols)
        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress.get(protoAddr) {
                category.addAdoptedProtocol(proto)
            }
            else if let proto = try? await loadProtocolAsync(at: protoAddr) {
                category.addAdoptedProtocol(proto)
            }
        }

        // Load properties
        for property in try loadProperties(at: rawCategory.instanceProperties) {
            category.addProperty(property)
        }
    }

    // MARK: - Category Class Reference Loading

    /// Load the class reference for a category.
    ///
    /// The category may reference a class by address (internal) or by symbol
    /// name (external, like NSString from Foundation).
    ///
    /// - Parameter rawCategory: The raw category structure.
    /// - Returns: The class reference or nil.
    /// - Throws: `DataCursorError` if reading class reference data fails.
    private func loadCategoryClassReference(
        from rawCategory: ObjC2Category
    ) async throws -> ObjCClassReference? {
        let clsResult = decodePointerWithBindInfo(rawCategory.cls)

        switch clsResult {
            case .address(let clsAddr):
                guard clsAddr != 0 else { return nil }
                // Try to get from cache first
                if let aClass = classesByAddress.get(clsAddr) {
                    return ObjCClassReference(name: aClass.name, address: clsAddr)
                }
                // Try to load the class
                if let aClass = try? await loadClassAsync(at: clsAddr) {
                    return ObjCClassReference(name: aClass.name, address: clsAddr)
                }
                return nil

            case .bindSymbol(let symbolName):
                let className = extractCategoryClassName(from: symbolName)
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
    private func extractCategoryClassName(from symbolName: String) -> String {
        if symbolName.hasPrefix("OBJC_CLASS_$_") {
            return String(symbolName.dropFirst("OBJC_CLASS_$_".count))
        }
        return symbolName
    }
}

// MARK: - Category Analysis Utilities

/// Pure functions for analyzing ObjC categories.
public enum ObjCCategoryAnalyzer {

    /// Get all method selectors defined in a category.
    ///
    /// Pure function that extracts selector names.
    ///
    /// - Parameter category: The category to analyze.
    /// - Returns: Set of selector names.
    public static func allSelectors(in category: ObjCCategory) -> Set<String> {
        var selectors = Set<String>()
        for method in category.instanceMethods {
            selectors.insert(method.name)
        }
        for method in category.classMethods {
            selectors.insert(method.name)
        }
        return selectors
    }

    /// Get all property names in a category.
    ///
    /// Pure function that extracts property names.
    ///
    /// - Parameter category: The category to analyze.
    /// - Returns: Set of property names.
    public static func allProperties(in category: ObjCCategory) -> Set<String> {
        Set(category.properties.map(\.name))
    }

    /// Count total members in a category.
    ///
    /// Pure function for category complexity analysis.
    ///
    /// - Parameter category: The category to analyze.
    /// - Returns: Total member count.
    public static func totalMemberCount(of category: ObjCCategory) -> Int {
        category.instanceMethods.count
            + category.classMethods.count
            + category.properties.count
    }

    /// Check if a category extends a specific class.
    ///
    /// Pure predicate function.
    ///
    /// - Parameters:
    ///   - category: The category to check.
    ///   - className: The class name to look for.
    /// - Returns: True if the category extends the class.
    public static func extendsClass(_ category: ObjCCategory, named className: String) -> Bool {
        category.classRef?.name == className
    }

    /// Get the canonical name for a category.
    ///
    /// Pure function that creates the "ClassName (CategoryName)" format.
    ///
    /// - Parameter category: The category.
    /// - Returns: The canonical category name.
    public static func canonicalName(of category: ObjCCategory) -> String {
        if let classRef = category.classRef {
            return "\(classRef.name) (\(category.name))"
        }
        return "? (\(category.name))"
    }

    /// Group categories by their target class.
    ///
    /// Pure function for organizing categories.
    ///
    /// - Parameter categories: Array of categories to group.
    /// - Returns: Dictionary mapping class names to categories.
    public static func groupByClass(_ categories: [ObjCCategory]) -> [String: [ObjCCategory]] {
        Dictionary(grouping: categories) { category in
            category.classRef?.name ?? "Unknown"
        }
    }
}
