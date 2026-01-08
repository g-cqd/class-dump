# ``ClassDump``

A Swift library for parsing Mach-O binaries and extracting Objective-C runtime metadata.

## Overview

ClassDump is the core library behind the `class-dump` suite of tools. It provides comprehensive support for:

- **Mach-O Binary Parsing**: Read and analyze Mach-O executables, frameworks, and libraries
- **Universal Binary Support**: Handle fat binaries containing multiple architectures
- **Objective-C Metadata Extraction**: Extract classes, protocols, categories, methods, and properties
- **Type Encoding Parsing**: Parse and format Objective-C type encodings
- **Segment Decryption**: Decrypt protected segments from legacy macOS binaries

The library is designed with Swift 6 strict concurrency in mind and provides a clean, type-safe API for binary analysis.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:CommandLineTools>

### Mach-O Binary Analysis

- ``MachOBinary``
- ``MachOFile``
- ``MachOHeader``
- ``Arch``
- ``FatFile``
- ``ByteOrder``

### Load Commands

- ``LoadCommand``
- ``LoadCommandType``
- ``SegmentCommand``
- ``Section``
- ``DylibCommand``
- ``SymtabCommand``

### Objective-C Metadata

- ``ObjCClass``
- ``ObjCCategory``
- ``ObjCProtocol``
- ``ObjCMethod``
- ``ObjCProperty``
- ``ObjCInstanceVariable``
- ``ObjC2Processor``

### Type System

- ``ObjCType``
- ``ObjCTypeParser``
- ``ObjCTypeFormatter``
- ``ObjCTypeLexer``

### Visitor Pattern

- ``ClassDumpVisitor``
- ``ClassDumpHeaderVisitor``
- ``TextClassDumpVisitor``
- ``MultiFileVisitor``
- ``ClassFrameworkVisitor``
- ``FindMethodVisitor``

### Decryption

- ``SegmentDecryptor``

### Errors

- ``MachOError``
- ``LoadCommandError``
