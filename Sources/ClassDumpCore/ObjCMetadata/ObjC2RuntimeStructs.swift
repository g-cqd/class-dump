import Foundation

// MARK: - ObjC 2.0 Runtime Structures

/// Common list header for ObjC 2.0 data structures.
public struct ObjC2ListHeader: Sendable {
    /// The size of each entry in the list.
    public let entsize: UInt32

    /// The number of entries in the list.
    public let count: UInt32

    /// Flags in the high bits of entsize.
    private static let smallMethodsFlag: UInt32 = 0x8000_0000  // Bit 31
    private static let directSelectorsFlag: UInt32 = 0x4000_0000  // Bit 30 (iOS 16+)
    private static let flagsMask: UInt32 = 0xFFFF_0000  // High 16 bits are flags

    /// The actual entry size (with flags masked out).
    ///
    /// The high bits contain flags and the low bits contain the entry size.
    public var actualEntsize: UInt32 {
        entsize & ~Self.flagsMask & ~3
    }

    /// Whether this list uses small methods (bit 31 set).
    ///
    /// Small methods use 12-byte relative entries instead of 24-byte absolute pointers.
    public var usesSmallMethods: Bool {
        (entsize & Self.smallMethodsFlag) != 0
    }

    /// Whether this list uses direct selectors (bit 30 set, iOS 16+).
    ///
    /// With direct selectors, the nameOffset points directly to the selector string,
    /// not to a selector reference that then points to the string.
    public var usesDirectSelectors: Bool {
        (entsize & Self.directSelectorsFlag) != 0
    }

    /// Initialize a list header manually.
    public init(entsize: UInt32, count: UInt32) {
        self.entsize = entsize
        self.count = count
    }

    /// Parse a list header from data.
    public init(cursor: inout DataCursor, byteOrder: ByteOrder) throws {
        if byteOrder == .little {
            self.entsize = try cursor.readLittleInt32()
            self.count = try cursor.readLittleInt32()
        }
        else {
            self.entsize = try cursor.readBigInt32()
            self.count = try cursor.readBigInt32()
        }
    }
}

/// ObjC 2.0 small method structure (relative offsets).
///
/// Used in iOS 14+ / macOS 11+ binaries.
public struct ObjC2SmallMethod: Sendable {
    /// Relative offset to selector reference.
    public let nameOffset: Int32

    /// Relative offset to type encoding.
    public let typesOffset: Int32

    /// Relative offset to implementation.
    public let impOffset: Int32

    /// Parse a small method structure.
    public init(cursor: inout DataCursor, byteOrder: ByteOrder) throws {
        if byteOrder == .little {
            self.nameOffset = Int32(bitPattern: try cursor.readLittleInt32())
            self.typesOffset = Int32(bitPattern: try cursor.readLittleInt32())
            self.impOffset = Int32(bitPattern: try cursor.readLittleInt32())
        }
        else {
            self.nameOffset = Int32(bitPattern: try cursor.readBigInt32())
            self.typesOffset = Int32(bitPattern: try cursor.readBigInt32())
            self.impOffset = Int32(bitPattern: try cursor.readBigInt32())
        }
    }
}

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

/// ObjC 2.0 class structure.
public struct ObjC2Class: Sendable {
    /// Pointer to metaclass.
    public let isa: UInt64

    /// Pointer to superclass.
    public let superclass: UInt64

    /// Pointer to method cache.
    public let cache: UInt64

    /// Pointer to virtual function table.
    public let vtable: UInt64

    /// Pointer to class_ro_t (low bits may have flags).
    public let data: UInt64

    /// Reserved field 1.
    public let reserved1: UInt64

    /// Reserved field 2.
    public let reserved2: UInt64

    /// Reserved field 3.
    public let reserved3: UInt64

    /// The actual data pointer (with flags stripped).
    public var dataPointer: UInt64 {
        data & ~7
    }

    /// Whether this is a Swift class (bit 0 of data).
    public var isSwiftClass: Bool {
        (data & 1) != 0
    }

    /// Parse an ObjC class structure.
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
            }
            else {
                self.isa = try cursor.readBigInt64()
                self.superclass = try cursor.readBigInt64()
                self.cache = try cursor.readBigInt64()
                self.vtable = try cursor.readBigInt64()
                self.data = try cursor.readBigInt64()
                self.reserved1 = try cursor.readBigInt64()
                self.reserved2 = try cursor.readBigInt64()
                self.reserved3 = try cursor.readBigInt64()
            }
        }
        else {
            if byteOrder == .little {
                self.isa = UInt64(try cursor.readLittleInt32())
                self.superclass = UInt64(try cursor.readLittleInt32())
                self.cache = UInt64(try cursor.readLittleInt32())
                self.vtable = UInt64(try cursor.readLittleInt32())
                self.data = UInt64(try cursor.readLittleInt32())
                self.reserved1 = UInt64(try cursor.readLittleInt32())
                self.reserved2 = UInt64(try cursor.readLittleInt32())
                self.reserved3 = UInt64(try cursor.readLittleInt32())
            }
            else {
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
            self.weakIvarLayout = is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
            self.baseProperties = is64Bit ? try cursor.readLittleInt64() : UInt64(try cursor.readLittleInt32())
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

/// ObjC 2.0 method structure.
public struct ObjC2Method: Sendable {
    /// Pointer to selector name.
    public let name: UInt64

    /// Pointer to type encoding.
    public let types: UInt64

    /// Implementation address.
    public let imp: UInt64

    /// Parse a method structure.
    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.name = try cursor.readLittleInt64()
                self.types = try cursor.readLittleInt64()
                self.imp = try cursor.readLittleInt64()
            }
            else {
                self.name = try cursor.readBigInt64()
                self.types = try cursor.readBigInt64()
                self.imp = try cursor.readBigInt64()
            }
        }
        else {
            if byteOrder == .little {
                self.name = UInt64(try cursor.readLittleInt32())
                self.types = UInt64(try cursor.readLittleInt32())
                self.imp = UInt64(try cursor.readLittleInt32())
            }
            else {
                self.name = UInt64(try cursor.readBigInt32())
                self.types = UInt64(try cursor.readBigInt32())
                self.imp = UInt64(try cursor.readBigInt32())
            }
        }
    }
}

/// ObjC 2.0 instance variable structure.
public struct ObjC2Ivar: Sendable {
    /// Pointer to offset value.
    public let offset: UInt64

    /// Pointer to name string.
    public let name: UInt64

    /// Pointer to type string.
    public let type: UInt64

    /// Ivar alignment.
    public let alignment: UInt32

    /// Ivar size.
    public let size: UInt32

    /// Parse an instance variable structure.
    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.offset = try cursor.readLittleInt64()
                self.name = try cursor.readLittleInt64()
                self.type = try cursor.readLittleInt64()
                self.alignment = try cursor.readLittleInt32()
                self.size = try cursor.readLittleInt32()
            }
            else {
                self.offset = try cursor.readBigInt64()
                self.name = try cursor.readBigInt64()
                self.type = try cursor.readBigInt64()
                self.alignment = try cursor.readBigInt32()
                self.size = try cursor.readBigInt32()
            }
        }
        else {
            if byteOrder == .little {
                self.offset = UInt64(try cursor.readLittleInt32())
                self.name = UInt64(try cursor.readLittleInt32())
                self.type = UInt64(try cursor.readLittleInt32())
                self.alignment = try cursor.readLittleInt32()
                self.size = try cursor.readLittleInt32()
            }
            else {
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
    /// Pointer to name string.
    public let name: UInt64

    /// Pointer to attributes string.
    public let attributes: UInt64

    /// Parse a property structure.
    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.name = try cursor.readLittleInt64()
                self.attributes = try cursor.readLittleInt64()
            }
            else {
                self.name = try cursor.readBigInt64()
                self.attributes = try cursor.readBigInt64()
            }
        }
        else {
            if byteOrder == .little {
                self.name = UInt64(try cursor.readLittleInt32())
                self.attributes = UInt64(try cursor.readLittleInt32())
            }
            else {
                self.name = UInt64(try cursor.readBigInt32())
                self.attributes = UInt64(try cursor.readBigInt32())
            }
        }
    }
}

/// ObjC 2.0 protocol structure.
public struct ObjC2Protocol: Sendable {
    /// Pointer to isa (usually null).
    public let isa: UInt64

    /// Pointer to name string.
    public let name: UInt64

    /// Pointer to adopted protocols.
    public let protocols: UInt64

    /// Pointer to instance methods.
    public let instanceMethods: UInt64

    /// Pointer to class methods.
    public let classMethods: UInt64

    /// Pointer to optional instance methods.
    public let optionalInstanceMethods: UInt64

    /// Pointer to optional class methods.
    public let optionalClassMethods: UInt64

    /// Pointer to instance properties.
    public let instanceProperties: UInt64

    /// Size of the protocol structure.
    public let size: UInt32

    /// Protocol flags.
    public let flags: UInt32

    /// Pointer to extended method types.
    public let extendedMethodTypes: UInt64

    /// Parse a protocol structure.
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
            }
            else {
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
        }
        else {
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
            }
            else {
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
    /// Pointer to category name.
    public let name: UInt64

    /// Pointer to class (note: 'class' is a Swift keyword).
    public let cls: UInt64

    /// Pointer to instance methods.
    public let instanceMethods: UInt64

    /// Pointer to class methods.
    public let classMethods: UInt64

    /// Pointer to adopted protocols.
    public let protocols: UInt64

    /// Pointer to instance properties.
    public let instanceProperties: UInt64

    /// Reserved field 1.
    public let v7: UInt64

    /// Reserved field 2.
    public let v8: UInt64

    /// Parse a category structure.
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
            }
            else {
                self.name = try cursor.readBigInt64()
                self.cls = try cursor.readBigInt64()
                self.instanceMethods = try cursor.readBigInt64()
                self.classMethods = try cursor.readBigInt64()
                self.protocols = try cursor.readBigInt64()
                self.instanceProperties = try cursor.readBigInt64()
                self.v7 = try cursor.readBigInt64()
                self.v8 = try cursor.readBigInt64()
            }
        }
        else {
            if byteOrder == .little {
                self.name = UInt64(try cursor.readLittleInt32())
                self.cls = UInt64(try cursor.readLittleInt32())
                self.instanceMethods = UInt64(try cursor.readLittleInt32())
                self.classMethods = UInt64(try cursor.readLittleInt32())
                self.protocols = UInt64(try cursor.readLittleInt32())
                self.instanceProperties = UInt64(try cursor.readLittleInt32())
                self.v7 = UInt64(try cursor.readLittleInt32())
                self.v8 = UInt64(try cursor.readLittleInt32())
            }
            else {
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
