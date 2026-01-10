import ArgumentParser
import ClassDumpCore
import Foundation

@main
struct ClassDumpCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "class-dump",
        abstract: "Generates Objective-C header files from Mach-O binaries.",
        version: "4.0.3 (Swift)",
        subcommands: [DumpCommand.self, InfoCommand.self, DSCCommand.self, AddressCommand.self],
        defaultSubcommand: DumpCommand.self
    )
}

// MARK: - Dump Command (Default)

struct DumpCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dump",
        abstract: "Dump Objective-C headers from a Mach-O binary (default command)"
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

    @Flag(name: .long, help: "Show raw type encodings in comments (useful for debugging)")
    var showRawTypes: Bool = false

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

    @Flag(name: .long, help: "Use system swift-demangle for complex symbols (requires Xcode)")
    var systemDemangle: Bool = false

    @Flag(name: .long, help: "Use dynamic library demangling for complex symbols (faster, in-process)")
    var dynamicDemangle: Bool = false

    // MARK: - Method Style Options

    @Option(name: .long, help: "Method declaration style: objc (default) or swift")
    var methodStyle: String?

    // MARK: - Output Style Options

    @Option(
        name: .long,
        help: "Output type style: objc (default) converts Swift types to ObjC, swift preserves Swift syntax"
    )
    var outputStyle: String?

    // MARK: - Output Format Options

    @Option(
        name: .long,
        help:
            "Output format: objc (default), swift (.swiftinterface-style), json (machine-readable), mixed (both ObjC and Swift)"
    )
    var format: String?

    mutating func run() async throws {
        // Enable dynamic demangling if requested (faster, in-process)
        if dynamicDemangle {
            let available = SwiftDemangler.enableDynamicDemangling()
            if !available {
                if let warningData = "Warning: --dynamic-demangle requested but Swift runtime not found\n"
                    .data(using: .utf8)
                {
                    FileHandle.standardError.write(warningData)
                }
            }
        }

        // Enable system demangling if requested (and dynamic not already enabled)
        if systemDemangle && !SwiftDemangler.isDynamicDemanglingEnabled {
            let available = await SwiftDemangler.enableSystemDemangling()
            if !available {
                if let warningData = "Warning: --system-demangle requested but swift-demangle not found\n"
                    .data(using: .utf8)
                {
                    FileHandle.standardError.write(warningData)
                }
            }
        }

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
        }
        else {
            machOFile = try binary.bestMatchForLocal()
        }

        // Build SDK root if specified (reserved for future recursive framework loading)
        _ = resolveSDKRoot()

        // Process ObjC metadata using parallel loading for better performance
        let processor = ObjC2Processor(machOFile: machOFile)

        let metadata: ObjCMetadata
        do {
            metadata = try await processor.processAsync()
        }
        catch {
            throw ClassDumpError.processingFailed(file, error)
        }

        // Determine demangle style
        let resolvedDemangleStyle: DemangleStyle
        if !demangle {
            resolvedDemangleStyle = .none
        }
        else if let style = demangleStyle?.lowercased() {
            switch style {
                case "swift":
                    resolvedDemangleStyle = .swift
                case "objc":
                    resolvedDemangleStyle = .objc
                default:
                    resolvedDemangleStyle = .swift
            }
        }
        else {
            resolvedDemangleStyle = .swift
        }

        // Determine method style
        let resolvedMethodStyle: MethodStyle
        if let style = methodStyle?.lowercased() {
            switch style {
                case "swift":
                    resolvedMethodStyle = .swift
                case "objc":
                    resolvedMethodStyle = .objc
                default:
                    resolvedMethodStyle = .objc
            }
        }
        else {
            resolvedMethodStyle = .objc
        }

        // Determine output style
        let resolvedOutputStyle: OutputStyle
        if let style = outputStyle?.lowercased() {
            switch style {
                case "swift":
                    resolvedOutputStyle = .swift
                case "objc":
                    resolvedOutputStyle = .objc
                default:
                    resolvedOutputStyle = .objc
            }
        }
        else {
            resolvedOutputStyle = .objc
        }

        // Build visitor options
        let visitorOptions = ClassDumpVisitorOptions(
            shouldShowStructureSection: !hide.contains("structures") && !hide.contains("all"),
            shouldShowProtocolSection: !hide.contains("protocols") && !hide.contains("all"),
            shouldShowIvarOffsets: showIvarOffsets,
            shouldShowMethodAddresses: showImpAddr,
            shouldShowRawTypes: showRawTypes,
            demangleStyle: resolvedDemangleStyle,
            methodStyle: resolvedMethodStyle,
            outputStyle: resolvedOutputStyle
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
                || !metadata.categories.isEmpty,
            structureRegistry: metadata.structureRegistry,
            methodSignatureRegistry: metadata.methodSignatureRegistry
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
            // Generate structure definitions from registry for CDStructures.h
            if visitorOptions.shouldShowStructureSection {
                multiVisitor.structureDefinitions = await metadata.structureRegistry.generateStructureDefinitions()
            }

            // Populate internal class/protocol names from metadata
            // This allows proper @class/@protocol handling (local import vs forward declaration)
            multiVisitor.internalClassNames = Set(metadata.classes.map { $0.name })
            multiVisitor.internalProtocolNames = Set(metadata.protocols.map { $0.name })

            visitMetadata(metadata, processorInfo: processorInfo, with: multiVisitor)
            return
        }

        // Determine output format
        let formatLower = format?.lowercased()

        // JSON format output
        if formatLower == "json" {
            let jsonVisitor = JSONOutputVisitor(options: visitorOptions)
            visitMetadata(metadata, processorInfo: processorInfo, with: jsonVisitor)
            // Output is written in didEndVisiting()
            return
        }

        // Swift format output
        if formatLower == "swift" {
            let swiftVisitor = SwiftOutputVisitor(options: visitorOptions)
            if !suppressHeader {
                swiftVisitor.headerString = generateHeaderString()
            }
            visitMetadata(metadata, processorInfo: processorInfo, with: swiftVisitor)
            // Output is written in didEndVisiting()
            return
        }

        // Mixed format output (both ObjC and Swift)
        if formatLower == "mixed" {
            let mixedVisitor = MixedOutputVisitor(options: visitorOptions)
            if !suppressHeader {
                mixedVisitor.headerString = generateHeaderString()
            }
            visitMetadata(metadata, processorInfo: processorInfo, with: mixedVisitor)
            // Output is written in didEndVisiting()
            return
        }

        // Standard ObjC output
        let visitor: ClassDumpVisitor
        if suppressHeader {
            visitor = TextClassDumpVisitor(options: visitorOptions)
        }
        else {
            let headerVisitor = ClassDumpHeaderVisitor(options: visitorOptions)
            headerVisitor.headerString = generateHeaderString()
            // Generate structure definitions from registry
            if visitorOptions.shouldShowStructureSection {
                headerVisitor.structureDefinitions = await metadata.structureRegistry.generateStructureDefinitions()
            }
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
            }
            else if FileManager.default.fileExists(atPath: "/Developer") {
                return "/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS\(version).sdk"
            }
        }

        if let version = sdkMac {
            if FileManager.default.fileExists(atPath: "/Applications/Xcode.app") {
                return
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX\(version).sdk"
            }
            else if FileManager.default.fileExists(atPath: "/Developer") {
                return "/Developer/SDKs/MacOSX\(version).sdk"
            }
        }

        return nil
    }

    private func generateHeaderString() -> String {
        ClassDumpHeaderVisitor.generateHeader(generatedBy: "class-dump", version: "4.0.3 (Swift)")
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
        }
        else if sort {
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
        _ metadata: ObjCMetadata,
        processorInfo: ObjCProcessorInfo,
        with visitor: ClassDumpVisitor
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

            for proto in protocols where shouldShow(name: proto.name) {
                visitProtocol(proto, with: visitor)
            }
        }

        // Visit classes
        let classes = sortClasses(metadata.classes)
        for cls in classes where shouldShow(name: cls.name) {
            visitClass(cls, with: visitor)
        }

        // Visit categories
        let categories =
            sort || sortByInheritance
            ? metadata.categories.sorted { $0.name < $1.name }
            : metadata.categories

        for category in categories where shouldShow(name: category.name) {
            visitCategory(category, with: visitor)
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

// MARK: - Info Command (T22)

struct InfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Display detailed information about a Mach-O binary"
    )

    @Argument(help: "The Mach-O file to inspect")
    var file: String

    @Option(name: .long, help: "Select a specific architecture from a universal binary")
    var arch: String?

    @Flag(name: .long, help: "Show all load commands")
    var loadCommands: Bool = false

    @Flag(name: .long, help: "Show all sections")
    var sections: Bool = false

    @Flag(name: .long, help: "Show segment details")
    var segments: Bool = false

    @Flag(name: .long, help: "Show encryption info")
    var encryption: Bool = false

    @Flag(name: .long, help: "Show linked libraries")
    var libraries: Bool = false

    @Flag(name: .long, help: "Show all available information")
    var all: Bool = false

    @Option(name: .long, help: "Output format: text (default) or json")
    var format: String?

    mutating func run() async throws {
        let url = URL(fileURLWithPath: file)
        guard FileManager.default.fileExists(atPath: file) else {
            throw ClassDumpError.fileNotFound(file)
        }

        let binary = try MachOBinary(contentsOf: url)

        // Select architecture
        let machOFile: MachOFile
        if let archName = arch {
            guard let requestedArch = Arch(name: archName) else {
                throw ClassDumpError.invalidArch(archName)
            }
            machOFile = try binary.machOFile(for: requestedArch)
        }
        else {
            machOFile = try binary.bestMatchForLocal()
        }

        let isJSON = format?.lowercased() == "json"

        if isJSON {
            printJSONInfo(binary: binary, machOFile: machOFile)
        }
        else {
            printTextInfo(binary: binary, machOFile: machOFile)
        }
    }

    private func printTextInfo(binary: MachOBinary, machOFile: MachOFile) {
        let header = machOFile.header

        print("Mach-O Binary Information")
        print("=".repeated(60))
        print()

        // Basic info
        print("File: \(file)")
        print("Format: \(binary.isFat ? "Universal (Fat)" : "Single Architecture")")
        if binary.isFat {
            print("Architectures: \(binary.archNames.joined(separator: ", "))")
        }
        print()

        // Selected architecture details
        print("Selected Architecture: \(machOFile.arch.name)")
        print("-".repeated(40))
        print("  CPU Type: \(cpuTypeName(UInt32(bitPattern: header.cputype)))")
        print("  CPU Subtype: 0x\(String(header.cpusubtype, radix: 16))")
        print("  File Type: \(fileTypeName(header.filetype))")
        print("  Flags: \(formatFlags(header.flags))")
        print("  64-bit: \(machOFile.uses64BitABI)")
        print("  Byte Order: \(machOFile.byteOrder)")
        print()

        // Platform info
        for cmd in machOFile.loadCommands {
            if case .buildVersion(let buildVersion) = cmd {
                print("Platform Information:")
                print("-".repeated(40))
                print("  Platform: \(platformName(buildVersion.platformRaw))")
                print("  Min OS: \(buildVersion.minos)")
                print("  SDK: \(buildVersion.sdk)")
                print()
                break
            }
        }

        // Segments (if requested or --all)
        if segments || all {
            print("Segments:")
            print("-".repeated(40))
            for segment in machOFile.segments {
                print("  \(segment.name)")
                print("    VM Address: 0x\(String(segment.vmaddr, radix: 16))")
                print("    VM Size: \(formatSize(segment.vmsize))")
                print("    File Offset: 0x\(String(segment.fileoff, radix: 16))")
                print("    File Size: \(formatSize(segment.filesize))")
                print("    Protection: \(formatProtection(segment.initprot))")
            }
            print()
        }

        // Sections (if requested or --all)
        if sections || all {
            print("Sections:")
            print("-".repeated(40))
            for segment in machOFile.segments {
                for section in segment.sections {
                    print("  \(segment.name),\(section.sectionName)")
                    print("    Address: 0x\(String(section.addr, radix: 16))")
                    print("    Size: \(formatSize(section.size))")
                    print("    Offset: 0x\(String(section.offset, radix: 16))")
                }
            }
            print()
        }

        // Libraries (if requested or --all)
        if libraries || all {
            var dylibs: [DylibCommand] = []
            for cmd in machOFile.loadCommands {
                if case .dylib(let dylib) = cmd {
                    dylibs.append(dylib)
                }
            }
            if !dylibs.isEmpty {
                print("Linked Libraries:")
                print("-".repeated(40))
                for dylib in dylibs {
                    print("  \(dylib.name)")
                    print("    Version: \(dylib.currentVersion)")
                }
                print()
            }
        }

        // Encryption (if requested or --all)
        if encryption || all {
            for cmd in machOFile.loadCommands {
                if case .encryptionInfo(let encInfo) = cmd {
                    print("Encryption:")
                    print("-".repeated(40))
                    print("  Encrypted: \(encInfo.cryptid != 0 ? "Yes" : "No")")
                    print("  Crypt Offset: 0x\(String(encInfo.cryptoff, radix: 16))")
                    print("  Crypt Size: \(formatSize(UInt64(encInfo.cryptsize)))")
                    print()
                    break
                }
            }
        }

        // Load commands (if requested or --all)
        if loadCommands || all {
            print("Load Commands (\(machOFile.loadCommands.count)):")
            print("-".repeated(40))
            for (index, cmd) in machOFile.loadCommands.enumerated() {
                print("  [\(index)] \(loadCommandName(cmd))")
            }
            print()
        }

        // ObjC info
        let hasObjC =
            machOFile.segments.contains { seg in
                seg.sections.contains { $0.sectionName.contains("objc") }
            }
        let hasSwift =
            machOFile.segments.contains { seg in
                seg.sections.contains { $0.sectionName.contains("swift") }
            }

        print("Runtime Information:")
        print("-".repeated(40))
        print("  Has Objective-C: \(hasObjC)")
        print("  Has Swift: \(hasSwift)")
    }

    private func printJSONInfo(binary: MachOBinary, machOFile: MachOFile) {
        var info: [String: Any] = [:]

        info["file"] = file
        info["format"] = binary.isFat ? "universal" : "single"
        info["architectures"] = binary.archNames

        var archInfo: [String: Any] = [:]
        archInfo["name"] = machOFile.arch.name
        archInfo["cpuType"] = machOFile.header.cputype
        archInfo["cpuSubtype"] = machOFile.header.cpusubtype
        archInfo["fileType"] = fileTypeName(machOFile.header.filetype)
        archInfo["is64Bit"] = machOFile.uses64BitABI

        var segmentList: [[String: Any]] = []
        for segment in machOFile.segments {
            var segInfo: [String: Any] = [:]
            segInfo["name"] = segment.name
            segInfo["vmAddress"] = String(format: "0x%llx", segment.vmaddr)
            segInfo["vmSize"] = segment.vmsize
            segInfo["fileOffset"] = segment.fileoff
            segInfo["fileSize"] = segment.filesize

            var sectionList: [[String: Any]] = []
            for section in segment.sections {
                var sectInfo: [String: Any] = [:]
                sectInfo["name"] = section.sectionName
                sectInfo["address"] = String(format: "0x%llx", section.addr)
                sectInfo["size"] = section.size
                sectionList.append(sectInfo)
            }
            segInfo["sections"] = sectionList
            segmentList.append(segInfo)
        }
        archInfo["segments"] = segmentList

        info["selectedArchitecture"] = archInfo

        if let jsonData = try? JSONSerialization.data(withJSONObject: info, options: .prettyPrinted),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            print(jsonString)
        }
    }

    // MARK: - Formatting Helpers

    private func cpuTypeName(_ type: UInt32) -> String {
        switch type {
            case 7: return "x86"
            case 0x0100_0007: return "x86_64"
            case 12: return "ARM"
            case 0x0100_000C: return "ARM64"
            default: return "Unknown (\(type))"
        }
    }

    private func fileTypeName(_ type: UInt32) -> String {
        switch type {
            case 1: return "Object"
            case 2: return "Executable"
            case 3: return "Fixed VM Library"
            case 4: return "Core"
            case 5: return "Preload"
            case 6: return "Dynamic Library"
            case 7: return "Dynamic Linker"
            case 8: return "Bundle"
            case 9: return "Dynamic Library Stub"
            case 10: return "Debug Symbols"
            case 11: return "Kext Bundle"
            default: return "Unknown (\(type))"
        }
    }

    private func platformName(_ platform: UInt32) -> String {
        switch platform {
            case 1: return "macOS"
            case 2: return "iOS"
            case 3: return "tvOS"
            case 4: return "watchOS"
            case 5: return "bridgeOS"
            case 6: return "Mac Catalyst"
            case 7: return "iOS Simulator"
            case 8: return "tvOS Simulator"
            case 9: return "watchOS Simulator"
            case 10: return "DriverKit"
            case 11: return "visionOS"
            case 12: return "visionOS Simulator"
            default: return "Unknown (\(platform))"
        }
    }

    private func formatVersion(_ version: UInt32) -> String {
        let major = (version >> 16) & 0xFFFF
        let minor = (version >> 8) & 0xFF
        let patch = version & 0xFF
        return "\(major).\(minor).\(patch)"
    }

    private func formatSize(_ size: UInt64) -> String {
        if size >= 1024 * 1024 * 1024 {
            return String(format: "%.2f GB", Double(size) / (1024 * 1024 * 1024))
        }
        else if size >= 1024 * 1024 {
            return String(format: "%.2f MB", Double(size) / (1024 * 1024))
        }
        else if size >= 1024 {
            return String(format: "%.2f KB", Double(size) / 1024)
        }
        return "\(size) bytes"
    }

    private func formatProtection(_ prot: Int32) -> String {
        var perms = ""
        if prot & 1 != 0 {
            perms += "r"
        }
        else {
            perms += "-"
        }
        if prot & 2 != 0 {
            perms += "w"
        }
        else {
            perms += "-"
        }
        if prot & 4 != 0 {
            perms += "x"
        }
        else {
            perms += "-"
        }
        return perms
    }

    private func formatFlags(_ flags: UInt32) -> String {
        var flagNames: [String] = []
        if flags & 0x1 != 0 { flagNames.append("NOUNDEFS") }
        if flags & 0x2 != 0 { flagNames.append("INCRLINK") }
        if flags & 0x4 != 0 { flagNames.append("DYLDLINK") }
        if flags & 0x8 != 0 { flagNames.append("BINDATLOAD") }
        if flags & 0x10 != 0 { flagNames.append("PREBOUND") }
        if flags & 0x20 != 0 { flagNames.append("SPLIT_SEGS") }
        if flags & 0x80 != 0 { flagNames.append("TWOLEVEL") }
        if flags & 0x200000 != 0 { flagNames.append("PIE") }
        return flagNames.isEmpty ? "none" : flagNames.joined(separator: " | ")
    }

    private func loadCommandName(_ cmd: LoadCommand) -> String {
        switch cmd {
            case .segment(let c): return "Segment (\(c.name))"
            case .symtab: return "Symtab"
            case .dysymtab: return "Dysymtab"
            case .dylib(let c): return "Dylib (\(c.dylibType))"
            case .dylinker: return "Dylinker"
            case .uuid: return "UUID"
            case .version: return "Version"
            case .buildVersion: return "BuildVersion"
            case .main: return "Main"
            case .sourceVersion: return "SourceVersion"
            case .encryptionInfo: return "EncryptionInfo"
            case .linkeditData: return "LinkeditData"
            case .rpath: return "Rpath"
            case .dyldInfo: return "DyldInfo"
            case .unknown(let c): return "Unknown (0x\(String(c.cmd, radix: 16)))"
        }
    }
}

// MARK: - DSC Command

struct DSCCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dsc",
        abstract: "Dump headers from dyld_shared_cache"
    )

    @Argument(help: "Framework name to dump (e.g., Foundation, UIKit)")
    var framework: String

    @Option(name: .long, help: "Path to dyld_shared_cache (default: system cache)")
    var cache: String?

    @Flag(name: .long, help: "List all frameworks in the cache")
    var list: Bool = false

    @Flag(name: .long, help: "List only public frameworks")
    var listPublic: Bool = false

    @Flag(name: .long, help: "List only private frameworks")
    var listPrivate: Bool = false

    @Option(name: .customShort("C"), help: "Only display classes matching regular expression")
    var match: String?

    @Flag(name: .customShort("s"), help: "Sort classes and categories by name")
    var sort: Bool = false

    @Flag(name: .customShort("H"), help: "Generate header files in current directory, or directory specified with -o")
    var generateHeaders: Bool = false

    @Option(name: .customShort("o"), help: "Output directory used for -H")
    var outputDir: String?

    @Option(name: .long, help: "Output format: objc (default), json")
    var format: String?

    mutating func run() async throws {
        // Find cache path
        let cachePath: String
        if let path = cache {
            cachePath = path
        }
        else if let systemPath = DyldSharedCache.systemCachePath() {
            cachePath = systemPath
        }
        else {
            throw DSCError.cacheNotFound
        }

        // Open cache
        let dsc = try DyldSharedCache(path: cachePath)

        // Handle list modes
        if list || listPublic || listPrivate {
            printFrameworkList(dsc)
            return
        }

        // Find the requested framework
        guard let image = dsc.image(named: framework) else {
            throw DSCError.frameworkNotFound(framework)
        }

        // Process ObjC metadata
        let processor = try DyldCacheObjCProcessor(cache: dsc, image: image)
        let metadata = try await processor.process()

        // Output
        let isJSON = format?.lowercased() == "json"

        if isJSON {
            printJSONMetadata(metadata, framework: framework)
        }
        else if generateHeaders {
            try generateHeaderFiles(metadata, framework: framework)
        }
        else {
            printTextMetadata(metadata, framework: framework, image: image)
        }
    }

    private func printFrameworkList(_ cache: DyldSharedCache) {
        let images: [DyldCacheImageInfo]

        if listPublic {
            images = cache.images.publicFrameworks
            print("Public Frameworks in \(cache.path):")
        }
        else if listPrivate {
            images = cache.images.privateFrameworks
            print("Private Frameworks in \(cache.path):")
        }
        else {
            images = cache.images
            print("All Images in \(cache.path):")
        }

        print("=".repeated(60))
        print("Total: \(images.count)")
        print()

        let sortedImages = images.sorted { ($0.frameworkName ?? $0.name) < ($1.frameworkName ?? $1.name) }

        for image in sortedImages {
            if let name = image.frameworkName {
                print("  \(name)")
            }
            else {
                print("  \(image.name)")
            }
        }
    }

    private func printTextMetadata(_ metadata: ObjCMetadata, framework: String, image: DyldCacheImageInfo) {
        print("/*")
        print(" * Framework: \(framework)")
        print(" * Path: \(image.path)")
        print(" * Classes: \(metadata.classes.count)")
        print(" * Protocols: \(metadata.protocols.count)")
        print(" * Categories: \(metadata.categories.count)")
        print(" */")
        print()

        // Build simple text output
        let visitorOptions = ClassDumpVisitorOptions(
            shouldShowStructureSection: true,
            shouldShowProtocolSection: true,
            shouldShowIvarOffsets: false,
            shouldShowMethodAddresses: false,
            shouldShowRawTypes: false,
            demangleStyle: .swift,
            methodStyle: .objc,
            outputStyle: .objc
        )

        let visitor = TextClassDumpVisitor(options: visitorOptions)

        visitor.willBeginVisiting()

        // Protocols
        let protocols = sort ? metadata.protocols.sorted { $0.name < $1.name } : metadata.protocols
        for proto in protocols where shouldShow(name: proto.name) {
            printProtocol(proto, visitor: visitor)
        }

        // Classes
        let classes = sort ? metadata.classes.sorted { $0.name < $1.name } : metadata.classes
        for cls in classes where shouldShow(name: cls.name) {
            printClass(cls, visitor: visitor)
        }

        // Categories
        let categories = sort ? metadata.categories.sorted { $0.name < $1.name } : metadata.categories
        for category in categories where shouldShow(name: category.name) {
            printCategory(category, visitor: visitor)
        }

        visitor.didEndVisiting()

        print(visitor.resultString)
    }

    private func printProtocol(_ proto: ObjCProtocol, visitor: TextClassDumpVisitor) {
        visitor.willVisitProtocol(proto)
        let propertyState = VisitorPropertyState(properties: proto.properties)
        for method in proto.classMethods {
            visitor.visitClassMethod(method)
        }
        for method in proto.instanceMethods {
            visitor.visitInstanceMethod(method, propertyState: propertyState)
        }
        visitor.didVisitProtocol(proto)
    }

    private func printClass(_ cls: ObjCClass, visitor: TextClassDumpVisitor) {
        visitor.willVisitClass(cls)
        if !cls.instanceVariables.isEmpty {
            visitor.willVisitIvarsOfClass(cls)
            for ivar in cls.instanceVariables {
                visitor.visitIvar(ivar)
            }
            visitor.didVisitIvarsOfClass(cls)
        }
        let propertyState = VisitorPropertyState(properties: cls.properties)
        for property in cls.properties {
            visitor.visitProperty(property)
        }
        for method in cls.classMethods {
            visitor.visitClassMethod(method)
        }
        for method in cls.instanceMethods {
            visitor.visitInstanceMethod(method, propertyState: propertyState)
        }
        visitor.didVisitClass(cls)
    }

    private func printCategory(_ category: ObjCCategory, visitor: TextClassDumpVisitor) {
        visitor.willVisitCategory(category)
        let propertyState = VisitorPropertyState(properties: category.properties)
        for property in category.properties {
            visitor.visitProperty(property)
        }
        for method in category.classMethods {
            visitor.visitClassMethod(method)
        }
        for method in category.instanceMethods {
            visitor.visitInstanceMethod(method, propertyState: propertyState)
        }
        visitor.didVisitCategory(category)
    }

    private func printJSONMetadata(_ metadata: ObjCMetadata, framework: String) {
        var output: [String: Any] = [:]
        output["framework"] = framework

        output["classes"] = metadata.classes.map { cls -> [String: Any] in
            var info: [String: Any] = ["name": cls.name]
            if let superclass = cls.superclassName {
                info["superclass"] = superclass
            }
            info["methods"] = cls.instanceMethods.map { $0.name } + cls.classMethods.map { "+" + $0.name }
            info["properties"] = cls.properties.map { $0.name }
            return info
        }

        output["protocols"] = metadata.protocols.map { proto -> [String: Any] in
            var info: [String: Any] = ["name": proto.name]
            info["methods"] = proto.instanceMethods.map { $0.name } + proto.classMethods.map { "+" + $0.name }
            return info
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            print(jsonString)
        }
    }

    private func generateHeaderFiles(_ metadata: ObjCMetadata, framework: String) throws {
        let outputPath = outputDir ?? "."
        let fm = FileManager.default

        // Create output directory if needed
        try fm.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

        // Generate one header per class
        for cls in metadata.classes {
            let filename = "\(cls.name).h"
            let path = (outputPath as NSString).appendingPathComponent(filename)

            var content = "// Generated from \(framework)\n\n"
            content += "#import <Foundation/Foundation.h>\n\n"

            if let superclass = cls.superclassName {
                content += "@interface \(cls.name) : \(superclass)\n"
            }
            else {
                content += "@interface \(cls.name)\n"
            }

            for property in cls.properties {
                content += "@property \(property.name);\n"
            }

            for method in cls.instanceMethods {
                content += "- \(method.name);\n"
            }

            for method in cls.classMethods {
                content += "+ \(method.name);\n"
            }

            content += "@end\n"

            try content.write(toFile: path, atomically: true, encoding: .utf8)
        }

        print("Generated \(metadata.classes.count) header files in \(outputPath)")
    }

    private func shouldShow(name: String) -> Bool {
        guard let pattern = match else { return true }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return true
        }
        let range = NSRange(name.startIndex..., in: name)
        return regex.firstMatch(in: name, options: [], range: range) != nil
    }
}

// MARK: - Address Command (T23)

struct AddressCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "address",
        abstract: "Address translation utilities"
    )

    @Argument(help: "The Mach-O file")
    var file: String

    @Option(name: .long, help: "Select architecture")
    var arch: String?

    @Option(name: [.customLong("a2o"), .customShort("a")], help: "Convert virtual address to file offset")
    var addressToOffset: String?

    @Option(name: [.customLong("o2a"), .customShort("o")], help: "Convert file offset to virtual address")
    var offsetToAddress: String?

    @Option(name: .long, help: "Look up symbol at address")
    var symbol: String?

    @Flag(name: .long, help: "Show all section addresses")
    var showSections: Bool = false

    mutating func run() async throws {
        let url = URL(fileURLWithPath: file)
        guard FileManager.default.fileExists(atPath: file) else {
            throw ClassDumpError.fileNotFound(file)
        }

        let binary = try MachOBinary(contentsOf: url)

        // Select architecture
        let machOFile: MachOFile
        if let archName = arch {
            guard let requestedArch = Arch(name: archName) else {
                throw ClassDumpError.invalidArch(archName)
            }
            machOFile = try binary.machOFile(for: requestedArch)
        }
        else {
            machOFile = try binary.bestMatchForLocal()
        }

        // Build address translator
        let translator = AddressTranslator(segments: machOFile.segments)

        // Handle a2o
        if let addrStr = addressToOffset {
            let address = parseAddress(addrStr)
            if let offset = translator.fileOffset(for: address) {
                print("Virtual Address: 0x\(String(address, radix: 16))")
                print("File Offset:     0x\(String(offset, radix: 16)) (\(offset))")

                // Find which section contains this address
                for segment in machOFile.segments {
                    for section in segment.sections {
                        if address >= section.addr && address < section.addr + section.size {
                            print("Section:         \(segment.name),\(section.sectionName)")
                            break
                        }
                    }
                }
            }
            else {
                print("Address 0x\(String(address, radix: 16)) not found in any section")
            }
            return
        }

        // Handle o2a
        if let offsetStr = offsetToAddress {
            let offset = parseAddress(offsetStr)

            // Find section containing this offset
            for segment in machOFile.segments {
                for section in segment.sections {
                    let sectionEnd = UInt64(section.offset) + section.size
                    if offset >= section.offset && UInt64(offset) < sectionEnd {
                        let relativeOffset = UInt64(offset) - UInt64(section.offset)
                        let address = section.addr + relativeOffset
                        print("File Offset:     0x\(String(offset, radix: 16)) (\(offset))")
                        print("Virtual Address: 0x\(String(address, radix: 16))")
                        print("Section:         \(segment.name),\(section.sectionName)")
                        return
                    }
                }
            }
            print("Offset \(offset) not found in any section")
            return
        }

        // Show sections
        if showSections {
            print("Section Address Map:")
            print("=".repeated(70))
            print("Section              VM Address         File Offset        Size")
            print("-".repeated(70))

            for segment in machOFile.segments {
                for section in segment.sections {
                    let name = "\(segment.name),\(section.sectionName)"
                        .padding(toLength: 20, withPad: " ", startingAt: 0)
                    let vmAddr = String(format: "0x%016llx", section.addr)
                    let fileOff = String(format: "0x%08x", section.offset)
                    let size = formatSize(section.size)
                    print("\(name) \(vmAddr) \(fileOff)    \(size)")
                }
            }
            return
        }

        // Default: show usage hint
        print("Address Translation for: \(file)")
        print()
        print("Usage:")
        print("  class-dump address \(file) --a2o 0x100001234  # Address to offset")
        print("  class-dump address \(file) --o2a 0x1234       # Offset to address")
        print("  class-dump address \(file) --show-sections    # List all sections")
    }

    private func parseAddress(_ str: String) -> UInt64 {
        if str.hasPrefix("0x") || str.hasPrefix("0X") {
            return UInt64(str.dropFirst(2), radix: 16) ?? 0
        }
        return UInt64(str) ?? 0
    }

    private func formatSize(_ size: UInt64) -> String {
        if size >= 1024 * 1024 {
            return String(format: "%.1f MB", Double(size) / (1024 * 1024))
        }
        else if size >= 1024 {
            return String(format: "%.1f KB", Double(size) / 1024)
        }
        return "\(size) B"
    }
}

// MARK: - Errors

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

enum DSCError: Error, CustomStringConvertible {
    case cacheNotFound
    case frameworkNotFound(String)

    var description: String {
        switch self {
            case .cacheNotFound:
                return "dyld_shared_cache not found. Specify path with --cache"
            case .frameworkNotFound(let name):
                return "Framework '\(name)' not found in cache"
        }
    }
}

// MARK: - String Extension

extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}
