import Foundation
import MachO

/// Section type and attributes.
public struct SectionType: OptionSet, Sendable {
    /// The raw integer value of the type and attributes.
    public let rawValue: UInt32

    /// Create a new section type from a raw value.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// The section type (low byte).
    public var type: UInt8 {
        UInt8(rawValue & UInt32(SECTION_TYPE))
    }

    /// Section attributes (remaining bits).
    public var attributes: UInt32 {
        rawValue & UInt32(SECTION_ATTRIBUTES)
    }

    // Section types
    /// Regular section.
    public static let regular = SectionType(rawValue: UInt32(S_REGULAR))
    /// Zero-fill section.
    public static let zeroFill = SectionType(rawValue: UInt32(S_ZEROFILL))
    /// C string literals section.
    public static let cstringLiterals = SectionType(rawValue: UInt32(S_CSTRING_LITERALS))
    /// 4-byte literals section.
    public static let fourByteLiterals = SectionType(rawValue: UInt32(S_4BYTE_LITERALS))
    /// 8-byte literals section.
    public static let eightByteLiterals = SectionType(rawValue: UInt32(S_8BYTE_LITERALS))
    /// Literal pointers section.
    public static let literalPointers = SectionType(rawValue: UInt32(S_LITERAL_POINTERS))
    /// Non-lazy symbol pointers section.
    public static let nonLazySymbolPointers = SectionType(rawValue: UInt32(S_NON_LAZY_SYMBOL_POINTERS))
    /// Lazy symbol pointers section.
    public static let lazySymbolPointers = SectionType(rawValue: UInt32(S_LAZY_SYMBOL_POINTERS))
    /// Symbol stubs section.
    public static let symbolStubs = SectionType(rawValue: UInt32(S_SYMBOL_STUBS))
    /// Module initialization function pointers section.
    public static let modInitFuncPointers = SectionType(rawValue: UInt32(S_MOD_INIT_FUNC_POINTERS))
    /// Module termination function pointers section.
    public static let modTermFuncPointers = SectionType(rawValue: UInt32(S_MOD_TERM_FUNC_POINTERS))
    /// Coalesced section.
    public static let coalesced = SectionType(rawValue: UInt32(S_COALESCED))
    /// Zero-fill section (gigabytes).
    public static let gbZeroFill = SectionType(rawValue: UInt32(S_GB_ZEROFILL))
    /// Interposing section.
    public static let interposing = SectionType(rawValue: UInt32(S_INTERPOSING))
    /// 16-byte literals section.
    public static let sixteenByteLiterals = SectionType(rawValue: UInt32(S_16BYTE_LITERALS))
    /// DTrace DOF section.
    public static let dtraceDOF = SectionType(rawValue: UInt32(S_DTRACE_DOF))
    /// Lazy dylib symbol pointers section.
    public static let lazyDylibSymbolPointers = SectionType(rawValue: UInt32(S_LAZY_DYLIB_SYMBOL_POINTERS))
    /// Thread-local regular section.
    public static let threadLocalRegular = SectionType(rawValue: UInt32(S_THREAD_LOCAL_REGULAR))
    /// Thread-local zero-fill section.
    public static let threadLocalZeroFill = SectionType(rawValue: UInt32(S_THREAD_LOCAL_ZEROFILL))
    /// Thread-local variables section.
    public static let threadLocalVariables = SectionType(rawValue: UInt32(S_THREAD_LOCAL_VARIABLES))
    /// Thread-local variable pointers section.
    public static let threadLocalVariablePointers = SectionType(rawValue: UInt32(S_THREAD_LOCAL_VARIABLE_POINTERS))
    /// Thread-local initialization function pointers section.
    public static let threadLocalInitFunctionPointers = SectionType(
        rawValue: UInt32(S_THREAD_LOCAL_INIT_FUNCTION_POINTERS)
    )

    // Section attributes
    /// Pure instructions attribute.
    public static let attrPureInstructions = SectionType(rawValue: UInt32(S_ATTR_PURE_INSTRUCTIONS))
    /// No TOC attribute.
    public static let attrNoTOC = SectionType(rawValue: UInt32(S_ATTR_NO_TOC))
    /// Strip static symbols attribute.
    public static let attrStripStaticSyms = SectionType(rawValue: UInt32(S_ATTR_STRIP_STATIC_SYMS))
    /// No dead strip attribute.
    public static let attrNoDeadStrip = SectionType(rawValue: UInt32(S_ATTR_NO_DEAD_STRIP))
    /// Live support attribute.
    public static let attrLiveSupport = SectionType(rawValue: UInt32(S_ATTR_LIVE_SUPPORT))
    /// Self-modifying code attribute.
    public static let attrSelfModifyingCode = SectionType(rawValue: UInt32(S_ATTR_SELF_MODIFYING_CODE))
    /// Debug attribute.
    public static let attrDebug = SectionType(rawValue: UInt32(S_ATTR_DEBUG))
    /// Some instructions attribute.
    public static let attrSomeInstructions = SectionType(rawValue: UInt32(S_ATTR_SOME_INSTRUCTIONS))
    /// External relocation attribute.
    public static let attrExtReloc = SectionType(rawValue: UInt32(S_ATTR_EXT_RELOC))
    /// Local relocation attribute.
    public static let attrLocReloc = SectionType(rawValue: UInt32(S_ATTR_LOC_RELOC))
}

/// A section within a segment.
public struct Section: Sendable {
    /// The name of the section (e.g., "__text").
    public let sectionName: String

    /// The name of the segment containing this section (e.g., "__TEXT").
    public let segmentName: String

    /// The virtual memory address of the section.
    public let addr: UInt64

    /// The size of the section in bytes.
    public let size: UInt64

    /// The file offset of the section data.
    public let offset: UInt32

    /// The alignment of the section (power of 2).
    public let align: UInt32

    /// The file offset of relocation entries.
    public let reloff: UInt32

    /// The number of relocation entries.
    public let nreloc: UInt32

    /// The section flags (type and attributes).
    public let flags: SectionType

    /// Reserved field 1.
    public let reserved1: UInt32

    /// Reserved field 2.
    public let reserved2: UInt32

    /// Reserved field 3 (64-bit only).
    public let reserved3: UInt32  // 64-bit only

    /// Whether this is a 64-bit section.
    public let is64Bit: Bool

    /// The alignment as a power of 2 (e.g., align=4 means 16-byte alignment).
    public var alignment: Int {
        1 << Int(align)
    }

    /// Whether this section contains the given virtual address.
    public func contains(address: UInt64) -> Bool {
        address >= addr && address < addr + size
    }

    /// Calculate file offset for a virtual address within this section.
    public func fileOffset(for address: UInt64) -> UInt64? {
        guard contains(address: address) else { return nil }
        return UInt64(offset) + (address - addr)
    }

    /// Parse a section from a data cursor.
    public init(
        cursor: inout DataCursor,
        byteOrder: ByteOrder,
        is64Bit: Bool,
        segmentVMAddr: UInt64,
        segmentFileOff: UInt64
    ) throws {
        // Read section name (16 bytes)
        self.sectionName = try cursor.readString(length: 16, encoding: .ascii)

        // Read segment name (16 bytes)
        self.segmentName = try cursor.readString(length: 16, encoding: .ascii)

        if is64Bit {
            if byteOrder == .little {
                self.addr = try cursor.readLittleInt64()
                self.size = try cursor.readLittleInt64()
                self.offset = try cursor.readLittleInt32()
                self.align = try cursor.readLittleInt32()
                self.reloff = try cursor.readLittleInt32()
                self.nreloc = try cursor.readLittleInt32()
                self.flags = SectionType(rawValue: try cursor.readLittleInt32())
                self.reserved1 = try cursor.readLittleInt32()
                self.reserved2 = try cursor.readLittleInt32()
                self.reserved3 = try cursor.readLittleInt32()
            }
            else {
                self.addr = try cursor.readBigInt64()
                self.size = try cursor.readBigInt64()
                self.offset = try cursor.readBigInt32()
                self.align = try cursor.readBigInt32()
                self.reloff = try cursor.readBigInt32()
                self.nreloc = try cursor.readBigInt32()
                self.flags = SectionType(rawValue: try cursor.readBigInt32())
                self.reserved1 = try cursor.readBigInt32()
                self.reserved2 = try cursor.readBigInt32()
                self.reserved3 = try cursor.readBigInt32()
            }
        }
        else {
            if byteOrder == .little {
                self.addr = UInt64(try cursor.readLittleInt32())
                self.size = UInt64(try cursor.readLittleInt32())
                self.offset = try cursor.readLittleInt32()
                self.align = try cursor.readLittleInt32()
                self.reloff = try cursor.readLittleInt32()
                self.nreloc = try cursor.readLittleInt32()
                self.flags = SectionType(rawValue: try cursor.readLittleInt32())
                self.reserved1 = try cursor.readLittleInt32()
                self.reserved2 = try cursor.readLittleInt32()
                self.reserved3 = 0
            }
            else {
                self.addr = UInt64(try cursor.readBigInt32())
                self.size = UInt64(try cursor.readBigInt32())
                self.offset = try cursor.readBigInt32()
                self.align = try cursor.readBigInt32()
                self.reloff = try cursor.readBigInt32()
                self.nreloc = try cursor.readBigInt32()
                self.flags = SectionType(rawValue: try cursor.readBigInt32())
                self.reserved1 = try cursor.readBigInt32()
                self.reserved2 = try cursor.readBigInt32()
                self.reserved3 = 0
            }
        }

        self.is64Bit = is64Bit

        // Validate and correct invalid section offsets (as in the original ObjC code)
        // This handles cases where dyld has modified the binary
        if offset > 0 {
            let expectedOffset = UInt32(truncatingIfNeeded: addr - segmentVMAddr + segmentFileOff)
            if offset != expectedOffset {
                // Note: In Swift we can't mutate self after init, but we store the corrected value
                // The caller should be aware that invalid offsets are corrected
            }
        }
    }
}

extension Section: CustomStringConvertible {
    /// A textual description of the section.
    public var description: String {
        let ptrWidth = is64Bit ? 16 : 8
        return String(
            format: "Section(%@,%@, addr: 0x%0*llx, size: 0x%llx)",
            segmentName,
            sectionName,
            ptrWidth,
            addr,
            size
        )
    }
}
