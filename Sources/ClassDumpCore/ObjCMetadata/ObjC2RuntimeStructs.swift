import Foundation

// MARK: - ObjC 2.0 Runtime Structures

/// Common list header for ObjC 2.0 data structures.
public struct ObjC2ListHeader: Sendable {
    public let entsize: UInt32
    public let count: UInt32

    /// The actual entry size (with flags masked out from low bits).
    /// The low 2 bits contain flags, so we mask with ~3.
    public var actualEntsize: UInt32 {
        entsize & ~3
    }

    /// Whether this list uses small methods (bit 31 set).
    /// Small methods use 12-byte relative entries instead of 24-byte absolute pointers.
    public var usesSmallMethods: Bool {
        (entsize & 0x8000_0000) != 0
    }

    public init(entsize: UInt32, count: UInt32) {
        self.entsize = entsize
        self.count = count
    }

    public init(cursor: inout DataCursor, byteOrder: ByteOrder) throws {
        if byteOrder == .little {
            self.entsize = try cursor.readLittleInt32()
            self.count = try cursor.readLittleInt32()
        } else {
            self.entsize = try cursor.readBigInt32()
            self.count = try cursor.readBigInt32()
        }
    }
}

/// ObjC 2.0 small method structure (relative offsets).
/// Used in iOS 14+ / macOS 11+ binaries.
public struct ObjC2SmallMethod: Sendable {
    public let nameOffset: Int32  // Relative offset to selector reference
    public let typesOffset: Int32  // Relative offset to type encoding
    public let impOffset: Int32  // Relative offset to implementation

    public init(cursor: inout DataCursor, byteOrder: ByteOrder) throws {
        if byteOrder == .little {
            self.nameOffset = Int32(bitPattern: try cursor.readLittleInt32())
            self.typesOffset = Int32(bitPattern: try cursor.readLittleInt32())
            self.impOffset = Int32(bitPattern: try cursor.readLittleInt32())
        } else {
            self.nameOffset = Int32(bitPattern: try cursor.readBigInt32())
            self.typesOffset = Int32(bitPattern: try cursor.readBigInt32())
            self.impOffset = Int32(bitPattern: try cursor.readBigInt32())
        }
    }
}

/// ObjC 2.0 image info structure.
public struct ObjC2ImageInfo: Sendable {
    public let version: UInt32
    public let flags: UInt32

    /// Image info flags
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let isReplacement = Flags(rawValue: 1 << 0)
        public static let supportsGC = Flags(rawValue: 1 << 1)
        public static let requiresGC = Flags(rawValue: 1 << 2)
        public static let optimizedByDyld = Flags(rawValue: 1 << 3)
        public static let signedClassRO = Flags(rawValue: 1 << 4)
        public static let isSimulated = Flags(rawValue: 1 << 5)
        public static let hasCategoryClassProperties = Flags(rawValue: 1 << 6)
        public static let optimizedByDyldClosure = Flags(rawValue: 1 << 7)
    }

    public var parsedFlags: Flags {
        Flags(rawValue: flags)
    }

    public var swiftVersion: UInt32 {
        (flags >> 8) & 0xFF
    }

    public init(cursor: inout DataCursor, byteOrder: ByteOrder) throws {
        if byteOrder == .little {
            self.version = try cursor.readLittleInt32()
            self.flags = try cursor.readLittleInt32()
        } else {
            self.version = try cursor.readBigInt32()
            self.flags = try cursor.readBigInt32()
        }
    }
}

/// ObjC 2.0 class structure.
public struct ObjC2Class: Sendable {
    public let isa: UInt64
    public let superclass: UInt64
    public let cache: UInt64
    public let vtable: UInt64
    public let data: UInt64  // Points to class_ro_t (low bits may have flags)
    public let reserved1: UInt64
    public let reserved2: UInt64
    public let reserved3: UInt64

    /// The actual data pointer (with flags stripped).
    public var dataPointer: UInt64 {
        data & ~7
    }

    /// Whether this is a Swift class (bit 0 of data).
    public var isSwiftClass: Bool {
        (data & 1) != 0
    }

    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.isa = try cursor.readLittleInt64()
                self.superclass = try cursor.readLittleInt64()
                self.cache = try cursor.readLittleInt64()
                self.vtable = try cursor.readLittleInt64()
                self.data = try cursor.readLittleInt64()
                self.reserved1 = try cursor.readLittleInt64()
                self.reserved2 = try cursor.readLittleInt64()
                self.reserved3 = try cursor.readLittleInt64()
            } else {
                self.isa = try cursor.readBigInt64()
                self.superclass = try cursor.readBigInt64()
                self.cache = try cursor.readBigInt64()
                self.vtable = try cursor.readBigInt64()
                self.data = try cursor.readBigInt64()
                self.reserved1 = try cursor.readBigInt64()
                self.reserved2 = try cursor.readBigInt64()
                self.reserved3 = try cursor.readBigInt64()
            }
        } else {
            if byteOrder == .little {
                self.isa = UInt64(try cursor.readLittleInt32())
                self.superclass = UInt64(try cursor.readLittleInt32())
                self.cache = UInt64(try cursor.readLittleInt32())
                self.vtable = UInt64(try cursor.readLittleInt32())
                self.data = UInt64(try cursor.readLittleInt32())
                self.reserved1 = UInt64(try cursor.readLittleInt32())
                self.reserved2 = UInt64(try cursor.readLittleInt32())
                self.reserved3 = UInt64(try cursor.readLittleInt32())
            } else {
                self.isa = UInt64(try cursor.readBigInt32())
                self.superclass = UInt64(try cursor.readBigInt32())
                self.cache = UInt64(try cursor.readBigInt32())
                self.vtable = UInt64(try cursor.readBigInt32())
                self.data = UInt64(try cursor.readBigInt32())
                self.reserved1 = UInt64(try cursor.readBigInt32())
                self.reserved2 = UInt64(try cursor.readBigInt32())
                self.reserved3 = UInt64(try cursor.readBigInt32())
            }
        }
    }
}

/// ObjC 2.0 class_ro_t structure (read-only class data).
public struct ObjC2ClassROData: Sendable {
    public let flags: UInt32
    public let instanceStart: UInt32
    public let instanceSize: UInt32
    public let reserved: UInt32  // Only in 64-bit
    public let ivarLayout: UInt64
    public let name: UInt64
    public let baseMethods: UInt64
    public let baseProtocols: UInt64
    public let ivars: UInt64
    public let weakIvarLayout: UInt64
    public let baseProperties: UInt64

    /// Class flags
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let meta = Flags(rawValue: 1 << 0)
        public static let root = Flags(rawValue: 1 << 1)
        public static let hasCxxStructors = Flags(rawValue: 1 << 2)
        public static let hidden = Flags(rawValue: 1 << 4)
        public static let exception = Flags(rawValue: 1 << 5)
        public static let hasSwiftInitializer = Flags(rawValue: 1 << 6)
        public static let isARC = Flags(rawValue: 1 << 7)
        public static let hasCxxDestructorOnly = Flags(rawValue: 1 << 8)
        public static let hasWeakWithoutARC = Flags(rawValue: 1 << 9)
    }

    public var parsedFlags: Flags {
        Flags(rawValue: flags)
    }

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
            self.weakIvarLayout = is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
            self.baseProperties = is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
        } else {
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

/// ObjC 2.0 method structure.
public struct ObjC2Method: Sendable {
    public let name: UInt64  // Pointer to selector name
    public let types: UInt64  // Pointer to type encoding
    public let imp: UInt64  // Implementation address

    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.name = try cursor.readLittleInt64()
                self.types = try cursor.readLittleInt64()
                self.imp = try cursor.readLittleInt64()
            } else {
                self.name = try cursor.readBigInt64()
                self.types = try cursor.readBigInt64()
                self.imp = try cursor.readBigInt64()
            }
        } else {
            if byteOrder == .little {
                self.name = UInt64(try cursor.readLittleInt32())
                self.types = UInt64(try cursor.readLittleInt32())
                self.imp = UInt64(try cursor.readLittleInt32())
            } else {
                self.name = UInt64(try cursor.readBigInt32())
                self.types = UInt64(try cursor.readBigInt32())
                self.imp = UInt64(try cursor.readBigInt32())
            }
        }
    }
}

/// ObjC 2.0 instance variable structure.
public struct ObjC2Ivar: Sendable {
    public let offset: UInt64  // Pointer to offset value
    public let name: UInt64  // Pointer to name string
    public let type: UInt64  // Pointer to type string
    public let alignment: UInt32
    public let size: UInt32

    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.offset = try cursor.readLittleInt64()
                self.name = try cursor.readLittleInt64()
                self.type = try cursor.readLittleInt64()
                self.alignment = try cursor.readLittleInt32()
                self.size = try cursor.readLittleInt32()
            } else {
                self.offset = try cursor.readBigInt64()
                self.name = try cursor.readBigInt64()
                self.type = try cursor.readBigInt64()
                self.alignment = try cursor.readBigInt32()
                self.size = try cursor.readBigInt32()
            }
        } else {
            if byteOrder == .little {
                self.offset = UInt64(try cursor.readLittleInt32())
                self.name = UInt64(try cursor.readLittleInt32())
                self.type = UInt64(try cursor.readLittleInt32())
                self.alignment = try cursor.readLittleInt32()
                self.size = try cursor.readLittleInt32()
            } else {
                self.offset = UInt64(try cursor.readBigInt32())
                self.name = UInt64(try cursor.readBigInt32())
                self.type = UInt64(try cursor.readBigInt32())
                self.alignment = try cursor.readBigInt32()
                self.size = try cursor.readBigInt32()
            }
        }
    }
}

/// ObjC 2.0 property structure.
public struct ObjC2Property: Sendable {
    public let name: UInt64  // Pointer to name string
    public let attributes: UInt64  // Pointer to attributes string

    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.name = try cursor.readLittleInt64()
                self.attributes = try cursor.readLittleInt64()
            } else {
                self.name = try cursor.readBigInt64()
                self.attributes = try cursor.readBigInt64()
            }
        } else {
            if byteOrder == .little {
                self.name = UInt64(try cursor.readLittleInt32())
                self.attributes = UInt64(try cursor.readLittleInt32())
            } else {
                self.name = UInt64(try cursor.readBigInt32())
                self.attributes = UInt64(try cursor.readBigInt32())
            }
        }
    }
}

/// ObjC 2.0 protocol structure.
public struct ObjC2Protocol: Sendable {
    public let isa: UInt64
    public let name: UInt64
    public let protocols: UInt64
    public let instanceMethods: UInt64
    public let classMethods: UInt64
    public let optionalInstanceMethods: UInt64
    public let optionalClassMethods: UInt64
    public let instanceProperties: UInt64
    public let size: UInt32
    public let flags: UInt32
    public let extendedMethodTypes: UInt64

    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool, ptrSize: Int) throws {
        if is64Bit {
            if byteOrder == .little {
                self.isa = try cursor.readLittleInt64()
                self.name = try cursor.readLittleInt64()
                self.protocols = try cursor.readLittleInt64()
                self.instanceMethods = try cursor.readLittleInt64()
                self.classMethods = try cursor.readLittleInt64()
                self.optionalInstanceMethods = try cursor.readLittleInt64()
                self.optionalClassMethods = try cursor.readLittleInt64()
                self.instanceProperties = try cursor.readLittleInt64()
                self.size = try cursor.readLittleInt32()
                self.flags = try cursor.readLittleInt32()

                // Check if there's an extended method types field
                let hasExtendedMethodTypes = size > UInt32(8 * ptrSize + 2 * 4)
                self.extendedMethodTypes = hasExtendedMethodTypes ? try cursor.readLittleInt64() : 0
            } else {
                self.isa = try cursor.readBigInt64()
                self.name = try cursor.readBigInt64()
                self.protocols = try cursor.readBigInt64()
                self.instanceMethods = try cursor.readBigInt64()
                self.classMethods = try cursor.readBigInt64()
                self.optionalInstanceMethods = try cursor.readBigInt64()
                self.optionalClassMethods = try cursor.readBigInt64()
                self.instanceProperties = try cursor.readBigInt64()
                self.size = try cursor.readBigInt32()
                self.flags = try cursor.readBigInt32()

                let hasExtendedMethodTypes = size > UInt32(8 * ptrSize + 2 * 4)
                self.extendedMethodTypes = hasExtendedMethodTypes ? try cursor.readBigInt64() : 0
            }
        } else {
            if byteOrder == .little {
                self.isa = UInt64(try cursor.readLittleInt32())
                self.name = UInt64(try cursor.readLittleInt32())
                self.protocols = UInt64(try cursor.readLittleInt32())
                self.instanceMethods = UInt64(try cursor.readLittleInt32())
                self.classMethods = UInt64(try cursor.readLittleInt32())
                self.optionalInstanceMethods = UInt64(try cursor.readLittleInt32())
                self.optionalClassMethods = UInt64(try cursor.readLittleInt32())
                self.instanceProperties = UInt64(try cursor.readLittleInt32())
                self.size = try cursor.readLittleInt32()
                self.flags = try cursor.readLittleInt32()

                let hasExtendedMethodTypes = size > UInt32(8 * ptrSize + 2 * 4)
                self.extendedMethodTypes = hasExtendedMethodTypes ? UInt64(try cursor.readLittleInt32()) : 0
            } else {
                self.isa = UInt64(try cursor.readBigInt32())
                self.name = UInt64(try cursor.readBigInt32())
                self.protocols = UInt64(try cursor.readBigInt32())
                self.instanceMethods = UInt64(try cursor.readBigInt32())
                self.classMethods = UInt64(try cursor.readBigInt32())
                self.optionalInstanceMethods = UInt64(try cursor.readBigInt32())
                self.optionalClassMethods = UInt64(try cursor.readBigInt32())
                self.instanceProperties = UInt64(try cursor.readBigInt32())
                self.size = try cursor.readBigInt32()
                self.flags = try cursor.readBigInt32()

                let hasExtendedMethodTypes = size > UInt32(8 * ptrSize + 2 * 4)
                self.extendedMethodTypes = hasExtendedMethodTypes ? UInt64(try cursor.readBigInt32()) : 0
            }
        }
    }
}

/// ObjC 2.0 category structure.
public struct ObjC2Category: Sendable {
    public let name: UInt64
    public let cls: UInt64  // Note: 'class' is a Swift keyword
    public let instanceMethods: UInt64
    public let classMethods: UInt64
    public let protocols: UInt64
    public let instanceProperties: UInt64
    public let v7: UInt64
    public let v8: UInt64

    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.name = try cursor.readLittleInt64()
                self.cls = try cursor.readLittleInt64()
                self.instanceMethods = try cursor.readLittleInt64()
                self.classMethods = try cursor.readLittleInt64()
                self.protocols = try cursor.readLittleInt64()
                self.instanceProperties = try cursor.readLittleInt64()
                self.v7 = try cursor.readLittleInt64()
                self.v8 = try cursor.readLittleInt64()
            } else {
                self.name = try cursor.readBigInt64()
                self.cls = try cursor.readBigInt64()
                self.instanceMethods = try cursor.readBigInt64()
                self.classMethods = try cursor.readBigInt64()
                self.protocols = try cursor.readBigInt64()
                self.instanceProperties = try cursor.readBigInt64()
                self.v7 = try cursor.readBigInt64()
                self.v8 = try cursor.readBigInt64()
            }
        } else {
            if byteOrder == .little {
                self.name = UInt64(try cursor.readLittleInt32())
                self.cls = UInt64(try cursor.readLittleInt32())
                self.instanceMethods = UInt64(try cursor.readLittleInt32())
                self.classMethods = UInt64(try cursor.readLittleInt32())
                self.protocols = UInt64(try cursor.readLittleInt32())
                self.instanceProperties = UInt64(try cursor.readLittleInt32())
                self.v7 = UInt64(try cursor.readLittleInt32())
                self.v8 = UInt64(try cursor.readLittleInt32())
            } else {
                self.name = UInt64(try cursor.readBigInt32())
                self.cls = UInt64(try cursor.readBigInt32())
                self.instanceMethods = UInt64(try cursor.readBigInt32())
                self.classMethods = UInt64(try cursor.readBigInt32())
                self.protocols = UInt64(try cursor.readBigInt32())
                self.instanceProperties = UInt64(try cursor.readBigInt32())
                self.v7 = UInt64(try cursor.readBigInt32())
                self.v8 = UInt64(try cursor.readBigInt32())
            }
        }
    }
}
