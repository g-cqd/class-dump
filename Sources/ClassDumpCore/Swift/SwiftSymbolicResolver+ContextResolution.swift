// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Context Descriptor Resolution

extension SwiftSymbolicResolver {

    /// Resolve a direct context descriptor reference.
    ///
    /// Context descriptors contain type metadata including flags, parent, and name.
    /// The name is typically at offset 8 as a relative pointer.
    ///
    /// - Parameters:
    ///   - offset: File offset of the context descriptor.
    ///   - mangledData: Original mangled data for fallback resolution.
    /// - Returns: The resolved type name.
    func resolveContextDescriptor(at offset: Int, mangledData: Data) -> String {
        guard offset >= 0, offset + 16 <= dataCount else {
            return "/* invalid offset: \(offset) */"
        }

        // Try to read the name at standard offset (8 bytes after flags and parent)
        let nameOffset = offset + 8
        if let name = readRelativeString(at: nameOffset), !name.isEmpty {
            return buildFullTypeName(name: name, parentOffset: offset + 4, mangledData: mangledData)
        }

        // Try alternate layout - sometimes name is at offset 12
        let altNameOffset = offset + 12
        if let altName = readRelativeString(at: altNameOffset), !altName.isEmpty {
            return altName
        }

        return resolveFromMangledSuffix(mangledData)
    }

    /// Build the full type name including parent context.
    private func buildFullTypeName(name: String, parentOffset: Int, mangledData: Data) -> String {
        let parentName = resolveParentContext(at: parentOffset)

        // Build qualified name
        let fullName: String
        if let parent = parentName, !parent.isEmpty, parent != "Swift" {
            fullName = "\(parent).\(name)"
        }
        else {
            fullName = name
        }

        // Handle generic types - check for suffix data
        if mangledData.count > 5 {
            let (suffix, _) = resolveGenericSuffix(mangledData: mangledData, offset: parentOffset + 1)
            if !suffix.isEmpty {
                return "\(fullName)\(suffix)"
            }
        }

        return fullName
    }

    /// Resolve an indirect context descriptor (pointer to pointer).
    ///
    /// Indirect references (0x02) point to a location that contains a pointer
    /// to the actual type context descriptor. This is typically used for
    /// external types from other modules.
    ///
    /// - Parameters:
    ///   - offset: File offset of the indirect reference.
    ///   - mangledData: Original mangled data for fallback resolution.
    /// - Returns: The resolved type name.
    func resolveIndirectContextDescriptor(at offset: Int, mangledData: Data) -> String {
        guard offset >= 0, offset + 8 <= dataCount else {
            return "/* invalid indirect offset */"
        }

        // Read the target pointer (typically 64-bit)
        let targetPointer = readUInt64(at: offset)

        // Try chained fixups first
        if let result = tryResolveViaChainedFixups(
            targetPointer: targetPointer,
            offset: offset,
            mangledData: mangledData
        ) {
            return result
        }

        // Handle zero pointer (unresolved external reference)
        if targetPointer == 0 {
            if mangledData.count > 5 {
                return resolveFromMangledSuffix(mangledData)
            }
            return "/* external type */"
        }

        // Try to resolve as VM address
        if let result = tryResolveAsVMAddress(
            address: targetPointer,
            mangledData: mangledData
        ) {
            return result
        }

        // Try as direct file offset
        if targetPointer < UInt64(dataCount) {
            return resolveContextDescriptor(at: Int(targetPointer), mangledData: mangledData)
        }

        // Try 32-bit pointer (for 32-bit binaries)
        if let result = tryResolve32BitPointer(
            at: offset,
            mangledData: mangledData
        ) {
            return result
        }

        // Final fallback
        if mangledData.count > 5 {
            return resolveFromMangledSuffix(mangledData)
        }

        return "/* unresolved indirect */"
    }

    /// Try to resolve via chained fixups.
    private func tryResolveViaChainedFixups(
        targetPointer: UInt64,
        offset: Int,
        mangledData: Data
    ) -> String? {
        guard let fixups = chainedFixups else { return nil }

        let result = fixups.decodePointer(targetPointer)
        switch result {
            case .bind(let ordinal, _):
                // Bound to an external symbol
                if let symbolName = fixups.symbolName(forOrdinal: ordinal) {
                    return SwiftDemangler.extractTypeName(symbolName)
                }
            case .rebase(let target):
                // Rebase to local address
                if let fileOff = self.fileOffset(for: target) {
                    return resolveContextDescriptor(at: fileOff, mangledData: mangledData)
                }
            case .notFixup:
                break
        }

        return nil
    }

    /// Try to resolve as a VM address.
    private func tryResolveAsVMAddress(address: UInt64, mangledData: Data) -> String? {
        guard let fileOff = self.fileOffset(for: address) else {
            return nil
        }
        return resolveContextDescriptor(at: fileOff, mangledData: mangledData)
    }

    /// Try to resolve as a 32-bit pointer.
    private func tryResolve32BitPointer(at offset: Int, mangledData: Data) -> String? {
        let targetPointer32 = readUInt32(at: offset)
        guard targetPointer32 != 0 else { return nil }

        if let fileOff = self.fileOffset(for: UInt64(targetPointer32)) {
            return resolveContextDescriptor(at: fileOff, mangledData: mangledData)
        }

        return nil
    }

    /// Resolve an Objective-C protocol reference.
    ///
    /// ObjC protocol references point to protocol structures containing
    /// the protocol name.
    ///
    /// - Parameter offset: File offset of the protocol reference.
    /// - Returns: The protocol name.
    func resolveObjCProtocol(at offset: Int) -> String {
        guard offset >= 0, offset + 8 <= dataCount else {
            return "/* invalid protocol offset */"
        }

        // Try as pointer to C string
        let namePointer = readUInt64(at: offset)
        if let name = readString(at: namePointer) {
            return name
        }

        // Try as relative pointer
        if let name = readRelativeString(at: offset) {
            return name
        }

        return "/* unknown protocol */"
    }

    /// Resolve the parent context (module or enclosing type).
    ///
    /// - Parameter offset: File offset of the parent pointer.
    /// - Returns: The parent name, or nil if resolution fails.
    func resolveParentContext(at offset: Int) -> String? {
        guard let parentDescOffset = readRelativePointer(at: offset) else {
            return nil
        }

        // Check cache
        if let cached = getCachedModuleName(at: parentDescOffset) {
            return cached
        }

        guard parentDescOffset > 0, parentDescOffset + 8 <= dataCount else {
            return nil
        }

        // Read parent flags to determine kind
        let flags = readUInt32(at: parentDescOffset)
        let kind = flags & 0x1F

        // Kind 0 = Module descriptor
        if kind == 0 {
            let nameOffset = parentDescOffset + 8
            if let name = readRelativeString(at: nameOffset) {
                cacheModuleName(name, at: parentDescOffset)
                return name
            }
        }

        // Otherwise it might be an enclosing type
        let nameOffset = parentDescOffset + 8
        if let name = readRelativeString(at: nameOffset) {
            cacheModuleName(name, at: parentDescOffset)
            return name
        }

        return nil
    }

    // MARK: - Suffix Resolution

    /// Try to extract type name from mangled suffix after symbolic ref.
    func resolveFromMangledSuffix(_ mangledData: Data) -> String {
        guard mangledData.count > 5 else { return "/* type */" }

        let suffix = mangledData.subdata(in: 5..<mangledData.count)
        if let suffixStr = String(data: suffix, encoding: .utf8) {
            return SwiftDemangler.demangle(suffixStr)
        }

        return "/* type */"
    }

    /// Resolve generic type parameters from mangled suffix.
    ///
    /// - Parameters:
    ///   - mangledData: The full mangled data.
    ///   - offset: The source offset for embedded ref resolution.
    /// - Returns: Tuple of (resolved generic string, bytes consumed).
    func resolveGenericSuffix(mangledData: Data, offset: Int) -> (String, Int) {
        guard mangledData.count > 5 else { return ("", 0) }

        let suffix = mangledData.subdata(in: 5..<mangledData.count)

        // If suffix contains embedded symbolic references, resolve them
        if hasEmbeddedSymbolicRef(suffix) {
            return resolveGenericWithEmbeddedRefs(suffix: suffix, offset: offset)
        }

        // Check for common patterns
        if let suffixStr = String(data: suffix, encoding: .utf8) {
            return resolveGenericFromString(suffixStr, suffixCount: suffix.count)
        }

        return ("", 0)
    }

    /// Resolve generic parameters from suffix with embedded refs.
    private func resolveGenericWithEmbeddedRefs(suffix: Data, offset: Int) -> (String, Int) {
        let resolvedSuffix = resolveTypeWithEmbeddedRefs(mangledData: suffix, sourceOffset: offset)

        // Check for generic pattern
        if resolvedSuffix.hasPrefix("y") {
            var params = resolvedSuffix.dropFirst()
            if params.hasSuffix("G") {
                params = params.dropLast()
            }

            if !params.isEmpty {
                let demangled = SwiftDemangler.demangleComplexType(String(params))
                return ("<\(demangled)>", suffix.count)
            }
        }

        return ("", 0)
    }

    /// Resolve generic parameters from a string suffix.
    private func resolveGenericFromString(_ suffixStr: String, suffixCount: Int) -> (String, Int) {
        // "Sg" = Optional wrapper
        if suffixStr.hasSuffix("Sg") || suffixStr.contains("Sg") {
            return ("?", suffixCount)
        }

        // "y" prefix = generic parameter
        if suffixStr.hasPrefix("y") {
            var params = suffixStr.dropFirst()
            if params.hasSuffix("G") {
                params = params.dropLast()
            }
            if !params.isEmpty {
                let demangled = SwiftDemangler.demangleComplexType(String(params))
                if demangled != String(params) || !demangled.isEmpty {
                    return ("<\(demangled)>", suffixCount)
                }
            }
        }

        return ("", 0)
    }
}
