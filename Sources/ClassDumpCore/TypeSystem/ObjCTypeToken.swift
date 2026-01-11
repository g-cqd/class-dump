// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Tokens produced by the type lexer.
public enum ObjCTypeToken: Sendable, Equatable {
    /// End of string.
    case eos
    /// A number (e.g., array size, bitfield size, stack offset).
    case number(String)
    /// An identifier (e.g., struct name, variable name).
    case identifier(String)
    /// A quoted string (e.g., class name, variable name in struct).
    case quotedString(String)
    /// A single character token (e.g., type codes, delimiters).
    case char(Character)
}
