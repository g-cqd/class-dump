// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Import Format

/// Import table format from dyld_chained_fixups_header.imports_format.
public enum ChainedImportFormat: UInt32, Sendable {
    case standard = 1  // DYLD_CHAINED_IMPORT
    case addend = 2  // DYLD_CHAINED_IMPORT_ADDEND
    case addend64 = 3  // DYLD_CHAINED_IMPORT_ADDEND64
}
