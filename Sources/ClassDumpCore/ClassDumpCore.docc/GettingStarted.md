# Getting Started with ClassDumpCore

Learn how to use ClassDumpCore to parse Mach-O binaries and extract Objective-C metadata.

## Overview

ClassDumpCore provides a comprehensive API for analyzing Mach-O binaries. This guide walks you through the fundamental concepts and common use cases.

## Loading a Binary

The entry point for binary analysis is ``MachOBinary``. It handles both thin (single architecture) and fat (universal) binaries automatically:

```swift
import ClassDumpCore

// Load a binary from disk
let url = URL(fileURLWithPath: "/path/to/binary")
let binary = try MachOBinary(contentsOf: url)

// Check available architectures
print("Architectures: \(binary.archNames)")
// Output: ["arm64", "x86_64"]
```

## Selecting an Architecture

For universal binaries, you can select a specific architecture or let the library choose the best match for the current system:

```swift
// Get the best match for the current system
let machOFile = try binary.bestMatchForLocal()

// Or select a specific architecture
if let arch = Arch(name: "arm64") {
    let arm64File = try binary.machOFile(for: arch)
}

// List all architectures
for arch in binary.architectures {
    print("\(arch.name): \(arch.uses64BitABI ? "64-bit" : "32-bit")")
}
```

## Extracting Objective-C Metadata

Once you have a ``MachOFile``, you can extract Objective-C runtime information:

```swift
let machOFile = try binary.bestMatchForLocal()

// Process Objective-C metadata
let processor = ObjC2Processor(machOFile: machOFile)
let metadata = try processor.process()

// Iterate through classes
for objcClass in metadata.classes {
    print("Class: \(objcClass.name)")
    
    // Print methods
    for method in objcClass.instanceMethods {
        print("  - \(method.name)")
    }
    
    // Print properties
    for property in objcClass.properties {
        print("  @property \(property.name)")
    }
}

// Iterate through protocols
for proto in metadata.protocols {
    print("Protocol: \(proto.name)")
}

// Iterate through categories
for category in metadata.categories {
    print("Category: \(category.name) on \(category.className)")
}
```

## Generating Headers

Use the visitor pattern to generate Objective-C header files:

```swift
// Generate headers to stdout
let visitor = TextClassDumpVisitor()
try visitor.visit(metadata: metadata)

// Or generate to individual files
let outputDir = URL(fileURLWithPath: "./headers")
let multiVisitor = MultiFileVisitor(outputDirectory: outputDir)
try multiVisitor.visit(metadata: metadata)
```

## Parsing Type Encodings

ClassDumpCore can parse and format Objective-C type encodings:

```swift
// Parse a type encoding
let parser = ObjCTypeParser()
let type = try parser.parse("@\"NSString\"")

// Format it back to a readable string
let formatter = ObjCTypeFormatter()
let formatted = formatter.format(type)
print(formatted)  // "NSString *"

// Parse method type encodings
let methodType = try parser.parse("v24@0:8@16")
// Returns: void, self, _cmd, id
```

## Working with Load Commands

Access load commands directly for low-level analysis:

```swift
let machOFile = try binary.bestMatchForLocal()

for command in machOFile.loadCommands {
    switch command {
    case .segment(let segment):
        print("Segment: \(segment.name)")
        for section in segment.sections {
            print("  Section: \(section.name)")
        }
        
    case .dylib(let dylib):
        print("Dylib: \(dylib.name)")
        
    case .uuid(let uuid):
        print("UUID: \(uuid.uuidString)")
        
    default:
        print("Other: \(command.type)")
    }
}
```

## Handling Errors

ClassDumpCore uses Swift's error handling for robust error management:

```swift
do {
    let binary = try MachOBinary(contentsOf: url)
    let machOFile = try binary.bestMatchForLocal()
    // ...
} catch MachOError.unsupportedFormat {
    print("Unsupported file format")
} catch MachOError.invalidMagic {
    print("Not a valid Mach-O file")
} catch MachOError.architectureNotFound(let arch) {
    print("Architecture not found: \(arch)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Next Steps

- Learn about the <doc:CommandLineTools> for quick binary analysis
- Explore the ``ObjC2Processor`` for detailed metadata extraction
- Check out ``ClassDumpVisitor`` for custom output generation
