import Foundation

/// A visitor that searches for methods matching a search string.
///
/// This visitor filters output to only show methods containing the search string,
/// along with their containing context (class, category, or protocol).
public final class FindMethodVisitor: ClassDumpVisitor, @unchecked Sendable {
    /// The string to search for in method names
    public var searchString: String = ""

    /// The accumulated result string
    public private(set) var resultString: String = ""

    /// Header string to prepend to output
    public var headerString: String = ""

    /// Visitor options
    public var options: ClassDumpVisitorOptions

    /// Type formatter for method strings
    public var typeFormatter: ObjCTypeFormatter

    /// Current context (class, category, or protocol)
    private var context: MethodSearchContext?

    /// Whether we've shown the current context
    private var hasShownContext: Bool = false

    public init(options: ClassDumpVisitorOptions = .init()) {
        self.options = options
        self.typeFormatter = ObjCTypeFormatter()
    }

    // MARK: - Output Helpers

    private func append(_ text: String) {
        resultString.append(text)
    }

    /// Write the result to standard output.
    public func writeResultToStandardOutput() {
        if let data = resultString.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }

    // MARK: - Lifecycle

    public func willBeginVisiting() {
        append(headerString)
    }

    public func didEndVisiting() {
        writeResultToStandardOutput()
    }

    public func visitProcessor(_ processor: ObjCProcessorInfo) {
        if !processor.hasObjectiveCRuntimeInfo {
            append("//\n")
            append("// This file does not contain any Objective-C runtime information.\n")
            append("//\n")
        }
    }

    // MARK: - Protocol Visits

    public func willVisitProtocol(_ proto: ObjCProtocol) {
        setContext(.protocol(proto))
    }

    public func didVisitProtocol(_ proto: ObjCProtocol) {
        if hasShownContext {
            append("\n")
        }
    }

    // MARK: - Class Visits

    public func willVisitClass(_ objcClass: ObjCClass) {
        setContext(.class(objcClass))
    }

    public func didVisitClass(_ objcClass: ObjCClass) {
        if hasShownContext {
            append("\n")
        }
    }

    // MARK: - Category Visits

    public func willVisitCategory(_ category: ObjCCategory) {
        setContext(.category(category))
    }

    public func didVisitCategory(_ category: ObjCCategory) {
        if hasShownContext {
            append("\n")
        }
    }

    // MARK: - Method Visits

    public func visitClassMethod(_ method: ObjCMethod) {
        guard method.name.contains(searchString) else { return }

        showContextIfNecessary()

        append("+ ")
        appendMethod(method)
        append("\n")
    }

    public func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState) {
        guard method.name.contains(searchString) else { return }

        showContextIfNecessary()

        append("- ")
        appendMethod(method)
        append("\n")
    }

    // MARK: - Context Management

    private func setContext(_ newContext: MethodSearchContext) {
        context = newContext
        hasShownContext = false
    }

    private func showContextIfNecessary() {
        guard !hasShownContext, let context = context else { return }

        append(context.description)
        append("\n")
        hasShownContext = true
    }

    // MARK: - Formatting

    private func appendMethod(_ method: ObjCMethod) {
        if let formatted = typeFormatter.formatMethodName(method.name, typeString: method.typeEncoding) {
            append(formatted)
            append(";")
        } else {
            append("(\(method.typeEncoding))\(method.name);")
        }
    }
}

// MARK: - Context Types

/// Context for method search results.
private enum MethodSearchContext {
    case `protocol`(ObjCProtocol)
    case `class`(ObjCClass)
    case category(ObjCCategory)

    var description: String {
        switch self {
        case .protocol(let proto):
            return "@protocol \(proto.name)"
        case .class(let cls):
            if let superName = cls.superclassName {
                return "@interface \(cls.name) : \(superName)"
            }
            return "@interface \(cls.name)"
        case .category(let cat):
            return "@interface \(cat.classNameForVisitor) (\(cat.name))"
        }
    }
}
