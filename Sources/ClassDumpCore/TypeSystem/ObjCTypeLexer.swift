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

/// Lexer states for context-sensitive tokenization.
public enum ObjCTypeLexerState: Sendable {
    /// Normal scanning mode.
    case normal
    /// Scanning identifiers (after { or ().
    case identifier
    /// Scanning template types.
    case templateTypes
}

/// Tokenizer for Objective-C type encoding strings.
public final class ObjCTypeLexer: @unchecked Sendable {
    /// The input string being tokenized.
    public let string: String

    /// Current position in the string.
    private var index: String.Index

    /// Current lexer state.
    public var state: ObjCTypeLexerState = .normal

    /// The text of the last token scanned.
    public private(set) var lexText: String = ""

    /// Initialize with a type encoding string.
    public init(string: String) {
        // Preprocess: Replace "<unnamed>::" with "unnamed::"
        self.string = string.replacingOccurrences(of: "<unnamed>::", with: "unnamed::")
        self.index = self.string.startIndex
    }

    /// Whether we've reached the end of the string.
    public var isAtEnd: Bool {
        index >= string.endIndex
    }

    /// The remaining unscanned portion of the string.
    public var remainingString: String {
        String(string[index...])
    }

    /// Peek at the next character without consuming it.
    public var peekChar: Character? {
        guard index < string.endIndex else { return nil }
        return string[index]
    }

    /// Peek at the next identifier without consuming it.
    public var peekIdentifier: String? {
        guard index < string.endIndex else { return nil }
        let start = index
        var end = index
        while end < string.endIndex && isIdentifierChar(string[end]) {
            end = string.index(after: end)
        }
        guard end > start else { return nil }
        return String(string[start..<end])
    }

    /// Scan and return the next token.
    public func scanNextToken() -> ObjCTypeToken {
        skipWhitespace()

        guard index < string.endIndex else {
            lexText = ""
            return .eos
        }

        let char = string[index]

        // In identifier state, scan identifiers differently
        if state == .identifier || state == .templateTypes {
            if isIdentifierStartChar(char) {
                return scanIdentifier()
            }
        }

        // Quoted string
        if char == "\"" {
            return scanQuotedString()
        }

        // Number
        if char.isNumber
            || (char == "-" && index < string.index(before: string.endIndex)
                && string[string.index(after: index)].isNumber)
        {
            return scanNumber()
        }

        // Single character token
        index = string.index(after: index)
        lexText = String(char)
        return .char(char)
    }

    // MARK: - Private Scanning Methods

    private func skipWhitespace() {
        while index < string.endIndex && string[index].isWhitespace {
            index = string.index(after: index)
        }
    }

    private func scanQuotedString() -> ObjCTypeToken {
        // Skip opening quote
        index = string.index(after: index)

        let start = index
        while index < string.endIndex && string[index] != "\"" {
            index = string.index(after: index)
        }

        let content = String(string[start..<index])

        // Skip closing quote if present
        if index < string.endIndex && string[index] == "\"" {
            index = string.index(after: index)
        }

        lexText = content
        return .quotedString(content)
    }

    private func scanNumber() -> ObjCTypeToken {
        let start = index

        // Handle negative numbers
        if string[index] == "-" {
            index = string.index(after: index)
        }

        while index < string.endIndex && string[index].isNumber {
            index = string.index(after: index)
        }

        let number = String(string[start..<index])
        lexText = number
        return .number(number)
    }

    private func scanIdentifier() -> ObjCTypeToken {
        let start = index

        while index < string.endIndex && isIdentifierChar(string[index]) {
            index = string.index(after: index)
        }

        let identifier = String(string[start..<index])
        lexText = identifier
        return .identifier(identifier)
    }

    private func isIdentifierStartChar(_ char: Character) -> Bool {
        char.isLetter || char == "_" || char == "$" || char == "?"
    }

    private func isIdentifierChar(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_" || char == "$" || char == ":" || char == "?"
    }
}
