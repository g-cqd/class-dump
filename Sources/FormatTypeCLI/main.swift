// formatType - Format Objective-C type encodings
// Part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
// Copyright (C) 1997-2019 Steve Nygard. Swift port 2024.

import ClassDumpCore
import Foundation

/// CLI for formatting Objective-C type encodings.
@main
struct FormatTypeCommand {
    /// Format type for displaying type encodings.
    enum FormatType {
        case ivar
        case method
        case balance
    }
    static func main() {
        do {
            try run()
        } catch {
            fputs("Error: \(error)\n", stderr)
            Darwin.exit(1)
        }
    }

    static func run() throws {
        var args = CommandLine.arguments.dropFirst()

        if args.isEmpty {
            printUsage()
            Darwin.exit(0)
        }

        var formatType = FormatType.ivar

        // Parse options
        while let arg = args.first, arg.hasPrefix("-") {
            args = args.dropFirst()

            switch arg {
            case "-m", "--method":
                formatType = .method

            case "-b", "--balance":
                formatType = .balance

            case "-i", "--ivar":
                formatType = .ivar

            case "-h", "--help":
                printUsage()
                Darwin.exit(0)

            case "--version":
                print("formatType 4.0.2 (Swift)")
                Darwin.exit(0)

            default:
                fputs("Error: Unknown option: \(arg)\n", stderr)
                printUsage()
                Darwin.exit(64)
            }
        }

        // Require at least one input file
        guard !args.isEmpty else {
            fputs("Error: No input files specified\n", stderr)
            printUsage()
            Darwin.exit(64)
        }

        // Print format mode
        switch formatType {
        case .ivar: print("Format as ivars")
        case .method: print("Format as methods")
        case .balance: print("Format as balance")
        }

        // Process each input file
        for arg in args {
            let filePath = String(arg)
            print("======================================================================")
            print("File: \(filePath)")

            let content: String
            do {
                content = try String(contentsOfFile: filePath, encoding: .utf8)
            } catch {
                fputs("Error reading file: \(error)\n", stderr)
                continue
            }

            processFile(content: content, formatType: formatType)
        }
    }

    static func printUsage() {
        fputs(
            """
            formatType 4.0.2 (Swift)
            Usage: formatType [options] <input file>...

              where options are:
                    -i, --ivar     format as ivars (default)
                    -m, --method   format as methods
                    -b, --balance  format showing balanced brackets
                    -h, --help     show this help message
                    --version      show version

              Input file format:
                Each type to format consists of two consecutive lines:
                1. The name (variable name or selector)
                2. The type encoding

                Lines starting with // are treated as comments and passed through.
                Empty lines are also passed through.

            """, stderr)
    }

    static func processFile(content: String, formatType: FormatType) {
        let lines = content.components(separatedBy: "\n")

        var name: String?

        for line in lines {
            // Pass through comments and empty lines
            if line.hasPrefix("//") || line.isEmpty {
                print(line)
                continue
            }

            if name == nil {
                name = line
            } else {
                let typeString = line

                let result: String?
                switch formatType {
                case .ivar:
                    result = formatAsIvar(name: name ?? "", typeString: typeString)
                case .method:
                    result = formatAsMethod(name: name ?? "", typeString: typeString)
                case .balance:
                    result = formatAsBalance(typeString: typeString)
                }

                if let str = result {
                    print(str)
                } else {
                    print("Error formatting type.")
                }
                print("----------------------------------------------------------------------")

                name = nil
            }
        }
    }

    static func formatAsIvar(name: String, typeString: String) -> String? {
        // Parse the type
        let type: ObjCType
        do {
            type = try ObjCType.parse(typeString)
        } catch {
            return nil
        }

        // Create formatter with expansion enabled
        let formatter = ObjCTypeFormatter(
            options: ObjCTypeFormatterOptions(
                shouldExpand: true,
                shouldAutoExpand: true
            ))

        return formatter.formatVariable(name: name, type: type)
    }

    static func formatAsMethod(name: String, typeString: String) -> String? {
        let formatter = ObjCTypeFormatter(
            options: ObjCTypeFormatterOptions(
                shouldExpand: false,
                shouldAutoExpand: false
            ))

        return formatter.formatMethodName(name, typeString: typeString)
    }

    static func formatAsBalance(typeString: String) -> String? {
        var balanceFormatter = BalanceFormatter(string: typeString)
        return balanceFormatter.format()
    }
}

// MARK: - Balance Formatter

/// Formats type strings showing balanced bracket structure with indentation.
struct BalanceFormatter {
    private let string: String
    private var index: String.Index
    private var result: String = ""

    private static let openBrackets: [Character] = ["{", "<", "("]
    private static let closeBrackets: [Character] = ["}", ">", ")"]
    private static let bracketSet = CharacterSet(charactersIn: "{}<>()")

    init(string: String) {
        self.string = string
        self.index = string.startIndex
    }

    mutating func format() -> String {
        parse(open: nil, level: 0)
        return result
    }

    private mutating func parse(open: Character?, level: Int) {
        while index < string.endIndex {
            // Scan up to next bracket
            var pre = ""
            while index < string.endIndex {
                let char = string[index]
                if let scalar = char.unicodeScalars.first, Self.bracketSet.contains(scalar) {
                    break
                }
                pre.append(char)
                index = string.index(after: index)
            }

            if !pre.isEmpty {
                appendIndented(pre, level: level)
            }

            guard index < string.endIndex else { break }

            let char = string[index]

            // Check for open brackets
            if let openIndex = Self.openBrackets.firstIndex(of: char) {
                index = string.index(after: index)
                appendIndented(String(char), level: level)
                parse(open: char, level: level + 1)
                appendIndented(String(Self.closeBrackets[openIndex]), level: level)
                continue
            }

            // Check for close brackets
            if let closeIndex = Self.closeBrackets.firstIndex(of: char) {
                if let open = open, Self.openBrackets.firstIndex(of: open) == closeIndex {
                    // Matching close - return to parent
                    index = string.index(after: index)
                    return
                } else {
                    // Unmatched close - error but continue
                    result += "ERROR: Unmatched \(char)\n"
                    index = string.index(after: index)
                    return
                }
            }

            // Unknown character at bracket position - shouldn't happen
            index = string.index(after: index)
        }
    }

    private mutating func appendIndented(_ text: String, level: Int) {
        let indent = String(repeating: "    ", count: level)
        result += indent + text + "\n"
    }
}
