// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("TextClassDumpVisitor Tests")
struct TextClassDumpVisitorTests {
    @Test("TextClassDumpVisitor basic output")
    func textVisitorBasicOutput() {
        let visitor = TextClassDumpVisitor()

        visitor.append("Hello")
        visitor.append(" World")

        #expect(visitor.resultString == "Hello World")
    }

    @Test("TextClassDumpVisitor clear")
    func textVisitorClear() {
        let visitor = TextClassDumpVisitor()

        visitor.append("Test")
        visitor.clearResult()

        #expect(visitor.resultString.isEmpty)
    }

    @Test("TextClassDumpVisitor newline")
    func textVisitorNewline() {
        let visitor = TextClassDumpVisitor()

        visitor.append("Line 1")
        visitor.appendNewline()
        visitor.append("Line 2")

        #expect(visitor.resultString == "Line 1\nLine 2")
    }
}
