# Usage

Learn how to use class-dump tools and library for binary analysis.

## Overview

class-dump provides both command-line tools and a Swift library API for analyzing Mach-O binaries.

## Command-Line Tools

### class-dump

The primary tool for generating Objective-C headers from Mach-O binaries.

#### Basic Usage

```bash
# Dump headers to stdout
class-dump /Applications/Safari.app

# Generate individual header files
class-dump -H -o ./headers /Applications/Safari.app

# Select specific architecture
class-dump --arch arm64 /path/to/binary
```

#### Common Options

| Option | Description |
|--------|-------------|
| `-H` | Generate individual header files |
| `-o <dir>` | Output directory for headers |
| `--arch <arch>` | Select architecture (arm64, x86_64, etc.) |
| `--list-arches` | List available architectures |
| `-a` | Show instance variable offsets |
| `-A` | Show implementation addresses |
| `-C <regex>` | Filter classes by pattern |
| `-f <string>` | Find string in method names |
| `-s` | Sort by name |
| `-I` | Sort by inheritance |

#### Examples

```bash
# Dump only UIView subclasses
class-dump -C "UI.*View" /System/Library/Frameworks/UIKit.framework

# Find password-related methods
class-dump -f "password" /Applications/Keychain\ Access.app

# Generate sorted headers
class-dump -H -I -o ./headers /path/to/binary
```

### deprotect

Decrypt protected segments in legacy macOS binaries (10.5-10.6 era).

```bash
# Decrypt a protected binary
deprotect /path/to/protected /path/to/output

# Then analyze with class-dump
class-dump /path/to/output
```

### formatType

Parse and format Objective-C type encodings.

```bash
# Create input file
echo '_name @"NSString"' > types.txt
echo '_count Q' >> types.txt

# Format as instance variables
formatType -i types.txt
# Output: NSString *_name;
#         unsigned long long _count;
```

## Library API

### Loading Binaries

```swift
import ClassDump

// Load a binary (handles both thin and universal)
let url = URL(fileURLWithPath: "/path/to/binary")
let binary = try MachOBinary(contentsOf: url)

// Check available architectures
print("Architectures: \(binary.archNames)")

// Get best match for current system
let machOFile = try binary.bestMatchForLocal()

// Or select specific architecture
if let arch = Arch(name: "arm64") {
    let arm64File = try binary.machOFile(for: arch)
}
```

### Extracting Metadata

```swift
import ClassDump

let binary = try MachOBinary(contentsOf: url)
let machOFile = try binary.bestMatchForLocal()

// Create processor
let processor = ObjC2Processor(machOFile: machOFile)
let metadata = try processor.process()

// Access classes
for objcClass in metadata.classes {
    print("Class: \(objcClass.name)")
    if let superclass = objcClass.superclassName {
        print("  Superclass: \(superclass)")
    }
    
    for method in objcClass.instanceMethods {
        print("  - \(method.name)")
    }
}

// Access protocols
for proto in metadata.protocols {
    print("Protocol: \(proto.name)")
}

// Access categories
for category in metadata.categories {
    print("Category: \(category.name) on \(category.className)")
}
```

### Generating Headers

```swift
import ClassDump

let metadata = try processor.process()

// Generate to stdout
let visitor = TextClassDumpVisitor()
try visitor.visit(metadata: metadata)

// Generate individual files
let outputDir = URL(fileURLWithPath: "./headers")
let multiVisitor = MultiFileVisitor(outputDirectory: outputDir)
try multiVisitor.visit(metadata: metadata)
```

### Parsing Type Encodings

```swift
import ClassDump

let parser = ObjCTypeParser()
let formatter = ObjCTypeFormatter()

// Parse a type encoding
let type = try parser.parse("@\"NSString\"")
let formatted = formatter.format(type)
print(formatted)  // "NSString *"

// Parse method signature
let methodType = try parser.parse("v24@0:8@16")
// Returns: void, self, _cmd, id
```

### Working with Load Commands

```swift
import ClassDump

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
        break
    }
}
```

### Error Handling

```swift
import ClassDump

do {
    let binary = try MachOBinary(contentsOf: url)
} catch MachOError.unsupportedFormat {
    print("Unsupported file format")
} catch MachOError.invalidMagic {
    print("Not a valid Mach-O file")
} catch MachOError.architectureNotFound(let arch) {
    print("Architecture not found: \(arch)")
} catch {
    print("Error: \(error)")
}
```

## See Also

- [ClassDumpCore Documentation](../ClassDumpCore/documentation/classdumpcore)
