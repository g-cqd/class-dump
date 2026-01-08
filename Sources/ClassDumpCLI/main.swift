import ArgumentParser
import ClassDumpCore
import Foundation

@main
struct ClassDumpCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "class-dump",
        abstract: "Generates Objective-C header files from Mach-O binaries.",
        version: "4.0.1 (Swift)"
    )

    @Argument(help: "The Mach-O file to process")
    var file: String

    // MARK: - Architecture Options

    @Option(
        name: .long,
        help:
            "Select a specific architecture from a universal binary (ppc, ppc64, i386, x86_64, armv6, armv7, armv7s, arm64)"
    )
    var arch: String?

    @Flag(name: .long, help: "List the architectures in the file, then exit")
    var listArches: Bool = false

    // MARK: - Display Options

    @Flag(name: .customShort("a"), help: "Show instance variable offsets")
    var showIvarOffsets: Bool = false

    @Flag(name: .customShort("A"), help: "Show implementation addresses")
    var showImpAddr: Bool = false

    @Flag(name: .customShort("t"), help: "Suppress header in output, for testing")
    var suppressHeader: Bool = false

    // MARK: - Sorting Options

    @Flag(name: .customShort("s"), help: "Sort classes and categories by name")
    var sort: Bool = false

    @Flag(name: .customShort("I"), help: "Sort classes, categories, and protocols by inheritance (overrides -s)")
    var sortByInheritance: Bool = false

    @Flag(name: .customShort("S"), help: "Sort methods by name")
    var sortMethods: Bool = false

    // MARK: - Filtering Options

    @Option(name: .customShort("C"), help: "Only display classes matching regular expression")
    var match: String?

    @Option(name: .customShort("f"), help: "Find string in method name")
    var find: String?

    // MARK: - Output Options

    @Flag(name: .customShort("H"), help: "Generate header files in current directory, or directory specified with -o")
    var generateHeaders: Bool = false

    @Option(name: .customShort("o"), help: "Output directory used for -H")
    var outputDir: String?

    // MARK: - Framework Options

    @Flag(name: .customShort("r"), help: "Recursively expand frameworks and fixed VM shared libraries")
    var recursive: Bool = false

    // MARK: - SDK Options

    @Option(name: .long, help: "Specify iOS SDK version")
    var sdkIos: String?

    @Option(name: .long, help: "Specify Mac OS X SDK version")
    var sdkMac: String?

    @Option(name: .long, help: "Specify the full SDK root path")
    var sdkRoot: String?

    // MARK: - Hide Options

    @Option(name: .long, help: "Hide section (structures, protocols, or all)")
    var hide: [String] = []

    // MARK: - Demangling Options

    @Flag(name: .long, inversion: .prefixedNo, help: "Demangle Swift type names (default: true)")
    var demangle: Bool = true

    @Option(name: .long, help: "Demangling style: swift (Module.Type) or objc (Type only)")
    var demangleStyle: String?

    mutating func run() async throws {
        // Load the Mach-O file
        let url = URL(fileURLWithPath: file)
        guard FileManager.default.fileExists(atPath: file) else {
            throw ClassDumpError.fileNotFound(file)
        }

        let binary = try MachOBinary(contentsOf: url)

        // Handle --list-arches
        if listArches {
            print(binary.archNames.joined(separator: " "))
            return
        }

        // Select architecture
        let machOFile: MachOFile
        if let archName = arch {
            guard let requestedArch = Arch(name: archName) else {
                throw ClassDumpError.invalidArch(archName)
            }
            machOFile = try binary.machOFile(for: requestedArch)
        } else {
            machOFile = try binary.bestMatchForLocal()
        }

        // Build SDK root if specified (reserved for future recursive framework loading)
        _ = resolveSDKRoot()

        // Process ObjC metadata (uses chained fixups for external symbol resolution)
        let processor = ObjC2Processor(machOFile: machOFile)

        let metadata: ObjCMetadata
        do {
            metadata = try processor.process()
        } catch {
            throw ClassDumpError.processingFailed(file, error)
        }

        // Determine demangle style
        let resolvedDemangleStyle: DemangleStyle
        if !demangle {
            resolvedDemangleStyle = .none
        } else if let style = demangleStyle?.lowercased() {
            switch style {
            case "swift":
                resolvedDemangleStyle = .swift
            case "objc":
                resolvedDemangleStyle = .objc
            default:
                resolvedDemangleStyle = .swift
            }
        } else {
            resolvedDemangleStyle = .swift
        }

        // Build visitor options
        let visitorOptions = ClassDumpVisitorOptions(
            shouldShowStructureSection: !hide.contains("structures") && !hide.contains("all"),
            shouldShowProtocolSection: !hide.contains("protocols") && !hide.contains("all"),
            shouldShowIvarOffsets: showIvarOffsets,
            shouldShowMethodAddresses: showImpAddr,
            demangleStyle: resolvedDemangleStyle
        )

        // Build processor info
        let machOFileInfo = VisitorMachOFileInfo(
            filename: url.lastPathComponent,
            archName: machOFile.arch.name,
            filetype: machOFile.header.filetype
        )
        let processorInfo = ObjCProcessorInfo(
            machOFile: machOFileInfo,
            hasObjectiveCRuntimeInfo: !metadata.classes.isEmpty || !metadata.protocols.isEmpty
                || !metadata.categories.isEmpty
        )

        // Handle -f (find method)
        if let searchString = find {
            let findVisitor = FindMethodVisitor(options: visitorOptions)
            findVisitor.searchString = searchString
            if !suppressHeader {
                findVisitor.headerString = generateHeaderString()
            }
            visitMetadata(metadata, processorInfo: processorInfo, with: findVisitor)
            return
        }

        // Handle -H (generate separate headers)
        if generateHeaders {
            let multiVisitor = MultiFileVisitor(options: visitorOptions)
            multiVisitor.outputPath = outputDir ?? "."
            if !suppressHeader {
                multiVisitor.headerString = generateHeaderString()
            }
            visitMetadata(metadata, processorInfo: processorInfo, with: multiVisitor)
            return
        }

        // Standard output
        let visitor: ClassDumpVisitor
        if suppressHeader {
            visitor = TextClassDumpVisitor(options: visitorOptions)
        } else {
            let headerVisitor = ClassDumpHeaderVisitor(options: visitorOptions)
            headerVisitor.headerString = generateHeaderString()
            visitor = headerVisitor
        }

        visitMetadata(metadata, processorInfo: processorInfo, with: visitor)

        // Output result
        if let textVisitor = visitor as? TextClassDumpVisitor {
            print(textVisitor.resultString)
        }
    }

    // MARK: - Helper Methods

    private func resolveSDKRoot() -> String? {
        if let root = sdkRoot {
            return root
        }

        if let version = sdkIos {
            if FileManager.default.fileExists(atPath: "/Applications/Xcode.app") {
                return
                    "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS\(version).sdk"
            } else if FileManager.default.fileExists(atPath: "/Developer") {
                return "/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS\(version).sdk"
            }
        }

        if let version = sdkMac {
            if FileManager.default.fileExists(atPath: "/Applications/Xcode.app") {
                return
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX\(version).sdk"
            } else if FileManager.default.fileExists(atPath: "/Developer") {
                return "/Developer/SDKs/MacOSX\(version).sdk"
            }
        }

        return nil
    }

    private func generateHeaderString() -> String {
        ClassDumpHeaderVisitor.generateHeader(generatedBy: "class-dump", version: "4.0.0 (Swift)")
    }

    private func shouldShow(name: String) -> Bool {
        guard let pattern = match else { return true }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return true
        }
        let range = NSRange(name.startIndex..., in: name)
        return regex.firstMatch(in: name, options: [], range: range) != nil
    }

    private func sortClasses(_ classes: [ObjCClass]) -> [ObjCClass] {
        if sortByInheritance {
            // Sort by inheritance depth, then by name
            return classes.sorted { lhs, rhs in
                let lhsDepth = inheritanceDepth(of: lhs, in: classes)
                let rhsDepth = inheritanceDepth(of: rhs, in: classes)
                if lhsDepth != rhsDepth {
                    return lhsDepth < rhsDepth
                }
                return lhs.name < rhs.name
            }
        } else if sort {
            return classes.sorted { $0.name < $1.name }
        }
        return classes
    }

    private func inheritanceDepth(of cls: ObjCClass, in classes: [ObjCClass]) -> Int {
        var depth = 0
        var current: ObjCClass? = cls
        while let c = current, let superName = c.superclassName {
            depth += 1
            current = classes.first { $0.name == superName }
        }
        return depth
    }

    private func visitMetadata(
        _ metadata: ObjCMetadata, processorInfo: ObjCProcessorInfo, with visitor: ClassDumpVisitor
    ) {
        visitor.willBeginVisiting()
        visitor.willVisitProcessor(processorInfo)
        visitor.visitProcessor(processorInfo)

        // Visit protocols (only if not hidden)
        if visitor.options.shouldShowProtocolSection {
            let protocols =
                sort || sortByInheritance
                ? metadata.protocols.sorted { $0.name < $1.name }
                : metadata.protocols

            for proto in protocols {
                if shouldShow(name: proto.name) {
                    visitProtocol(proto, with: visitor)
                }
            }
        }

        // Visit classes
        let classes = sortClasses(metadata.classes)
        for cls in classes {
            if shouldShow(name: cls.name) {
                visitClass(cls, with: visitor)
            }
        }

        // Visit categories
        let categories =
            sort || sortByInheritance
            ? metadata.categories.sorted { $0.name < $1.name }
            : metadata.categories

        for category in categories {
            if shouldShow(name: category.name) {
                visitCategory(category, with: visitor)
            }
        }

        visitor.didVisitProcessor(processorInfo)
        visitor.didEndVisiting()
    }

    private func visitProtocol(_ proto: ObjCProtocol, with visitor: ClassDumpVisitor) {
        visitor.willVisitProtocol(proto)
        visitor.willVisitPropertiesOfProtocol(proto)

        for property in proto.properties {
            visitor.visitProperty(property)
        }

        visitor.didVisitPropertiesOfProtocol(proto)

        let propertyState = VisitorPropertyState(properties: proto.properties)

        // Required methods
        let classMethods = sortMethods ? proto.classMethods.sorted() : proto.classMethods
        for method in classMethods {
            visitor.visitClassMethod(method)
        }

        let instanceMethods = sortMethods ? proto.instanceMethods.sorted() : proto.instanceMethods
        for method in instanceMethods {
            visitor.visitInstanceMethod(method, propertyState: propertyState)
        }

        // Optional methods
        let optionalClassMethods = sortMethods ? proto.optionalClassMethods.sorted() : proto.optionalClassMethods
        let optionalInstanceMethods =
            sortMethods ? proto.optionalInstanceMethods.sorted() : proto.optionalInstanceMethods

        if !optionalClassMethods.isEmpty || !optionalInstanceMethods.isEmpty {
            visitor.willVisitOptionalMethods()
            for method in optionalClassMethods {
                visitor.visitClassMethod(method)
            }
            for method in optionalInstanceMethods {
                visitor.visitInstanceMethod(method, propertyState: propertyState)
            }
            visitor.didVisitOptionalMethods()
        }

        visitor.visitRemainingProperties(propertyState)
        visitor.didVisitProtocol(proto)
    }

    private func visitClass(_ cls: ObjCClass, with visitor: ClassDumpVisitor) {
        visitor.willVisitClass(cls)

        // Instance variables
        if !cls.instanceVariables.isEmpty {
            visitor.willVisitIvarsOfClass(cls)
            for ivar in cls.instanceVariables {
                visitor.visitIvar(ivar)
            }
            visitor.didVisitIvarsOfClass(cls)
        }

        // Properties
        visitor.willVisitPropertiesOfClass(cls)
        for property in cls.properties {
            visitor.visitProperty(property)
        }
        visitor.didVisitPropertiesOfClass(cls)

        let propertyState = VisitorPropertyState(properties: cls.properties)

        // Class methods
        let classMethods = sortMethods ? cls.classMethods.sorted() : cls.classMethods
        for method in classMethods {
            visitor.visitClassMethod(method)
        }

        let instanceMethods = sortMethods ? cls.instanceMethods.sorted() : cls.instanceMethods
        for method in instanceMethods {
            visitor.visitInstanceMethod(method, propertyState: propertyState)
        }

        visitor.visitRemainingProperties(propertyState)
        visitor.didVisitClass(cls)
    }

    private func visitCategory(_ category: ObjCCategory, with visitor: ClassDumpVisitor) {
        visitor.willVisitCategory(category)

        // Properties
        visitor.willVisitPropertiesOfCategory(category)
        for property in category.properties {
            visitor.visitProperty(property)
        }
        visitor.didVisitPropertiesOfCategory(category)

        let propertyState = VisitorPropertyState(properties: category.properties)

        // Class methods
        let classMethods = sortMethods ? category.classMethods.sorted() : category.classMethods
        for method in classMethods {
            visitor.visitClassMethod(method)
        }

        let instanceMethods = sortMethods ? category.instanceMethods.sorted() : category.instanceMethods
        for method in instanceMethods {
            visitor.visitInstanceMethod(method, propertyState: propertyState)
        }

        visitor.visitRemainingProperties(propertyState)
        visitor.didVisitCategory(category)
    }
}

// MARK: - Supporting Types

enum ClassDumpError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case invalidArch(String)
    case processingFailed(String, Error)

    var description: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidArch(let arch):
            return "Invalid architecture: \(arch)"
        case .processingFailed(let path, let error):
            return "Failed to process \(path): \(error)"
        }
    }
}
