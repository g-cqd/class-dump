// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// Pure parsing utilities for Swift name demangling.
///
/// This enum provides a namespace for pure parsing functions used throughout
/// the demangler. All functions are static and pure - they take input and
/// return output without side effects.
///
/// The design favors simplicity and Sendable compliance over the more
/// complex parser combinator pattern.
enum SwiftDemanglerParsers: Sendable {

    // MARK: - Core Parsing Functions

    /// Parse a length-prefixed string.
    ///
    /// Format: `<digits><characters>` where digits encode the length.
    /// Example: `13IDEFoundation` → "IDEFoundation"
    ///
    /// This is the fundamental parser in Swift name demangling.
    ///
    /// - Parameter input: The input substring to parse.
    /// - Returns: Tuple of (parsed string, remaining input) or nil if parsing fails.
    static func lengthPrefixed(_ input: Substring) -> (String, Substring)? {
        var index = input.startIndex
        var lengthStr = ""

        // Collect digits
        while index < input.endIndex, input[index].isNumber {
            lengthStr.append(input[index])
            index = input.index(after: index)
        }

        guard let length = Int(lengthStr), length > 0 else {
            return nil
        }

        let nameStart = index
        guard let nameEnd = input.index(nameStart, offsetBy: length, limitedBy: input.endIndex) else {
            return nil
        }

        let name = String(input[nameStart..<nameEnd])
        return (name, input[nameEnd...])
    }

    /// Parse a sequence of digits from input.
    ///
    /// - Parameter input: The input substring to parse.
    /// - Returns: Tuple of (digit string, remaining input) or nil if no digits found.
    static func digits(_ input: Substring) -> (String, Substring)? {
        guard !input.isEmpty, let first = input.first, first.isNumber else {
            return nil
        }

        var index = input.startIndex
        var result = ""

        while index < input.endIndex, input[index].isNumber {
            result.append(input[index])
            index = input.index(after: index)
        }

        return (result, input[index...])
    }

    /// Take exactly n characters from input.
    ///
    /// - Parameters:
    ///   - n: Number of characters to take.
    ///   - input: The input substring.
    /// - Returns: Tuple of (taken string, remaining input) or nil if not enough characters.
    static func take(_ n: Int, from input: Substring) -> (String, Substring)? {
        guard n >= 0, input.count >= n else {
            return n == 0 ? ("", input) : nil
        }
        let end = input.index(input.startIndex, offsetBy: n)
        return (String(input[..<end]), input[end...])
    }

    /// Skip characters while a predicate holds.
    ///
    /// - Parameters:
    ///   - input: The input substring.
    ///   - predicate: The condition to continue skipping.
    /// - Returns: The remaining input after skipping.
    static func skipWhile(_ input: Substring, while predicate: (Character) -> Bool) -> Substring {
        var index = input.startIndex
        while index < input.endIndex && predicate(input[index]) {
            index = input.index(after: index)
        }
        return input[index...]
    }

    /// Take characters while a predicate holds.
    ///
    /// - Parameters:
    ///   - input: The input substring.
    ///   - predicate: The condition to continue taking.
    /// - Returns: Tuple of (taken string, remaining input).
    static func takeWhile(_ input: Substring, while predicate: (Character) -> Bool) -> (String, Substring) {
        var index = input.startIndex
        while index < input.endIndex && predicate(input[index]) {
            index = input.index(after: index)
        }
        return (String(input[..<index]), input[index...])
    }

    // MARK: - Prefix Checking

    /// Check if input has a specific prefix without consuming it.
    ///
    /// - Parameters:
    ///   - prefix: The prefix to check.
    ///   - input: The input substring.
    /// - Returns: True if the prefix matches.
    static func hasPrefix(_ prefix: String, in input: Substring) -> Bool {
        input.hasPrefix(prefix)
    }

    /// Check if input has a specific suffix.
    ///
    /// - Parameters:
    ///   - suffix: The suffix to check.
    ///   - input: The input substring.
    /// - Returns: True if the suffix matches.
    static func hasSuffix(_ suffix: String, in input: Substring) -> Bool {
        input.hasSuffix(suffix)
    }

    /// Drop a prefix from input if it matches.
    ///
    /// - Parameters:
    ///   - prefix: The prefix to drop.
    ///   - input: The input substring.
    /// - Returns: The remaining input after dropping prefix, or original if no match.
    static func dropPrefix(_ prefix: String, from input: Substring) -> Substring {
        if input.hasPrefix(prefix) {
            return input.dropFirst(prefix.count)
        }
        return input
    }

    // MARK: - Type Suffix Handling

    /// Skip type kind suffixes (C, V, O, P, y).
    ///
    /// These suffixes indicate class, struct, enum, protocol, or other type markers.
    ///
    /// - Parameter input: The input substring.
    /// - Returns: The remaining input after skipping suffixes.
    static func skipTypeSuffixes(_ input: Substring) -> Substring {
        skipWhile(input) { "CVOPy".contains($0) }
    }

    /// Skip protocol existential suffix (_p).
    ///
    /// - Parameter input: The input substring.
    /// - Returns: The remaining input after skipping suffix.
    static func skipProtocolExistential(_ input: Substring) -> Substring {
        if input.hasPrefix("_p") {
            return input.dropFirst(2)
        }
        return input
    }

    // MARK: - Optional Suffix Handling

    /// Check for optional suffix (Sg) and return modified type if found.
    ///
    /// - Parameters:
    ///   - typeName: The base type name.
    ///   - input: The input to check for Sg suffix.
    /// - Returns: Tuple of (possibly modified type name, remaining input).
    static func applyOptionalSuffix(_ typeName: String, to input: Substring) -> (String, Substring) {
        if input.hasPrefix("Sg") {
            return ("\(typeName)?", input.dropFirst(2))
        }
        return (typeName, input)
    }

    // MARK: - Table Lookup Functions

    /// Look up a single character in a type shortcut table.
    ///
    /// - Parameters:
    ///   - char: The character to look up.
    ///   - input: The input substring (for returning remainder).
    /// - Returns: Tuple of (type name, remaining input) or nil.
    static func lookupTypeShortcut(
        _ char: Character,
        from input: Substring
    ) -> (String, Substring)? {
        guard let result = SwiftDemanglerTables.typeShortcut(for: char) else {
            return nil
        }
        return (result, input.dropFirst())
    }

    /// Look up a two-character pattern in the common patterns table.
    ///
    /// - Parameter input: The input substring to check.
    /// - Returns: Tuple of (type name, remaining input) or nil.
    static func lookupTwoCharPattern(_ input: Substring) -> (String, Substring)? {
        guard input.count >= 2 else { return nil }
        let twoChars = String(input.prefix(2))
        guard let result = SwiftDemanglerTables.commonPattern(for: twoChars) else {
            return nil
        }
        return (result, input.dropFirst(2))
    }

    /// Look up a protocol shortcut in the protocol shortcuts table.
    ///
    /// - Parameter input: The input substring to check.
    /// - Returns: Tuple of (protocol name, remaining input) or nil.
    static func lookupProtocolShortcut(_ input: Substring) -> (String, Substring)? {
        guard input.count >= 2 else { return nil }
        let twoChars = String(input.prefix(2))
        guard let result = SwiftDemanglerTables.protocolShortcut(for: twoChars) else {
            return nil
        }
        return (result, input.dropFirst(2))
    }
}
