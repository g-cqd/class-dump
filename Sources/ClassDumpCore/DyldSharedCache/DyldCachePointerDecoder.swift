// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Pointer Decoding

/// Pure functions for decoding chained fixup pointers in dyld_shared_cache.
///
/// In modern DSC (arm64e), pointers use different encodings depending on context:
///
/// 1. **Direct pointers**: Already valid virtual addresses in shared region (0x18...)
/// 2. **Non-authenticated rebases**: 51-bit offset from shared region base (classlist)
/// 3. **Authenticated rebases**: 32-bit offset with PAC in high bits (objc_data)
///
/// This enum provides pure functions to decode these formats.
///
/// ## Usage
///
/// ```swift
/// let decoder = DyldCachePointerDecoder(
///     sharedRegionBase: cache.mappings.first?.address ?? 0,
///     addressValidator: { cache.translator.fileOffsetInt(for: $0) != nil }
/// )
///
/// let decoded = decoder.decode(rawPointer)
/// ```
public struct DyldCachePointerDecoder: Sendable {

    /// Base address of the shared region for offset calculations.
    public let sharedRegionBase: UInt64

    /// Function to validate if an address is valid (maps to a file offset).
    private let addressValidator: @Sendable (UInt64) -> Bool

    /// Maximum offset from shared region base (256GB).
    private static let maxRegionOffset: UInt64 = 0x10_0000_0000

    // MARK: - Initialization

    /// Create a pointer decoder.
    ///
    /// - Parameters:
    ///   - sharedRegionBase: Base address of the shared region.
    ///   - addressValidator: Closure that returns true if an address is valid.
    public init(
        sharedRegionBase: UInt64,
        addressValidator: @escaping @Sendable (UInt64) -> Bool
    ) {
        self.sharedRegionBase = sharedRegionBase
        self.addressValidator = addressValidator
    }

    // MARK: - Decoding

    /// Decode a potentially encoded pointer value.
    ///
    /// Tries multiple decoding strategies and validates which produces a valid address.
    ///
    /// Pure function (deterministic output for given input).
    ///
    /// - Parameter rawPointer: The raw pointer value from the binary.
    /// - Returns: The decoded virtual address, or 0 if decoding fails.
    public func decode(_ rawPointer: UInt64) -> UInt64 {
        guard rawPointer != 0 else { return 0 }

        // Strategy 1: Check if already a valid direct pointer
        if Self.isInSharedRegion(rawPointer, base: sharedRegionBase) {
            return rawPointer
        }

        // Check for encoded format (high bits set)
        let highBits = rawPointer >> 32
        if highBits != 0 {
            // Strategy 2: Try 32-bit offset (authenticated pointers in __objc_data)
            if let decoded = try32BitOffset(rawPointer) {
                return decoded
            }

            // Strategy 3: Try 51-bit offset (non-authenticated rebases in classlist)
            if let decoded = try51BitOffset(rawPointer) {
                return decoded
            }

            // Neither worked
            return 0
        }

        // Small value - might be a direct offset, try adding base
        return tryDirectOffset(rawPointer)
    }

    // MARK: - Decoding Strategies

    /// Try to decode as 32-bit offset (authenticated pointer format).
    ///
    /// Authenticated pointers have PAC/diversity in high bits, offset in lower 32 bits.
    private func try32BitOffset(_ rawPointer: UInt64) -> UInt64? {
        let offset32 = rawPointer & 0xFFFF_FFFF
        let decoded = sharedRegionBase + offset32

        guard Self.isInSharedRegion(decoded, base: sharedRegionBase) else {
            return nil
        }

        guard addressValidator(decoded) else {
            return nil
        }

        return decoded
    }

    /// Try to decode as 51-bit offset (non-authenticated rebase format).
    ///
    /// Non-authenticated rebases use the lower 51 bits as offset from shared region base.
    private func try51BitOffset(_ rawPointer: UInt64) -> UInt64? {
        let offset51 = rawPointer & 0x7_FFFF_FFFF_FFFF
        let decoded = sharedRegionBase + offset51

        guard Self.isInSharedRegion(decoded, base: sharedRegionBase) else {
            return nil
        }

        guard addressValidator(decoded) else {
            return nil
        }

        return decoded
    }

    /// Try to decode as direct offset from base.
    private func tryDirectOffset(_ rawPointer: UInt64) -> UInt64 {
        let withBase = sharedRegionBase + rawPointer

        guard Self.isInSharedRegion(withBase, base: sharedRegionBase) else {
            return rawPointer
        }

        guard addressValidator(withBase) else {
            return rawPointer
        }

        return withBase
    }

    // MARK: - Validation

    /// Check if an address is within the shared region bounds.
    ///
    /// Pure function.
    ///
    /// - Parameters:
    ///   - address: The address to check.
    ///   - base: The shared region base address.
    /// - Returns: True if the address is within bounds.
    public static func isInSharedRegion(_ address: UInt64, base: UInt64) -> Bool {
        address >= base && address < (base + maxRegionOffset)
    }
}

// MARK: - Pointer Clearing

/// Pure functions for clearing pointer flags.
public enum DyldCachePointerFlags {

    /// Clear ObjC data flags from a pointer.
    ///
    /// ObjC class data pointers may have flags in the low bits:
    /// - Bit 0: Swift class marker
    /// - Bit 1: Swift stable ABI marker
    /// - Bit 2: Swift stdlib marker
    ///
    /// Pure function.
    ///
    /// - Parameter pointer: The raw pointer with potential flags.
    /// - Returns: The pointer with flags cleared.
    @inlinable
    public static func clearObjCDataFlags(_ pointer: UInt64) -> UInt64 {
        pointer & ~0x7
    }

    /// Extract ObjC data flags from a pointer.
    ///
    /// Pure function.
    ///
    /// - Parameter pointer: The raw pointer with potential flags.
    /// - Returns: The flag bits (0-7).
    @inlinable
    public static func extractObjCDataFlags(_ pointer: UInt64) -> UInt8 {
        UInt8(pointer & 0x7)
    }

    /// Check if a pointer indicates a Swift class.
    ///
    /// Pure function.
    ///
    /// - Parameter pointer: The raw data pointer.
    /// - Returns: True if the Swift class bit is set.
    @inlinable
    public static func isSwiftClass(_ pointer: UInt64) -> Bool {
        (pointer & 0x1) != 0
    }
}
