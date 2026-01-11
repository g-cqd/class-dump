// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// ObjC 2.0 image info structure.
public struct ObjC2ImageInfo: Sendable {
    /// Image info version.
    public let version: UInt32

    /// Image info flags.
    public let flags: UInt32

    /// Image info flags.
    public struct Flags: OptionSet, Sendable {
        /// The raw integer value of the flags.
        public let rawValue: UInt32

        /// Create flags from a raw value.
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Is a replacement class.
        public static let isReplacement = Flags(rawValue: 1 << 0)
        /// Supports garbage collection.
        public static let supportsGC = Flags(rawValue: 1 << 1)
        /// Requires garbage collection.
        public static let requiresGC = Flags(rawValue: 1 << 2)
        /// Optimized by dyld.
        public static let optimizedByDyld = Flags(rawValue: 1 << 3)
        /// Has signed class read-only data.
        public static let signedClassRO = Flags(rawValue: 1 << 4)
        /// Is simulated (iOS Simulator).
        public static let isSimulated = Flags(rawValue: 1 << 5)
        /// Has category class properties.
        public static let hasCategoryClassProperties = Flags(rawValue: 1 << 6)
        /// Optimized by dyld closure.
        public static let optimizedByDyldClosure = Flags(rawValue: 1 << 7)
    }

    /// Parsed image info flags.
    public var parsedFlags: Flags {
        Flags(rawValue: flags)
    }

    /// The Swift version used to build this binary.
    public var swiftVersion: UInt32 {
        (flags >> 8) & 0xFF
    }

    /// Parse an image info structure.
    public init(cursor: inout DataCursor, byteOrder: ByteOrder) throws {
        if byteOrder == .little {
            self.version = try cursor.readLittleInt32()
            self.flags = try cursor.readLittleInt32()
        }
        else {
            self.version = try cursor.readBigInt32()
            self.flags = try cursor.readBigInt32()
        }
    }
}
