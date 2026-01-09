// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Lexer Tests

@Suite("ObjC Type Lexer Tests")
struct ObjCTypeLexerTests {
    @Test("Lexer simple tokens")
    func lexerSimpleTokens() {
        let lexer = ObjCTypeLexer(string: "ic@")
        #expect(lexer.scanNextToken() == .char("i"))
        #expect(lexer.scanNextToken() == .char("c"))
        #expect(lexer.scanNextToken() == .char("@"))
        #expect(lexer.scanNextToken() == .eos)
    }

    @Test("Lexer numbers")
    func lexerNumbers() {
        let lexer = ObjCTypeLexer(string: "123")
        #expect(lexer.scanNextToken() == .number("123"))
    }

    @Test("Lexer negative numbers")
    func lexerNegativeNumbers() {
        let lexer = ObjCTypeLexer(string: "-42")
        #expect(lexer.scanNextToken() == .number("-42"))
    }

    @Test("Lexer quoted string")
    func lexerQuotedString() {
        let lexer = ObjCTypeLexer(string: "\"NSString\"")
        #expect(lexer.scanNextToken() == .quotedString("NSString"))
    }

    @Test("Lexer identifier state")
    func lexerIdentifier() {
        let lexer = ObjCTypeLexer(string: "{CGPoint=dd}")
        #expect(lexer.scanNextToken() == .char("{"))
        lexer.state = .identifier
        #expect(lexer.scanNextToken() == .identifier("CGPoint"))
        #expect(lexer.scanNextToken() == .char("="))
        // In identifier state, "dd" is scanned as an identifier
        // For actual parsing, we reset to normal state after "=" to scan types
        #expect(lexer.scanNextToken() == .identifier("dd"))
        #expect(lexer.scanNextToken() == .char("}"))
        #expect(lexer.scanNextToken() == .eos)
    }
}
