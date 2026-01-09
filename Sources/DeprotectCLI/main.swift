// deprotect - Decrypts protected Mach-O segments
// Part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
// Copyright (C) 1997-2019 Steve Nygard. Swift port 2024.

import ClassDumpCore
import Foundation
import MachO

/// CLI for decrypting protected Mach-O segments.
@main
struct DeprotectCommand {
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

        var archName: String?

        // Parse options
        while let arg = args.first, arg.hasPrefix("-") {
            args = args.dropFirst()

            switch arg {
            case "-a", "--arch":
                guard let name = args.first else {
                    fputs("Error: --arch requires an argument\n", stderr)
                    printUsage()
                    Darwin.exit(64)
                }
                args = args.dropFirst()
                archName = name

            case "-h", "--help":
                printUsage()
                Darwin.exit(0)

            case "--version":
                print("deprotect 4.0.2 (Swift)")
                Darwin.exit(0)

            default:
                fputs("Error: Unknown option: \(arg)\n", stderr)
                printUsage()
                Darwin.exit(64)
            }
        }

        // Require input and output files
        guard args.count >= 2 else {
            fputs("Error: Missing input or output file\n", stderr)
            printUsage()
            Darwin.exit(64)
        }

        let inputPath = String(args[args.startIndex])
        let outputPath = String(args[args.index(after: args.startIndex)])

        // Load the file
        let inputURL = URL(fileURLWithPath: inputPath)
        guard FileManager.default.fileExists(atPath: inputPath) else {
            fputs("Error: Input file not found: \(inputPath)\n", stderr)
            Darwin.exit(66)
        }

        let binary = try MachOBinary(contentsOf: inputURL)

        // Select architecture
        let machOFile: MachOFile
        if let name = archName {
            guard let arch = Arch(name: name) else {
                fputs("Error: Unknown architecture: \(name)\n", stderr)
                Darwin.exit(64)
            }
            machOFile = try binary.machOFile(for: arch)
        } else {
            machOFile = try binary.bestMatchForLocal()
        }

        // Deprotect the file
        let result = try deprotect(machOFile: machOFile, outputPath: outputPath)

        if result.protectedSegmentCount == 0 {
            fputs("Error: Input file (\(machOFile.archName) arch) is not protected.\n", stderr)
            Darwin.exit(65)
        }

        print("Decrypted \(result.protectedSegmentCount) protected segment(s) to \(outputPath)")
    }

    static func printUsage() {
        fputs(
            """
            deprotect 4.0.2 (Swift)
            Usage: deprotect [options] <input file> <output file>

              where options are:
                    -a, --arch <arch>  choose a specific architecture from a universal binary
                                       (ppc, ppc64, i386, x86_64, armv6, armv7, armv7s, arm64)
                    -h, --help         show this help message
                    --version          show version

            """, stderr)
    }

    struct DeprotectResult {
        var protectedSegmentCount: Int
    }

    static func deprotect(machOFile: MachOFile, outputPath: String) throws -> DeprotectResult {
        var mutableData = machOFile.data
        var protectedSegmentCount = 0

        // Find all segment load commands and check for protection
        var commandOffset = Int(machOFile.header.headerSize)

        for loadCommand in machOFile.loadCommands {
            if case .segment(let segment) = loadCommand {
                if segment.isProtected {
                    protectedSegmentCount += 1

                    // Get segment data
                    let segmentRange = Int(segment.fileoff)..<Int(segment.fileoff + segment.filesize)
                    guard segmentRange.upperBound <= mutableData.count else {
                        throw DeprotectError.invalidSegmentRange
                    }

                    let segmentData = mutableData.subdata(in: segmentRange)

                    // Decrypt the segment
                    let decryptedData = try SegmentDecryptor.decrypt(data: segmentData)

                    // Replace encrypted data with decrypted data
                    mutableData.replaceSubrange(segmentRange, with: decryptedData)

                    // Clear the SG_PROTECTED_VERSION_1 flag
                    // The flags field is at different offsets for 32-bit vs 64-bit
                    let flagsOffset: Int
                    if segment.is64Bit {
                        // segment_command_64: cmd(4) + cmdsize(4) + segname(16) + vmaddr(8) + vmsize(8) + fileoff(8) + filesize(8) + maxprot(4) + initprot(4) + nsects(4) = 64 bytes to flags
                        flagsOffset = commandOffset + 4 + 4 + 16 + 8 + 8 + 8 + 8 + 4 + 4 + 4
                    } else {
                        // segment_command: cmd(4) + cmdsize(4) + segname(16) + vmaddr(4) + vmsize(4) + fileoff(4) + filesize(4) + maxprot(4) + initprot(4) + nsects(4) = 52 bytes to flags
                        flagsOffset = commandOffset + 4 + 4 + 16 + 4 + 4 + 4 + 4 + 4 + 4 + 4
                    }

                    // Read current flags and clear the protection bit
                    let currentFlags = mutableData.withUnsafeBytes { buffer -> UInt32 in
                        if machOFile.byteOrder == .little {
                            return buffer.load(fromByteOffset: flagsOffset, as: UInt32.self)
                        } else {
                            return UInt32(bigEndian: buffer.load(fromByteOffset: flagsOffset, as: UInt32.self))
                        }
                    }

                    let newFlags = currentFlags & ~UInt32(SG_PROTECTED_VERSION_1)

                    mutableData.withUnsafeMutableBytes { buffer in
                        if machOFile.byteOrder == .little {
                            buffer.storeBytes(of: newFlags, toByteOffset: flagsOffset, as: UInt32.self)
                        } else {
                            buffer.storeBytes(of: newFlags.bigEndian, toByteOffset: flagsOffset, as: UInt32.self)
                        }
                    }
                }
            }

            // Move to next load command
            commandOffset += Int(loadCommand.cmdsize)
        }

        // Write the output file
        if protectedSegmentCount > 0 {
            let outputURL = URL(fileURLWithPath: outputPath)
            try mutableData.write(to: outputURL)
        }

        return DeprotectResult(protectedSegmentCount: protectedSegmentCount)
    }
}

enum DeprotectError: Error, CustomStringConvertible {
    case invalidSegmentRange
    case decryptionFailed(String)

    var description: String {
        switch self {
        case .invalidSegmentRange:
            return "Invalid segment range in file"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        }
    }
}
