# ``ClassDump``

A complete toolkit for Mach-O binary analysis and Objective-C header generation.

## Overview

The class-dump package provides tools for examining Mach-O binaries and extracting Objective-C runtime metadata. It includes:

- **ClassDumpCore**: The core library for parsing Mach-O files and extracting metadata
- **class-dump**: Command-line tool for generating Objective-C headers
- **deprotect**: Tool for decrypting protected binary segments
- **formatType**: Utility for parsing Objective-C type encodings
- **regression-test**: Tool for testing against reference implementations

### Quick Start

```bash
# Generate headers from a binary
class-dump /Applications/Safari.app

# Generate individual header files
class-dump -H -o ./headers /Applications/Safari.app

# List architectures in a universal binary
class-dump --list-arches /path/to/binary
```

### Using as a Library

```swift
import ClassDump

// Load a binary
let binary = try MachOBinary(contentsOf: url)
let machOFile = try binary.bestMatchForLocal()

// Extract Objective-C metadata
let processor = ObjC2Processor(machOFile: machOFile)
let metadata = try processor.process()

// Iterate through classes
for objcClass in metadata.classes {
    print("Class: \(objcClass.name)")
}
```

## Topics

### Getting Started

- <doc:Installation>
- <doc:Usage>
