// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Chained Fixups Error

/// Errors that can occur when parsing chained fixups.
public enum ChainedFixupsError: Error, Sendable {
    case dataTooSmall
    case invalidFormat
    case unsupportedPointerFormat(UInt16)
    case symbolNotFound(ordinal: UInt32)
}
