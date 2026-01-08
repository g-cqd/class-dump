import Foundation

/// A visitor that generates separate header files for each class, category, and protocol.
///
/// This visitor writes individual `.h` files to an output directory, with proper
/// import statements based on framework mappings.
public final class MultiFileVisitor: TextClassDumpVisitor, @unchecked Sendable {
    /// Output directory path
    public var outputPath: String?

    /// Header string to prepend to each file
    public var headerString: String = ""

    /// Structure definitions for CDStructures.h
    public var structureDefinitions: String = ""

    /// Framework name mappings (class name -> framework name)
    public var frameworkNamesByClassName: [String: String] = [:]

    /// Framework name mappings (protocol name -> framework name)
    public var frameworkNamesByProtocolName: [String: String] = [:]

    /// Location to insert reference imports
    private var referenceLocation: Int = 0

    /// Referenced class names
    private var referencedClassNames: Set<String> = []

    /// Referenced protocol names (need import)
    private var referencedProtocolNames: Set<String> = []

    /// Weakly referenced protocol names (can use forward declaration)
    private var weaklyReferencedProtocolNames: Set<String> = []

    public override init(options: ClassDumpVisitorOptions = .init()) {
        super.init(options: options)

        // Wire up reference tracking
        onClassNameReferenced = { [weak self] name in
            self?.addReferenceToClassName(name)
        }
        onProtocolNamesReferenced = { [weak self] names in
            self?.addWeakReferencesToProtocolNames(names)
        }
    }

    // MARK: - Lifecycle

    public override func willBeginVisiting() {
        super.willBeginVisiting()

        append(headerString)
        createOutputPathIfNecessary()
        generateStructureHeader()
    }

    // MARK: - Class Visits

    public override func willVisitClass(_ objcClass: ObjCClass) {
        // Set up context
        clearResult()
        append(headerString)
        removeAllReferences()

        // Add superclass import
        if let superName = objcClass.superclassName,
            let importStr = importString(forClassName: superName)
        {
            append(importStr)
            appendNewline()
        }

        referenceLocation = resultString.count

        // Generate regular output
        super.willVisitClass(objcClass)

        addReferencesToProtocolNames(objcClass.protocols)
    }

    public override func didVisitClass(_ objcClass: ObjCClass) {
        super.didVisitClass(objcClass)

        // Remove self references
        removeReferenceToClassName(objcClass.name)
        if let superName = objcClass.superclassName {
            removeReferenceToClassName(superName)
        }

        // Insert reference imports
        insertReferenceString()

        // Write file
        let filename = "\(objcClass.name).h"
        writeResultToFile(named: filename)
    }

    // MARK: - Category Visits

    public override func willVisitCategory(_ category: ObjCCategory) {
        clearResult()
        append(headerString)
        removeAllReferences()

        if let importStr = importString(forClassName: category.classNameForVisitor) {
            append(importStr)
            appendNewline()
        }

        referenceLocation = resultString.count

        super.willVisitCategory(category)

        addReferencesToProtocolNames(category.protocols)
    }

    public override func didVisitCategory(_ category: ObjCCategory) {
        super.didVisitCategory(category)

        removeReferenceToClassName(category.classNameForVisitor)
        insertReferenceString()

        let filename = "\(category.classNameForVisitor)-\(category.name).h"
        writeResultToFile(named: filename)
    }

    // MARK: - Protocol Visits

    public override func willVisitProtocol(_ proto: ObjCProtocol) {
        clearResult()
        append(headerString)
        removeAllReferences()

        referenceLocation = resultString.count

        super.willVisitProtocol(proto)

        addReferencesToProtocolNames(proto.protocols)
    }

    public override func didVisitProtocol(_ proto: ObjCProtocol) {
        super.didVisitProtocol(proto)

        insertReferenceString()

        let filename = "\(proto.name)-Protocol.h"
        writeResultToFile(named: filename)
    }

    // MARK: - Reference Tracking

    private func addReferenceToClassName(_ name: String) {
        referencedClassNames.insert(name)
    }

    private func removeReferenceToClassName(_ name: String) {
        referencedClassNames.remove(name)
    }

    private func addReferencesToProtocolNames(_ names: [String]) {
        for name in names {
            referencedProtocolNames.insert(name)
        }
    }

    private func addWeakReferencesToProtocolNames(_ names: [String]) {
        for name in names {
            weaklyReferencedProtocolNames.insert(name)
        }
    }

    private func removeAllReferences() {
        referencedClassNames.removeAll()
        referencedProtocolNames.removeAll()
        weaklyReferencedProtocolNames.removeAll()
    }

    // MARK: - Import Generation

    private func framework(forClassName name: String) -> String? {
        var framework = frameworkNamesByClassName[name]

        // Map public CoreFoundation classes to Foundation
        if framework == "CoreFoundation" && name.hasPrefix("NS") {
            framework = "Foundation"
        }

        return framework
    }

    private func framework(forProtocolName name: String) -> String? {
        frameworkNamesByProtocolName[name]
    }

    private func importString(forClassName name: String) -> String? {
        if let framework = framework(forClassName: name) {
            return "#import <\(framework)/\(name).h>\n"
        } else {
            return "#import \"\(name).h\"\n"
        }
    }

    private func importString(forProtocolName name: String) -> String? {
        let headerName = "\(name)-Protocol.h"
        if let framework = framework(forProtocolName: name) {
            return "#import <\(framework)/\(headerName)>\n"
        } else {
            return "#import \"\(headerName)\"\n"
        }
    }

    private func generateReferenceString() -> String? {
        var referenceString = ""

        // Protocol imports
        if !referencedProtocolNames.isEmpty {
            for name in referencedProtocolNames.sorted() {
                if let importStr = importString(forProtocolName: name) {
                    referenceString.append(importStr)
                }
            }
            referenceString.append("\n")
        }

        // Class forward declarations
        var needsNewline = false
        if !referencedClassNames.isEmpty {
            let names = referencedClassNames.sorted().joined(separator: ", ")
            referenceString.append("@class \(names);\n")
            needsNewline = true
        }

        // Protocol forward declarations
        if !weaklyReferencedProtocolNames.isEmpty {
            let names = weaklyReferencedProtocolNames.sorted().joined(separator: ", ")
            referenceString.append("@protocol \(names);\n")
            needsNewline = true
        }

        if needsNewline {
            referenceString.append("\n")
        }

        return referenceString.isEmpty ? nil : referenceString
    }

    private func insertReferenceString() {
        if let refStr = generateReferenceString() {
            let index = resultString.index(resultString.startIndex, offsetBy: referenceLocation)
            resultString.insert(contentsOf: refStr, at: index)
        }
    }

    // MARK: - File Operations

    private func createOutputPathIfNecessary() {
        guard let path = outputPath else { return }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if !fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch {
                print("Error: Couldn't create output directory: \(path)")
                print("Error: \(error)")
            }
        } else if !isDirectory.boolValue {
            print("Error: File exists at output path: \(path)")
        }
    }

    private func writeResultToFile(named filename: String) {
        var fullPath = filename
        if let outputPath = outputPath {
            fullPath = (outputPath as NSString).appendingPathComponent(filename)
        }

        if let data = resultString.data(using: .utf8) {
            do {
                try data.write(to: URL(fileURLWithPath: fullPath), options: .atomic)
            } catch {
                print("Error writing file \(fullPath): \(error)")
            }
        }
    }

    private func generateStructureHeader() {
        guard !structureDefinitions.isEmpty else { return }

        clearResult()
        append(headerString)
        removeAllReferences()

        referenceLocation = resultString.count

        append(structureDefinitions)

        insertReferenceString()

        writeResultToFile(named: "CDStructures.h")
    }
}
