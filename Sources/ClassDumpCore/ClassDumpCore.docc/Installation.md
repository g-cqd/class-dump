# Installation

Learn how to install class-dump and its command-line tools.

## Overview

class-dump can be installed from source using Swift Package Manager or by downloading pre-built binaries.

## Building from Source

### Requirements

- macOS 15.0 or later
- Swift 6.0 or later (Xcode 16+)

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/g-cqd/class-dump.git
cd class-dump

# Build release binaries
swift build -c release

# Binaries are located in:
# .build/release/class-dump
# .build/release/deprotect
# .build/release/formatType
# .build/release/regression-test
```

### Install to System Path

```bash
# Copy binaries to /usr/local/bin
sudo cp .build/release/class-dump /usr/local/bin/
sudo cp .build/release/deprotect /usr/local/bin/
sudo cp .build/release/formatType /usr/local/bin/

# Verify installation
class-dump --version
```

## Using as a Swift Package Dependency

Add class-dump to your `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyTool",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/g-cqd/class-dump.git", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MyTool",
            dependencies: [
                .product(name: "ClassDump", package: "class-dump")
            ]
        )
    ]
)
```

### Available Products

| Product | Type | Description |
|---------|------|-------------|
| `ClassDump` | Library | Full API (re-exports ClassDumpCore) |
| `ClassDumpCore` | Library | Core parsing and metadata types |
| `class-dump` | Executable | Header generation CLI |
| `deprotect` | Executable | Segment decryption CLI |
| `formatType` | Executable | Type encoding utility |
| `regression-test` | Executable | Testing utility |

## Pre-built Binaries

Download pre-built universal binaries from the [Releases](https://github.com/g-cqd/class-dump/releases) page.

```bash
# Download and extract
curl -L -o class-dump.tar.gz https://github.com/g-cqd/class-dump/releases/latest/download/class-dump.tar.gz
tar xzf class-dump.tar.gz

# Move to PATH
sudo mv class-dump /usr/local/bin/
```

## Verifying Installation

```bash
# Check version
class-dump --version

# Test on a system binary
class-dump --list-arches /usr/bin/ruby
```
