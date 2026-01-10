import Foundation
import MachO

/// Load command type identifier.
public enum LoadCommandType: UInt32, Sendable, CaseIterable {
    // Basic load commands
    case segment = 0x1  // LC_SEGMENT
    case symtab = 0x2  // LC_SYMTAB
    case symseg = 0x3  // LC_SYMSEG (obsolete)
    case thread = 0x4  // LC_THREAD
    case unixThread = 0x5  // LC_UNIXTHREAD
    case loadFVMLib = 0x6  // LC_LOADFVMLIB
    case idFVMLib = 0x7  // LC_IDFVMLIB
    case ident = 0x8  // LC_IDENT (obsolete)
    case fvmFile = 0x9  // LC_FVMFILE (internal use)
    case prepage = 0xa  // LC_PREPAGE (internal use)
    case dysymtab = 0xb  // LC_DYSYMTAB
    case loadDylib = 0xc  // LC_LOAD_DYLIB
    case idDylib = 0xd  // LC_ID_DYLIB
    case loadDylinker = 0xe  // LC_LOAD_DYLINKER
    case idDylinker = 0xf  // LC_ID_DYLINKER
    case preboundDylib = 0x10  // LC_PREBOUND_DYLIB
    case routines = 0x11  // LC_ROUTINES
    case subFramework = 0x12  // LC_SUB_FRAMEWORK
    case subUmbrella = 0x13  // LC_SUB_UMBRELLA
    case subClient = 0x14  // LC_SUB_CLIENT
    case subLibrary = 0x15  // LC_SUB_LIBRARY
    case twoLevelHints = 0x16  // LC_TWOLEVEL_HINTS
    case prebindChecksum = 0x17  // LC_PREBIND_CKSUM

    // LC_REQ_DYLD commands (0x80000000 bit set)
    case loadWeakDylib = 0x8000_0018  // LC_LOAD_WEAK_DYLIB
    case segment64 = 0x19  // LC_SEGMENT_64
    case routines64 = 0x1a  // LC_ROUTINES_64
    case uuid = 0x1b  // LC_UUID
    case rpath = 0x8000_001c  // LC_RPATH
    case codeSignature = 0x1d  // LC_CODE_SIGNATURE
    case segmentSplitInfo = 0x1e  // LC_SEGMENT_SPLIT_INFO
    case reexportDylib = 0x8000_001f  // LC_REEXPORT_DYLIB
    case lazyLoadDylib = 0x20  // LC_LAZY_LOAD_DYLIB
    case encryptionInfo = 0x21  // LC_ENCRYPTION_INFO
    case dyldInfo = 0x22  // LC_DYLD_INFO
    case dyldInfoOnly = 0x8000_0022  // LC_DYLD_INFO_ONLY
    case loadUpwardDylib = 0x8000_0023  // LC_LOAD_UPWARD_DYLIB
    case versionMinMacOSX = 0x24  // LC_VERSION_MIN_MACOSX
    case versionMinIPhoneOS = 0x25  // LC_VERSION_MIN_IPHONEOS
    case functionStarts = 0x26  // LC_FUNCTION_STARTS
    case dyldEnvironment = 0x27  // LC_DYLD_ENVIRONMENT
    case main = 0x8000_0028  // LC_MAIN
    case dataInCode = 0x29  // LC_DATA_IN_CODE
    case sourceVersion = 0x2a  // LC_SOURCE_VERSION
    case dylibCodeSignDRS = 0x2b  // LC_DYLIB_CODE_SIGN_DRS
    case encryptionInfo64 = 0x2c  // LC_ENCRYPTION_INFO_64
    case linkerOption = 0x2d  // LC_LINKER_OPTION
    case linkerOptimizationHint = 0x2e  // LC_LINKER_OPTIMIZATION_HINT
    case versionMinTVOS = 0x2f  // LC_VERSION_MIN_TVOS
    case versionMinWatchOS = 0x30  // LC_VERSION_MIN_WATCHOS
    case note = 0x31  // LC_NOTE
    case buildVersion = 0x32  // LC_BUILD_VERSION
    case dyldExportsTrie = 0x8000_0033  // LC_DYLD_EXPORTS_TRIE
    case dyldChainedFixups = 0x8000_0034  // LC_DYLD_CHAINED_FIXUPS
    case filesetEntry = 0x8000_0035  // LC_FILESET_ENTRY

    /// Whether this command must be understood to execute the binary.
    public var mustUnderstandToExecute: Bool {
        (rawValue & UInt32(LC_REQ_DYLD)) != 0
    }

    /// Human-readable name for this load command type.
    public var name: String {
        switch self {
            case .segment: return "LC_SEGMENT"
            case .symtab: return "LC_SYMTAB"
            case .symseg: return "LC_SYMSEG"
            case .thread: return "LC_THREAD"
            case .unixThread: return "LC_UNIXTHREAD"
            case .loadFVMLib: return "LC_LOADFVMLIB"
            case .idFVMLib: return "LC_IDFVMLIB"
            case .ident: return "LC_IDENT"
            case .fvmFile: return "LC_FVMFILE"
            case .prepage: return "LC_PREPAGE"
            case .dysymtab: return "LC_DYSYMTAB"
            case .loadDylib: return "LC_LOAD_DYLIB"
            case .idDylib: return "LC_ID_DYLIB"
            case .loadDylinker: return "LC_LOAD_DYLINKER"
            case .idDylinker: return "LC_ID_DYLINKER"
            case .preboundDylib: return "LC_PREBOUND_DYLIB"
            case .routines: return "LC_ROUTINES"
            case .subFramework: return "LC_SUB_FRAMEWORK"
            case .subUmbrella: return "LC_SUB_UMBRELLA"
            case .subClient: return "LC_SUB_CLIENT"
            case .subLibrary: return "LC_SUB_LIBRARY"
            case .twoLevelHints: return "LC_TWOLEVEL_HINTS"
            case .prebindChecksum: return "LC_PREBIND_CKSUM"
            case .loadWeakDylib: return "LC_LOAD_WEAK_DYLIB"
            case .segment64: return "LC_SEGMENT_64"
            case .routines64: return "LC_ROUTINES_64"
            case .uuid: return "LC_UUID"
            case .rpath: return "LC_RPATH"
            case .codeSignature: return "LC_CODE_SIGNATURE"
            case .segmentSplitInfo: return "LC_SEGMENT_SPLIT_INFO"
            case .reexportDylib: return "LC_REEXPORT_DYLIB"
            case .lazyLoadDylib: return "LC_LAZY_LOAD_DYLIB"
            case .encryptionInfo: return "LC_ENCRYPTION_INFO"
            case .dyldInfo: return "LC_DYLD_INFO"
            case .dyldInfoOnly: return "LC_DYLD_INFO_ONLY"
            case .loadUpwardDylib: return "LC_LOAD_UPWARD_DYLIB"
            case .versionMinMacOSX: return "LC_VERSION_MIN_MACOSX"
            case .versionMinIPhoneOS: return "LC_VERSION_MIN_IPHONEOS"
            case .functionStarts: return "LC_FUNCTION_STARTS"
            case .dyldEnvironment: return "LC_DYLD_ENVIRONMENT"
            case .main: return "LC_MAIN"
            case .dataInCode: return "LC_DATA_IN_CODE"
            case .sourceVersion: return "LC_SOURCE_VERSION"
            case .dylibCodeSignDRS: return "LC_DYLIB_CODE_SIGN_DRS"
            case .encryptionInfo64: return "LC_ENCRYPTION_INFO_64"
            case .linkerOption: return "LC_LINKER_OPTION"
            case .linkerOptimizationHint: return "LC_LINKER_OPTIMIZATION_HINT"
            case .versionMinTVOS: return "LC_VERSION_MIN_TVOS"
            case .versionMinWatchOS: return "LC_VERSION_MIN_WATCHOS"
            case .note: return "LC_NOTE"
            case .buildVersion: return "LC_BUILD_VERSION"
            case .dyldExportsTrie: return "LC_DYLD_EXPORTS_TRIE"
            case .dyldChainedFixups: return "LC_DYLD_CHAINED_FIXUPS"
            case .filesetEntry: return "LC_FILESET_ENTRY"
        }
    }

    /// Creates a LoadCommandType from a raw command value.
    public init?(rawCmd: UInt32) {
        self.init(rawValue: rawCmd)
    }

    /// Returns the name for an arbitrary command value (including unknown commands).
    public static func name(for cmd: UInt32) -> String {
        if let type = LoadCommandType(rawValue: cmd) {
            return type.name
        }
        return String(format: "LC_UNKNOWN(0x%08x)", cmd)
    }
}
