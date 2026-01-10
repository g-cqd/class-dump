import Foundation

/// A visitor that builds mappings from class/protocol names to framework names.
///
/// This visitor is used by MultiFileVisitor to generate proper import statements
/// when creating separate header files.
public final class ClassFrameworkVisitor: ClassDumpVisitor, @unchecked Sendable {
    /// Mapping from class names to framework names.
    public private(set) var frameworkNamesByClassName: [String: String] = [:]

    /// Mapping from protocol names to framework names.
    public private(set) var frameworkNamesByProtocolName: [String: String] = [:]

    /// Visitor options.
    public var options: ClassDumpVisitorOptions

    /// Current framework name being processed.
    private var currentFrameworkName: String?

    /// Initialize a framework visitor.
    public init(options: ClassDumpVisitorOptions = .init()) {
        self.options = options
    }

    // MARK: - Processor Visits

    /// Begin visiting a processor - extract framework name.
    public func willVisitProcessor(_ processor: ObjCProcessorInfo) {
        currentFrameworkName = importBaseName(from: processor.machOFile.filename)
    }

    // MARK: - Class Visits

    /// Begin visiting a class - collect class and superclass references.
    public func willVisitClass(_ objcClass: ObjCClass) {
        addClassName(objcClass.name, referencedInFramework: currentFrameworkName)

        // Add external superclass references
        if let superRef = objcClass.superclassReference,
            superRef.isExternal,
            let frameworkName = superRef.frameworkName,
            let className = superRef.className
        {
            addClassName(className, referencedInFramework: frameworkName)
        }
    }

    /// Begin visiting a protocol - collect protocol reference.
    public func willVisitProtocol(_ proto: ObjCProtocol) {
        addProtocolName(proto.name, referencedInFramework: currentFrameworkName)
    }

    /// Begin visiting a category - collect external class references.
    public func willVisitCategory(_ category: ObjCCategory) {
        // Add external class references from categories
        if let classRef = category.classReference,
            classRef.isExternal,
            let frameworkName = classRef.frameworkName,
            let className = classRef.className
        {
            addClassName(className, referencedInFramework: frameworkName)
        }
    }

    // MARK: - Framework Mapping

    private func addClassName(_ name: String, referencedInFramework frameworkName: String?) {
        guard let framework = frameworkName, !name.isEmpty else { return }
        frameworkNamesByClassName[name] = framework
    }

    private func addProtocolName(_ name: String, referencedInFramework frameworkName: String?) {
        guard let framework = frameworkName, !name.isEmpty else { return }
        frameworkNamesByProtocolName[name] = framework
    }
}

// MARK: - Import Name Extraction

extension ClassFrameworkVisitor {
    /// Extract the base framework/library name from a path.
    ///
    /// For example:
    /// - `/System/Library/Frameworks/AppKit.framework/AppKit` -> `AppKit`
    /// - `/usr/lib/libSystem.B.dylib` -> `libSystem.B`
    private func importBaseName(from path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let filename = url.deletingPathExtension().lastPathComponent

        // Handle framework bundles
        if path.contains(".framework/") {
            if let range = path.range(of: ".framework/") {
                let frameworkPath = String(path[..<range.lowerBound])
                return URL(fileURLWithPath: frameworkPath).lastPathComponent
            }
        }

        // Handle dylibs
        if filename.hasPrefix("lib") {
            // Return without "lib" prefix for standard naming
            return filename
        }

        return filename.isEmpty ? nil : filename
    }
}

// MARK: - Class Reference Info

/// Information about a class reference (for external class tracking).
public struct ClassReferenceInfo: Sendable {
    /// Whether the class is external (from another library/framework).
    public let isExternal: Bool

    /// The class name.
    public let className: String?

    /// The framework name (if external).
    public let frameworkName: String?

    /// Initialize class reference info.
    public init(isExternal: Bool, className: String?, frameworkName: String?) {
        self.isExternal = isExternal
        self.className = className
        self.frameworkName = frameworkName
    }
}

// MARK: - ObjCClass Extension

extension ObjCClass {
    /// Reference info for the superclass.
    public var superclassReference: ClassReferenceInfo? {
        // This would be populated from symbol information during parsing
        nil
    }
}

// MARK: - ObjCCategory Extension

extension ObjCCategory {
    /// Reference info for the class this category extends.
    public var classReference: ClassReferenceInfo? {
        // This would be populated from symbol information during parsing
        nil
    }
}
