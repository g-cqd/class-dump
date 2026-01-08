import ArgumentParser
import ClassDumpCore
import Foundation

@main
struct ClassDumpCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "class-dump",
    abstract: "Generates Objective-C header files from Mach-O binaries.",
    version: "4.0.0 (Swift)"
  )

  @Argument(help: "The Mach-O file to process")
  var file: String

  @Option(name: .shortAndLong, help: "Select a specific architecture from a fat binary")
  var arch: String?

  @Flag(name: .long, help: "Sort classes and categories by name")
  var sort: Bool = false

  @Flag(name: .long, help: "Sort classes by inheritance")
  var sortByInheritance: Bool = false

  @Flag(name: .long, help: "Sort methods by name")
  var sortMethods: Bool = false

  @Option(name: .shortAndLong, help: "Only show classes/protocols matching this regex")
  var match: String?

  mutating func run() async throws {
    // Load the Mach-O file
    let url = URL(fileURLWithPath: file)
    guard FileManager.default.fileExists(atPath: file) else {
      throw ClassDumpError.fileNotFound(file)
    }

    let binary = try MachOBinary(contentsOf: url)
    let machOFile: MachOFile

    if let archName = arch {
      guard let requestedArch = Arch(name: archName) else {
        throw ClassDumpError.invalidArch(archName)
      }
      machOFile = try binary.machOFile(for: requestedArch)
    } else {
      machOFile = try binary.bestMatchForLocal()
    }

    // Process ObjC metadata
    let processor = ObjC2Processor(
      data: machOFile.data,
      segments: machOFile.segments,
      byteOrder: machOFile.byteOrder,
      is64Bit: machOFile.uses64BitABI
    )

    let metadata: ObjCMetadata
    do {
      metadata = try processor.process()
    } catch {
      throw ClassDumpError.processingFailed(file, error)
    }

    // Create visitor and generate output
    let visitor = TextClassDumpVisitor()

    // Build processor info
    let machOFileInfo = VisitorMachOFileInfo(
      filename: url.lastPathComponent,
      archName: machOFile.arch.name,
      filetype: machOFile.header.filetype
    )
    let processorInfo = ObjCProcessorInfo(
      machOFile: machOFileInfo,
      hasObjectiveCRuntimeInfo: !metadata.classes.isEmpty || !metadata.protocols.isEmpty || !metadata.categories.isEmpty
    )

    // Visit metadata
    visitMetadata(metadata, processorInfo: processorInfo, with: visitor)

    // Output result
    print(visitor.resultString)
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

  private func visitMetadata(_ metadata: ObjCMetadata, processorInfo: ObjCProcessorInfo, with visitor: ClassDumpVisitor) {
    visitor.willBeginVisiting()
    visitor.willVisitProcessor(processorInfo)
    visitor.visitProcessor(processorInfo)

    // Visit protocols
    let protocols = sort || sortByInheritance
      ? metadata.protocols.sorted { $0.name < $1.name }
      : metadata.protocols

    for proto in protocols {
      if shouldShow(name: proto.name) {
        visitProtocol(proto, with: visitor)
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
    let categories = sort || sortByInheritance
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
    let optionalInstanceMethods = sortMethods ? proto.optionalInstanceMethods.sorted() : proto.optionalInstanceMethods

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
