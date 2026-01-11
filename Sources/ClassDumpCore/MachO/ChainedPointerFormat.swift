// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Pointer Format Types

/// Chained pointer format types from dyld.
public enum ChainedPointerFormat: UInt16, Sendable {
    case arm64e = 1  // DYLD_CHAINED_PTR_ARM64E
    case ptr64 = 2  // DYLD_CHAINED_PTR_64
    case ptr32 = 3  // DYLD_CHAINED_PTR_32
    case ptr32Cache = 4  // DYLD_CHAINED_PTR_32_CACHE
    case ptr32Firmware = 5  // DYLD_CHAINED_PTR_32_FIRMWARE
    case ptr64Offset = 6  // DYLD_CHAINED_PTR_64_OFFSET
    case arm64eKernel = 7  // DYLD_CHAINED_PTR_ARM64E_KERNEL
    case ptr64KernelCache = 8  // DYLD_CHAINED_PTR_64_KERNEL_CACHE
    case arm64eUserland = 9  // DYLD_CHAINED_PTR_ARM64E_USERLAND
    case arm64eFirmware = 10  // DYLD_CHAINED_PTR_ARM64E_FIRMWARE
    // swift-format-ignore: AlwaysUseLowerCamelCase
    case x86_64KernelCache = 11  // DYLD_CHAINED_PTR_X86_64_KERNEL_CACHE
    case arm64eUserland24 = 12  // DYLD_CHAINED_PTR_ARM64E_USERLAND24
    case arm64eSharedCache = 13  // DYLD_CHAINED_PTR_ARM64E_SHARED_CACHE
    case arm64eSegmented = 14  // DYLD_CHAINED_PTR_ARM64E_SEGMENTED

    /// Stride in bytes between fixup locations.
    public var stride: Int {
        switch self {
            case .arm64e, .arm64eUserland, .arm64eUserland24, .arm64eSharedCache:
                return 8
            case .arm64eKernel, .arm64eFirmware, .ptr32Firmware, .ptr64, .ptr64Offset,
                .ptr32, .ptr32Cache, .ptr64KernelCache, .arm64eSegmented:
                return 4
            case .x86_64KernelCache:
                return 1
        }
    }

    /// Pointer size in bytes.
    public var pointerSize: Int {
        switch self {
            case .ptr32, .ptr32Cache, .ptr32Firmware:
                return 4
            default:
                return 8
        }
    }
}
