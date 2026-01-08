import Foundation
import MachO

/// Symbol table load command (LC_SYMTAB).
public struct SymtabCommand: LoadCommandProtocol, Sendable {
    public let cmd: UInt32
    public let cmdsize: UInt32
    public let symoff: UInt32  // Symbol table offset
    public let nsyms: UInt32  // Number of symbols
    public let stroff: UInt32  // String table offset
    public let strsize: UInt32  // String table size

    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.symoff = try cursor.readLittleInt32()
                self.nsyms = try cursor.readLittleInt32()
                self.stroff = try cursor.readLittleInt32()
                self.strsize = try cursor.readLittleInt32()
            } else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.symoff = try cursor.readBigInt32()
                self.nsyms = try cursor.readBigInt32()
                self.stroff = try cursor.readBigInt32()
                self.strsize = try cursor.readBigInt32()
            }
        } catch {
            throw LoadCommandError.dataTooSmall(expected: 24, actual: data.count)
        }
    }
}

extension SymtabCommand: CustomStringConvertible {
    public var description: String {
        "SymtabCommand(nsyms: \(nsyms), symoff: 0x\(String(symoff, radix: 16)), stroff: 0x\(String(stroff, radix: 16)), strsize: \(strsize))"
    }
}

/// Dynamic symbol table load command (LC_DYSYMTAB).
public struct DysymtabCommand: LoadCommandProtocol, Sendable {
    public let cmd: UInt32
    public let cmdsize: UInt32

    // Local symbols
    public let ilocalsym: UInt32
    public let nlocalsym: UInt32

    // Externally defined symbols
    public let iextdefsym: UInt32
    public let nextdefsym: UInt32

    // Undefined symbols
    public let iundefsym: UInt32
    public let nundefsym: UInt32

    // Table of contents
    public let tocoff: UInt32
    public let ntoc: UInt32

    // Module table
    public let modtaboff: UInt32
    public let nmodtab: UInt32

    // External reference table
    public let extrefsymoff: UInt32
    public let nextrefsyms: UInt32

    // Indirect symbol table
    public let indirectsymoff: UInt32
    public let nindirectsyms: UInt32

    // External relocation entries
    public let extreloff: UInt32
    public let nextrel: UInt32

    // Local relocation entries
    public let locreloff: UInt32
    public let nlocrel: UInt32

    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.ilocalsym = try cursor.readLittleInt32()
                self.nlocalsym = try cursor.readLittleInt32()
                self.iextdefsym = try cursor.readLittleInt32()
                self.nextdefsym = try cursor.readLittleInt32()
                self.iundefsym = try cursor.readLittleInt32()
                self.nundefsym = try cursor.readLittleInt32()
                self.tocoff = try cursor.readLittleInt32()
                self.ntoc = try cursor.readLittleInt32()
                self.modtaboff = try cursor.readLittleInt32()
                self.nmodtab = try cursor.readLittleInt32()
                self.extrefsymoff = try cursor.readLittleInt32()
                self.nextrefsyms = try cursor.readLittleInt32()
                self.indirectsymoff = try cursor.readLittleInt32()
                self.nindirectsyms = try cursor.readLittleInt32()
                self.extreloff = try cursor.readLittleInt32()
                self.nextrel = try cursor.readLittleInt32()
                self.locreloff = try cursor.readLittleInt32()
                self.nlocrel = try cursor.readLittleInt32()
            } else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.ilocalsym = try cursor.readBigInt32()
                self.nlocalsym = try cursor.readBigInt32()
                self.iextdefsym = try cursor.readBigInt32()
                self.nextdefsym = try cursor.readBigInt32()
                self.iundefsym = try cursor.readBigInt32()
                self.nundefsym = try cursor.readBigInt32()
                self.tocoff = try cursor.readBigInt32()
                self.ntoc = try cursor.readBigInt32()
                self.modtaboff = try cursor.readBigInt32()
                self.nmodtab = try cursor.readBigInt32()
                self.extrefsymoff = try cursor.readBigInt32()
                self.nextrefsyms = try cursor.readBigInt32()
                self.indirectsymoff = try cursor.readBigInt32()
                self.nindirectsyms = try cursor.readBigInt32()
                self.extreloff = try cursor.readBigInt32()
                self.nextrel = try cursor.readBigInt32()
                self.locreloff = try cursor.readBigInt32()
                self.nlocrel = try cursor.readBigInt32()
            }
        } catch {
            throw LoadCommandError.dataTooSmall(expected: 80, actual: data.count)
        }
    }
}

extension DysymtabCommand: CustomStringConvertible {
    public var description: String {
        "DysymtabCommand(local: \(nlocalsym), extdef: \(nextdefsym), undef: \(nundefsym), indirect: \(nindirectsyms))"
    }
}

/// Symbol type flags.
public struct SymbolTypeFlags: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let external = SymbolTypeFlags(rawValue: UInt8(N_EXT))
    public static let privateExternal = SymbolTypeFlags(rawValue: UInt8(N_PEXT))

    /// The basic type (N_TYPE mask).
    public var type: UInt8 {
        rawValue & UInt8(N_TYPE)
    }

    /// STAB debugging symbol type.
    public var stab: UInt8 {
        rawValue & UInt8(N_STAB)
    }

    public var isExternal: Bool { contains(.external) }
    public var isPrivateExternal: Bool { contains(.privateExternal) }
    public var isStab: Bool { stab != 0 }
    public var isUndefined: Bool { type == UInt8(N_UNDF) }
    public var isAbsolute: Bool { type == UInt8(N_ABS) }
    public var isInSection: Bool { type == UInt8(N_SECT) }
    public var isPrebound: Bool { type == UInt8(N_PBUD) }
    public var isIndirect: Bool { type == UInt8(N_INDR) }
}

/// Symbol reference type.
public enum SymbolReferenceType: UInt16, Sendable {
    case undefinedNonLazy = 0  // REFERENCE_FLAG_UNDEFINED_NON_LAZY
    case undefinedLazy = 1  // REFERENCE_FLAG_UNDEFINED_LAZY
    case defined = 2  // REFERENCE_FLAG_DEFINED
    case privateDefined = 3  // REFERENCE_FLAG_PRIVATE_DEFINED
    case privateUndefinedNonLazy = 4  // REFERENCE_FLAG_PRIVATE_UNDEFINED_NON_LAZY
    case privateUndefinedLazy = 5  // REFERENCE_FLAG_PRIVATE_UNDEFINED_LAZY

    public var name: String {
        switch self {
        case .undefinedNonLazy: return "undefined non lazy"
        case .undefinedLazy: return "undefined lazy"
        case .defined: return "defined"
        case .privateDefined: return "private defined"
        case .privateUndefinedNonLazy: return "private undefined non lazy"
        case .privateUndefinedLazy: return "private undefined lazy"
        }
    }
}

/// A symbol entry from the symbol table.
public struct Symbol: Sendable {
    public let name: String
    public let typeFlags: SymbolTypeFlags
    public let sect: UInt8  // Section number (1-indexed, 0 = NO_SECT)
    public let desc: UInt16
    public let value: UInt64
    public let is32Bit: Bool

    /// The library ordinal from the descriptor.
    public var libraryOrdinal: UInt8 {
        UInt8((desc >> 8) & 0xFF)
    }

    /// The reference type from the descriptor.
    public var referenceType: SymbolReferenceType? {
        SymbolReferenceType(rawValue: desc & UInt16(REFERENCE_TYPE))
    }

    public var isExternal: Bool { typeFlags.isExternal }
    public var isPrivateExternal: Bool { typeFlags.isPrivateExternal }
    public var isDefined: Bool { !typeFlags.isUndefined }
    public var isAbsolute: Bool { typeFlags.isAbsolute }
    public var isInSection: Bool { typeFlags.isInSection }
    public var isPrebound: Bool { typeFlags.isPrebound }
    public var isIndirect: Bool { typeFlags.isIndirect }

    /// Whether this is a common symbol (undefined external with non-zero value).
    public var isCommon: Bool {
        !isDefined && isExternal && value != 0
    }

    /// Short type description (single character like nm output).
    public var shortTypeDescription: String {
        let c: String
        if typeFlags.isStab {
            c = "-"
        } else if isCommon {
            c = "c"
        } else if !isDefined || isPrebound {
            c = "u"
        } else if isAbsolute {
            c = "a"
        } else if isInSection {
            // Would need section info to determine t/d/b/s
            c = "s"
        } else if isIndirect {
            c = "i"
        } else {
            c = "?"
        }
        return isExternal ? c.uppercased() : c
    }

    /// Prefix for Objective-C class symbols.
    public static let objcClassPrefix = "_OBJC_CLASS_$_"

    /// Extract class name from an Objective-C class symbol name.
    public static func className(from symbolName: String) -> String? {
        guard symbolName.hasPrefix(objcClassPrefix) else { return nil }
        return String(symbolName.dropFirst(objcClassPrefix.count))
    }

    /// Parse a 32-bit symbol (nlist).
    public init(name: String, nlist32: nlist) {
        self.name = name
        self.typeFlags = SymbolTypeFlags(rawValue: nlist32.n_type)
        self.sect = nlist32.n_sect
        self.desc = UInt16(bitPattern: nlist32.n_desc)
        self.value = UInt64(nlist32.n_value)
        self.is32Bit = true
    }

    /// Parse a 64-bit symbol (nlist_64).
    public init(name: String, nlist64: nlist_64) {
        self.name = name
        self.typeFlags = SymbolTypeFlags(rawValue: nlist64.n_type)
        self.sect = nlist64.n_sect
        self.desc = nlist64.n_desc
        self.value = nlist64.n_value
        self.is32Bit = false
    }
}

extension Symbol: CustomStringConvertible {
    public var description: String {
        let valueStr: String
        if isDefined {
            valueStr = String(format: is32Bit ? "%08llx" : "%016llx", value)
        } else {
            valueStr = String(repeating: " ", count: is32Bit ? 8 : 16)
        }
        return "\(valueStr) \(shortTypeDescription) \(name)"
    }
}

extension Symbol: Comparable {
    public static func < (lhs: Symbol, rhs: Symbol) -> Bool {
        lhs.value < rhs.value
    }

    public static func == (lhs: Symbol, rhs: Symbol) -> Bool {
        lhs.value == rhs.value && lhs.name == rhs.name
    }
}
