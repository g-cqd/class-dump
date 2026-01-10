import Foundation

/// Protocol defining the visitor pattern for class dump traversal.
///
/// Visitors traverse the ObjC metadata tree and can perform actions at each node.
/// The visitor pattern allows separation of traversal logic from output generation.
public protocol ClassDumpVisitor: AnyObject, Sendable {
    /// Configuration options for the visitor.
    var options: ClassDumpVisitorOptions { get set }

    // MARK: - Lifecycle

    /// Called before visiting begins.
    func willBeginVisiting()

    /// Called after all visiting is complete.
    func didEndVisiting()

    // MARK: - Processor Visits

    /// Called before visiting an ObjC processor.
    func willVisitProcessor(_ processor: ObjCProcessorInfo)

    /// Called while visiting an ObjC processor (before children).
    func visitProcessor(_ processor: ObjCProcessorInfo)

    /// Called after visiting an ObjC processor.
    func didVisitProcessor(_ processor: ObjCProcessorInfo)

    // MARK: - Protocol Visits

    /// Called before visiting a protocol.
    func willVisitProtocol(_ proto: ObjCProtocol)

    /// Called after visiting a protocol.
    func didVisitProtocol(_ proto: ObjCProtocol)

    /// Called before visiting protocol properties.
    func willVisitPropertiesOfProtocol(_ proto: ObjCProtocol)

    /// Called after visiting protocol properties.
    func didVisitPropertiesOfProtocol(_ proto: ObjCProtocol)

    /// Called before visiting optional methods section.
    func willVisitOptionalMethods()

    /// Called after visiting optional methods section.
    func didVisitOptionalMethods()

    // MARK: - Class Visits

    /// Called before visiting a class.
    func willVisitClass(_ objcClass: ObjCClass)

    /// Called after visiting a class.
    func didVisitClass(_ objcClass: ObjCClass)

    /// Called before visiting class ivars.
    func willVisitIvarsOfClass(_ objcClass: ObjCClass)

    /// Called after visiting class ivars.
    func didVisitIvarsOfClass(_ objcClass: ObjCClass)

    /// Called before visiting class properties.
    func willVisitPropertiesOfClass(_ objcClass: ObjCClass)

    /// Called after visiting class properties.
    func didVisitPropertiesOfClass(_ objcClass: ObjCClass)

    // MARK: - Category Visits

    /// Called before visiting a category.
    func willVisitCategory(_ category: ObjCCategory)

    /// Called after visiting a category.
    func didVisitCategory(_ category: ObjCCategory)

    /// Called before visiting category properties.
    func willVisitPropertiesOfCategory(_ category: ObjCCategory)

    /// Called after visiting category properties.
    func didVisitPropertiesOfCategory(_ category: ObjCCategory)

    // MARK: - Member Visits

    /// Visit a class method.
    func visitClassMethod(_ method: ObjCMethod)

    /// Visit an instance method with property state tracking.
    func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState)

    /// Visit an instance variable.
    func visitIvar(_ ivar: ObjCInstanceVariable)

    /// Visit a property.
    func visitProperty(_ property: ObjCProperty)

    /// Visit remaining properties that weren't emitted via accessor methods.
    func visitRemainingProperties(_ propertyState: VisitorPropertyState)
}

// MARK: - Default Implementations

/// Default empty implementations for all visitor protocol methods.
/// Conforming types only need to override the methods they care about.
extension ClassDumpVisitor {
    /// Called before visiting begins.
    public func willBeginVisiting() {}
    /// Called after visiting ends.
    public func didEndVisiting() {}

    /// Called before visiting a processor.
    public func willVisitProcessor(_ processor: ObjCProcessorInfo) {}
    /// Called to visit a processor.
    public func visitProcessor(_ processor: ObjCProcessorInfo) {}
    /// Called after visiting a processor.
    public func didVisitProcessor(_ processor: ObjCProcessorInfo) {}

    /// Called before visiting a protocol.
    public func willVisitProtocol(_ proto: ObjCProtocol) {}
    /// Called after visiting a protocol.
    public func didVisitProtocol(_ proto: ObjCProtocol) {}
    /// Called before visiting properties of a protocol.
    public func willVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}
    /// Called after visiting properties of a protocol.
    public func didVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}
    /// Called before visiting optional methods.
    public func willVisitOptionalMethods() {}
    /// Called after visiting optional methods.
    public func didVisitOptionalMethods() {}

    /// Called before visiting a class.
    public func willVisitClass(_ objcClass: ObjCClass) {}
    /// Called after visiting a class.
    public func didVisitClass(_ objcClass: ObjCClass) {}
    /// Called before visiting ivars of a class.
    public func willVisitIvarsOfClass(_ objcClass: ObjCClass) {}
    /// Called after visiting ivars of a class.
    public func didVisitIvarsOfClass(_ objcClass: ObjCClass) {}
    /// Called before visiting properties of a class.
    public func willVisitPropertiesOfClass(_ objcClass: ObjCClass) {}
    /// Called after visiting properties of a class.
    public func didVisitPropertiesOfClass(_ objcClass: ObjCClass) {}

    /// Called before visiting a category.
    public func willVisitCategory(_ category: ObjCCategory) {}
    /// Called after visiting a category.
    public func didVisitCategory(_ category: ObjCCategory) {}
    /// Called before visiting properties of a category.
    public func willVisitPropertiesOfCategory(_ category: ObjCCategory) {}
    /// Called after visiting properties of a category.
    public func didVisitPropertiesOfCategory(_ category: ObjCCategory) {}

    /// Called to visit a class method.
    public func visitClassMethod(_ method: ObjCMethod) {}
    /// Called to visit an instance method.
    public func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState) {}
    /// Called to visit an instance variable.
    public func visitIvar(_ ivar: ObjCInstanceVariable) {}
    /// Called to visit a property.
    public func visitProperty(_ property: ObjCProperty) {}
    /// Called to visit remaining properties.
    public func visitRemainingProperties(_ propertyState: VisitorPropertyState) {}
}

// MARK: - Options

/// Style for demangling Swift names in output.
public enum DemangleStyle: String, Sendable, CaseIterable {
    /// Full Swift style: `Module.ClassName`.
    case swift

    /// ObjC style: just `ClassName` (drop module prefix).
    case objc

    /// No demangling: show raw mangled names.
    case none
}

/// Style for formatting method declarations.
public enum MethodStyle: String, Sendable, CaseIterable {
    /// ObjC style: `- (ReturnType)methodName:(ParamType)param;`.
    case objc

    /// Swift style: `func methodName(param: ParamType) -> ReturnType`.
    case swift
}

/// Output style for type formatting.
///
/// Controls how types are rendered in the output:
/// - `objc`: All types use Objective-C syntax (pointers, NS* types)
/// - `swift`: Types use Swift syntax (optionals, generics)
public enum OutputStyle: String, Sendable, CaseIterable {
    /// ObjC output style: `NSArray *`, `NSDictionary *`, `Type *`.
    case objc

    /// Swift output style: `[Type]`, `[Key: Value]`, `Type?`.
    case swift
}

/// Configuration options for class dump visitors.
public struct ClassDumpVisitorOptions: Sendable {
    /// Whether to show the structure section.
    public var shouldShowStructureSection: Bool

    /// Whether to show the protocol section.
    public var shouldShowProtocolSection: Bool

    /// Whether to show instance variable offsets.
    public var shouldShowIvarOffsets: Bool

    /// Whether to show method implementation addresses.
    public var shouldShowMethodAddresses: Bool

    /// Whether to show raw type encodings in comments (for debugging).
    public var shouldShowRawTypes: Bool

    /// Style for demangling Swift names.
    public var demangleStyle: DemangleStyle

    /// Style for formatting method declarations.
    public var methodStyle: MethodStyle

    /// Output style for type formatting.
    public var outputStyle: OutputStyle

    /// Initialize visitor options with the specified settings.
    public init(
        shouldShowStructureSection: Bool = true,
        shouldShowProtocolSection: Bool = true,
        shouldShowIvarOffsets: Bool = false,
        shouldShowMethodAddresses: Bool = false,
        shouldShowRawTypes: Bool = false,
        demangleStyle: DemangleStyle = .swift,
        methodStyle: MethodStyle = .objc,
        outputStyle: OutputStyle = .objc
    ) {
        self.shouldShowStructureSection = shouldShowStructureSection
        self.shouldShowProtocolSection = shouldShowProtocolSection
        self.shouldShowIvarOffsets = shouldShowIvarOffsets
        self.shouldShowMethodAddresses = shouldShowMethodAddresses
        self.shouldShowRawTypes = shouldShowRawTypes
        self.demangleStyle = demangleStyle
        self.methodStyle = methodStyle
        self.outputStyle = outputStyle
    }
}

// MARK: - Processor Info

/// Information about an ObjC processor being visited.
public struct ObjCProcessorInfo: Sendable {
    /// The Mach-O file being processed.
    public let machOFile: VisitorMachOFileInfo

    /// Whether this file has ObjC runtime info.
    public let hasObjectiveCRuntimeInfo: Bool

    /// Garbage collection status (if any).
    public let garbageCollectionStatus: String?

    /// Registry for structure/union type resolution.
    public let structureRegistry: StructureRegistry?

    /// Registry for method signature cross-referencing (block resolution).
    public let methodSignatureRegistry: MethodSignatureRegistry?

    /// Initialize processor info with the specified Mach-O file and metadata.
    public init(
        machOFile: VisitorMachOFileInfo,
        hasObjectiveCRuntimeInfo: Bool,
        garbageCollectionStatus: String? = nil,
        structureRegistry: StructureRegistry? = nil,
        methodSignatureRegistry: MethodSignatureRegistry? = nil
    ) {
        self.machOFile = machOFile
        self.hasObjectiveCRuntimeInfo = hasObjectiveCRuntimeInfo
        self.garbageCollectionStatus = garbageCollectionStatus
        self.structureRegistry = structureRegistry
        self.methodSignatureRegistry = methodSignatureRegistry
    }
}

/// Information about a Mach-O file being processed for visitor output.
public struct VisitorMachOFileInfo: Sendable {
    /// The filename.
    public let filename: String

    /// UUID of the file (if available).
    public let uuid: UUID?

    /// Architecture name.
    public let archName: String

    /// File type (MH_EXECUTE, MH_DYLIB, etc.).
    public let filetype: UInt32

    /// Whether the file is encrypted.
    public let isEncrypted: Bool

    /// Whether the file has protected segments.
    public let hasProtectedSegments: Bool

    /// Whether all protected segments can be decrypted.
    public let canDecryptAllSegments: Bool

    /// Dylib identifier (for MH_DYLIB).
    public let dylibIdentifier: DylibInfo?

    /// Source version string.
    public let sourceVersion: String?

    /// Build version string.
    public let buildVersion: String?

    /// Build tools list.
    public let buildTools: [String]?

    /// Minimum macOS version.
    public let minMacOSVersion: String?

    /// Minimum iOS version.
    public let minIOSVersion: String?

    /// SDK version.
    public let sdkVersion: String?

    /// Run paths.
    public let runPaths: [(path: String, resolved: String)]

    /// Dyld environment entries.
    public let dyldEnvironment: [String]

    /// Initialize Mach-O file info with the specified properties.
    public init(
        filename: String,
        uuid: UUID? = nil,
        archName: String,
        filetype: UInt32 = 0,
        isEncrypted: Bool = false,
        hasProtectedSegments: Bool = false,
        canDecryptAllSegments: Bool = true,
        dylibIdentifier: DylibInfo? = nil,
        sourceVersion: String? = nil,
        buildVersion: String? = nil,
        buildTools: [String]? = nil,
        minMacOSVersion: String? = nil,
        minIOSVersion: String? = nil,
        sdkVersion: String? = nil,
        runPaths: [(path: String, resolved: String)] = [],
        dyldEnvironment: [String] = []
    ) {
        self.filename = filename
        self.uuid = uuid
        self.archName = archName
        self.filetype = filetype
        self.isEncrypted = isEncrypted
        self.hasProtectedSegments = hasProtectedSegments
        self.canDecryptAllSegments = canDecryptAllSegments
        self.dylibIdentifier = dylibIdentifier
        self.sourceVersion = sourceVersion
        self.buildVersion = buildVersion
        self.buildTools = buildTools
        self.minMacOSVersion = minMacOSVersion
        self.minIOSVersion = minIOSVersion
        self.sdkVersion = sdkVersion
        self.runPaths = runPaths
        self.dyldEnvironment = dyldEnvironment
    }
}

/// Information about a dylib.
public struct DylibInfo: Sendable {
    /// The dylib name/path.
    public let name: String

    /// Current version string.
    public let currentVersion: String

    /// Compatibility version string.
    public let compatibilityVersion: String

    /// Initialize dylib info with the specified name and versions.
    public init(name: String, currentVersion: String, compatibilityVersion: String) {
        self.name = name
        self.currentVersion = currentVersion
        self.compatibilityVersion = compatibilityVersion
    }
}
