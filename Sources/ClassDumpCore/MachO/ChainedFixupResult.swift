// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Fixup Result

/// Result of resolving a chained fixup pointer.
public enum ChainedFixupResult: Sendable {
    /// A rebase to an internal address.
    case rebase(target: UInt64)
    /// A bind to an external symbol.
    case bind(ordinal: UInt32, addend: Int64)
    /// Not a chained fixup pointer.
    case notFixup
}
