// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// ObjC 2.0 class_ro_t structure (read-only class data).
public struct ObjC2ClassROData: Sendable {
    /// Class flags.
    public let flags: UInt32

    /// Instance start offset.
    public let instanceStart: UInt32

    /// Instance size.
    public let instanceSize: UInt32

    /// Reserved field (64-bit only).
    public let reserved: UInt32

    /// Pointer to ivar layout.
    public let ivarLayout: UInt64

    /// Pointer to class name.
    public let name: UInt64

    /// Pointer to method list.
    public let baseMethods: UInt64

    /// Pointer to protocol list.
    public let baseProtocols: UInt64

    /// Pointer to ivar list.
    public let ivars: UInt64

    /// Pointer to weak ivar layout.
    public let weakIvarLayout: UInt64

    /// Pointer to property list.
    public let baseProperties: UInt64

    /// Class flags.
    public struct Flags: OptionSet, Sendable {
        /// The raw integer value of the flags.
        public let rawValue: UInt32

        /// Create flags from a raw value.
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Is a metaclass.
        public static let meta = Flags(rawValue: 1 << 0)
        /// Is a root class.
        public static let root = Flags(rawValue: 1 << 1)
        /// Has C++ constructors/destructors.
        public static let hasCxxStructors = Flags(rawValue: 1 << 2)
        /// Is hidden.
        public static let hidden = Flags(rawValue: 1 << 4)
        /// Exception handling.
        public static let exception = Flags(rawValue: 1 << 5)
        /// Has Swift initializer.
        public static let hasSwiftInitializer = Flags(rawValue: 1 << 6)
        /// Is ARC.
        public static let isARC = Flags(rawValue: 1 << 7)
        /// Has C++ destructor only.
        public static let hasCxxDestructorOnly = Flags(rawValue: 1 << 8)
        /// Has weak ivars without ARC.
        public static let hasWeakWithoutARC = Flags(rawValue: 1 << 9)
    }

    /// Parsed class flags.
    public var parsedFlags: Flags {
        Flags(rawValue: flags)
    }

    /// Parse a class read-only data structure.
    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if byteOrder == .little {
            self.flags = try cursor.readLittleInt32()
            self.instanceStart = try cursor.readLittleInt32()
            self.instanceSize = try cursor.readLittleInt32()
            self.reserved = is64Bit ? try cursor.readLittleInt32() : 0
            self.ivarLayout = is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
            self.name = is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
            self.baseMethods = is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
            self.baseProtocols = is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
            self.ivars = is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
            self.weakIvarLayout =
                is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
            self.baseProperties =
                is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
        }
        else {
            self.flags = try cursor.readBigInt32()
            self.instanceStart = try cursor.readBigInt32()
            self.instanceSize = try cursor.readBigInt32()
            self.reserved = is64Bit ? try cursor.readBigInt32() : 0
            self.ivarLayout = is64Bit ? try cursor.readBigInt64() : UInt64(try cursor.readBigInt32())
            self.name = is64Bit ? try cursor.readBigInt64() : UInt64(try cursor.readBigInt32())
            self.baseMethods = is64Bit ? try cursor.readBigInt64() : UInt64(try cursor.readBigInt32())
            self.baseProtocols = is64Bit ? try cursor.readBigInt64() : UInt64(try cursor.readBigInt32())
            self.ivars = is64Bit ? try cursor.readBigInt64() : UInt64(try cursor.readBigInt32())
            self.weakIvarLayout = is64Bit ? try cursor.readBigInt64() : UInt64(try cursor.readBigInt32())
            self.baseProperties = is64Bit ? try cursor.readBigInt64() : UInt64(try cursor.readBigInt32())
        }
    }
}
