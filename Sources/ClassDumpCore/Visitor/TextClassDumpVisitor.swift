import Foundation

/// A visitor that generates text output of class dumps.
///
/// This visitor traverses the ObjC metadata tree and builds a string representation
/// of classes, protocols, categories, methods, properties, and ivars.
open class TextClassDumpVisitor: ClassDumpVisitor, @unchecked Sendable {
  /// The accumulated result string
  public var resultString: String = ""

  /// Visitor options
  public var options: ClassDumpVisitorOptions

  /// Type formatter for generating type strings
  public var typeFormatter: ObjCTypeFormatter

  /// Callback when a class name is referenced
  public var onClassNameReferenced: ((String) -> Void)?

  /// Callback when protocol names are referenced
  public var onProtocolNamesReferenced: (([String]) -> Void)?

  public init(options: ClassDumpVisitorOptions = .init()) {
    self.options = options
    self.typeFormatter = ObjCTypeFormatter()

    // Wire up type formatter callbacks
    typeFormatter.onClassNameReferenced = { [weak self] name in
      self?.onClassNameReferenced?(name)
    }
    typeFormatter.onProtocolNamesReferenced = { [weak self] names in
      self?.onProtocolNamesReferenced?(names)
    }
  }

  // MARK: - Lifecycle

  open func willBeginVisiting() {}

  open func didEndVisiting() {}

  // MARK: - Processor Visits

  open func willVisitProcessor(_ processor: ObjCProcessorInfo) {}

  open func visitProcessor(_ processor: ObjCProcessorInfo) {}

  open func didVisitProcessor(_ processor: ObjCProcessorInfo) {}

  // MARK: - Output Helpers

  /// Append text to the result string.
  public func append(_ text: String) {
    resultString.append(text)
  }

  /// Append a newline to the result string.
  public func appendNewline() {
    resultString.append("\n")
  }

  /// Clear the result string.
  public func clearResult() {
    resultString = ""
  }

  /// Write the result to standard output.
  public func writeResultToStandardOutput() {
    if let data = resultString.data(using: .utf8) {
      FileHandle.standardOutput.write(data)
    }
  }

  // MARK: - Class Visits

  open func willVisitClass(_ objcClass: ObjCClass) {
    if !objcClass.isExported {
      append("__attribute__((visibility(\"hidden\")))\n")
    }

    append("@interface \(objcClass.name)")
    if let superName = objcClass.superclassName {
      append(" : \(superName)")
    }

    if !objcClass.protocols.isEmpty {
      append(" <\(objcClass.protocols.joined(separator: ", "))>")
    }

    appendNewline()
  }

  open func didVisitClass(_ objcClass: ObjCClass) {
    if objcClass.hasMethods {
      appendNewline()
    }
    append("@end\n\n")
  }

  open func willVisitIvarsOfClass(_ objcClass: ObjCClass) {
    append("{\n")
  }

  open func didVisitIvarsOfClass(_ objcClass: ObjCClass) {
    append("}\n\n")
  }

  open func didVisitPropertiesOfClass(_ objcClass: ObjCClass) {
    if !objcClass.properties.isEmpty {
      appendNewline()
    }
  }

  // MARK: - Category Visits

  open func willVisitCategory(_ category: ObjCCategory) {
    append("@interface \(category.classNameForVisitor) (\(category.name))")

    if !category.protocols.isEmpty {
      append(" <\(category.protocols.joined(separator: ", "))>")
    }

    appendNewline()
  }

  open func didVisitCategory(_ category: ObjCCategory) {
    append("@end\n\n")
  }

  open func willVisitPropertiesOfCategory(_ category: ObjCCategory) {
    if !category.properties.isEmpty {
      appendNewline()
    }
  }

  open func didVisitPropertiesOfCategory(_ category: ObjCCategory) {
    if !category.properties.isEmpty {
      appendNewline()
    }
  }

  // MARK: - Protocol Visits

  open func willVisitProtocol(_ proto: ObjCProtocol) {
    append("@protocol \(proto.name)")

    if !proto.protocols.isEmpty {
      append(" <\(proto.protocols.joined(separator: ", "))>")
    }

    appendNewline()
  }

  open func didVisitProtocol(_ proto: ObjCProtocol) {
    append("@end\n\n")
  }

  open func willVisitOptionalMethods() {
    append("\n@optional\n")
  }

  open func willVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {
    if !proto.properties.isEmpty {
      appendNewline()
    }
  }

  open func didVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {
    if !proto.properties.isEmpty {
      appendNewline()
    }
  }

  // MARK: - Method Visits

  open func visitClassMethod(_ method: ObjCMethod) {
    append("+ ")
    appendMethod(method)
    appendNewline()
  }

  open func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState) {
    if propertyState.property(forAccessor: method.name) != nil {
      // This method is a property accessor - skip it since properties are output separately
      return
    }
    // Regular instance method
    append("- ")
    appendMethod(method)
    appendNewline()
  }

  open func visitIvar(_ ivar: ObjCInstanceVariable) {
    appendIvar(ivar)
    appendNewline()
  }

  open func visitProperty(_ property: ObjCProperty) {
    guard let parsedType = property.parsedType else {
      if property.attributeString.hasPrefix("T") {
        append("// Error parsing type for property \(property.name):\n")
        append("// Property attributes: \(property.attributeString)\n\n")
      } else {
        append("// Error: Property attributes should begin with the type ('T') attribute, property name: \(property.name)\n")
        append("// Property attributes: \(property.attributeString)\n\n")
      }
      return
    }

    appendProperty(property, parsedType: parsedType)
  }

  open func visitRemainingProperties(_ propertyState: VisitorPropertyState) {
    // Properties are now visited explicitly, so no remaining properties to handle
  }

  // MARK: - Formatting Helpers

  /// Append a formatted method declaration.
  open func appendMethod(_ method: ObjCMethod) {
    if let formatted = typeFormatter.formatMethodName(method.name, typeString: method.typeEncoding) {
      append(formatted)
      append(";")
    } else {
      // Fallback if formatting fails
      append("(\(method.typeEncoding))\(method.name);")
    }

    // Show implementation address if enabled
    if options.shouldShowMethodAddresses && method.address != 0 {
      append(String(format: " // IMP=0x%llx", method.address))
    }
  }

  /// Append a formatted ivar declaration.
  open func appendIvar(_ ivar: ObjCInstanceVariable) {
    if let parsedType = ivar.parsedType {
      let formatted = typeFormatter.formatVariable(name: ivar.name, type: parsedType)
      append("    \(formatted);")
    } else {
      append("    /* \(ivar.typeEncoding) */ \(ivar.name);")
    }

    // Show ivar offset if enabled
    if options.shouldShowIvarOffsets {
      append(" // +\(ivar.offset)")
    }
  }

  /// Append a formatted property declaration.
  open func appendProperty(_ property: ObjCProperty, parsedType: ObjCType) {
    var attributes: [String] = []
    var backingVar: String? = nil
    var isWeak = false
    var isDynamic = false
    var unknownAttrs: [String] = []

    for attr in property.attributeComponents {
      if attr.hasPrefix("T") {
        // Type attribute - handled separately
      } else if attr.hasPrefix("R") {
        attributes.append("readonly")
      } else if attr.hasPrefix("C") {
        attributes.append("copy")
      } else if attr.hasPrefix("&") {
        attributes.append("retain")
      } else if attr.hasPrefix("G") {
        attributes.append("getter=\(String(attr.dropFirst()))")
      } else if attr.hasPrefix("S") {
        attributes.append("setter=\(String(attr.dropFirst()))")
      } else if attr.hasPrefix("V") {
        backingVar = String(attr.dropFirst())
      } else if attr.hasPrefix("N") {
        attributes.append("nonatomic")
      } else if attr.hasPrefix("W") {
        isWeak = true
      } else if attr.hasPrefix("P") {
        isWeak = false
      } else if attr.hasPrefix("D") {
        isDynamic = true
      } else if attr == "?" {
        attributes.append("nullable")
      } else {
        unknownAttrs.append(attr)
      }
    }

    if !attributes.isEmpty {
      append("@property(\(attributes.joined(separator: ", "))) ")
    } else {
      append("@property ")
    }

    if isWeak {
      append("__weak ")
    }

    let formatted = typeFormatter.formatVariable(name: property.name, type: parsedType)
    append("\(formatted);")

    if isDynamic {
      append(" // @dynamic \(property.name);")
    } else if let backing = backingVar {
      if backing == property.name {
        append(" // @synthesize \(property.name);")
      } else {
        append(" // @synthesize \(property.name)=\(backing);")
      }
    }

    appendNewline()

    if !unknownAttrs.isEmpty {
      append("// Preceding property had unknown attributes: \(unknownAttrs.joined(separator: ","))\n")
      append("// Original attribute string: \(property.attributeString)\n\n")
    }
  }
}
