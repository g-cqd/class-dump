// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("SegmentCommand Tests", .serialized)
struct TestSegmentCommand {
    @Test("Parse 64-bit segment command")
    func testParse64BitSegment() throws {
        // Create a minimal LC_SEGMENT_64 command
        var data = Data()

        // cmd (LC_SEGMENT_64 = 0x19)
        var cmd: UInt32 = UInt32(LC_SEGMENT_64)
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        // cmdsize (72 bytes for 64-bit segment header with no sections)
        var cmdsize: UInt32 = 72
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        // segname (16 bytes, "__TEXT")
        var segname = "__TEXT".padding(toLength: 16, withPad: "\0", startingAt: 0)
        data.append(segname.data(using: .ascii)!)

        // vmaddr (64-bit)
        var vmaddr: UInt64 = 0x1_0000_0000
        data.append(contentsOf: withUnsafeBytes(of: &vmaddr) { Array($0) })

        // vmsize (64-bit)
        var vmsize: UInt64 = 0x10000
        data.append(contentsOf: withUnsafeBytes(of: &vmsize) { Array($0) })

        // fileoff (64-bit)
        var fileoff: UInt64 = 0
        data.append(contentsOf: withUnsafeBytes(of: &fileoff) { Array($0) })

        // filesize (64-bit)
        var filesize: UInt64 = 0x10000
        data.append(contentsOf: withUnsafeBytes(of: &filesize) { Array($0) })

        // maxprot
        var maxprot: Int32 = 7  // rwx
        data.append(contentsOf: withUnsafeBytes(of: &maxprot) { Array($0) })

        // initprot
        var initprot: Int32 = 5  // rx
        data.append(contentsOf: withUnsafeBytes(of: &initprot) { Array($0) })

        // nsects
        var nsects: UInt32 = 0
        data.append(contentsOf: withUnsafeBytes(of: &nsects) { Array($0) })

        // flags
        var flags: UInt32 = 0
        data.append(contentsOf: withUnsafeBytes(of: &flags) { Array($0) })

        let segment = try SegmentCommand(data: data, byteOrder: .little, is64Bit: true)

        #expect(segment.cmd == UInt32(LC_SEGMENT_64))
        #expect(segment.cmdsize == 72)
        #expect(segment.name == "__TEXT")
        #expect(segment.vmaddr == 0x1_0000_0000)
        #expect(segment.vmsize == 0x10000)
        #expect(segment.fileoff == 0)
        #expect(segment.filesize == 0x10000)
        #expect(segment.initprot == 5)
        #expect(segment.nsects == 0)
        #expect(segment.sections.isEmpty)
        #expect(segment.is64Bit == true)
    }

    @Test("Parse 32-bit segment command")
    func testParse32BitSegment() throws {
        var data = Data()

        // cmd (LC_SEGMENT = 0x1)
        var cmd: UInt32 = UInt32(LC_SEGMENT)
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        // cmdsize (56 bytes for 32-bit segment header with no sections)
        var cmdsize: UInt32 = 56
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        // segname (16 bytes, "__DATA")
        var segname = "__DATA".padding(toLength: 16, withPad: "\0", startingAt: 0)
        data.append(segname.data(using: .ascii)!)

        // vmaddr (32-bit)
        var vmaddr: UInt32 = 0x1000
        data.append(contentsOf: withUnsafeBytes(of: &vmaddr) { Array($0) })

        // vmsize (32-bit)
        var vmsize: UInt32 = 0x1000
        data.append(contentsOf: withUnsafeBytes(of: &vmsize) { Array($0) })

        // fileoff (32-bit)
        var fileoff: UInt32 = 0x1000
        data.append(contentsOf: withUnsafeBytes(of: &fileoff) { Array($0) })

        // filesize (32-bit)
        var filesize: UInt32 = 0x1000
        data.append(contentsOf: withUnsafeBytes(of: &filesize) { Array($0) })

        // maxprot
        var maxprot: Int32 = 7
        data.append(contentsOf: withUnsafeBytes(of: &maxprot) { Array($0) })

        // initprot
        var initprot: Int32 = 3  // rw
        data.append(contentsOf: withUnsafeBytes(of: &initprot) { Array($0) })

        // nsects
        var nsects: UInt32 = 0
        data.append(contentsOf: withUnsafeBytes(of: &nsects) { Array($0) })

        // flags
        var flags: UInt32 = 0
        data.append(contentsOf: withUnsafeBytes(of: &flags) { Array($0) })

        let segment = try SegmentCommand(data: data, byteOrder: .little, is64Bit: false)

        #expect(segment.cmd == UInt32(LC_SEGMENT))
        #expect(segment.name == "__DATA")
        #expect(segment.vmaddr == 0x1000)
        #expect(segment.is64Bit == false)
    }

    @Test("Segment contains address")
    func testSegmentContainsAddress() throws {
        var data = Data()

        var cmd: UInt32 = UInt32(LC_SEGMENT_64)
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        var cmdsize: UInt32 = 72
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        var segname = "__TEXT".padding(toLength: 16, withPad: "\0", startingAt: 0)
        data.append(segname.data(using: .ascii)!)

        var vmaddr: UInt64 = 0x1000
        data.append(contentsOf: withUnsafeBytes(of: &vmaddr) { Array($0) })

        var vmsize: UInt64 = 0x1000
        data.append(contentsOf: withUnsafeBytes(of: &vmsize) { Array($0) })

        // Fill remaining fields
        var zero64: UInt64 = 0
        data.append(contentsOf: withUnsafeBytes(of: &zero64) { Array($0) })  // fileoff
        data.append(contentsOf: withUnsafeBytes(of: &zero64) { Array($0) })  // filesize

        var zero32: UInt32 = 0
        data.append(contentsOf: withUnsafeBytes(of: &zero32) { Array($0) })  // maxprot
        data.append(contentsOf: withUnsafeBytes(of: &zero32) { Array($0) })  // initprot
        data.append(contentsOf: withUnsafeBytes(of: &zero32) { Array($0) })  // nsects
        data.append(contentsOf: withUnsafeBytes(of: &zero32) { Array($0) })  // flags

        let segment = try SegmentCommand(data: data, byteOrder: .little, is64Bit: true)

        #expect(segment.contains(address: 0x1000) == true)
        #expect(segment.contains(address: 0x1500) == true)
        #expect(segment.contains(address: 0x1FFF) == true)
        #expect(segment.contains(address: 0x2000) == false)
        #expect(segment.contains(address: 0x0FFF) == false)
    }

    @Test("Segment flags description")
    func testSegmentFlagsDescription() {
        let noFlags = SegmentFlags(rawValue: 0)
        #expect(noFlags.description == "none")

        let protected = SegmentFlags.protectedVersion1
        #expect(protected.description.contains("PROTECTED"))

        let multiple = SegmentFlags([.highVM, .noReloc])
        #expect(multiple.description.contains("HIGHVM"))
        #expect(multiple.description.contains("NORELOC"))
    }
}
