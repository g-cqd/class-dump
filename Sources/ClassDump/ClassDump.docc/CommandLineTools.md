# Command Line Tools

Learn how to use the class-dump suite of command-line tools for binary analysis.

## Overview

The class-dump package includes three command-line tools:

| Tool | Purpose |
|------|---------|
| `class-dump` | Generate Objective-C headers from Mach-O binaries |
| `deprotect` | Decrypt protected segments in legacy binaries |
| `formatType` | Parse and format Objective-C type encodings |

## class-dump

The primary tool for extracting Objective-C interface declarations from compiled binaries.

### Basic Usage

```bash
# Dump headers to stdout
class-dump /Applications/Safari.app

# Generate header files
class-dump -H -o ./headers /Applications/Safari.app

# Dump a specific architecture from a universal binary
class-dump --arch arm64 /path/to/binary
```

### Options

#### Architecture Selection

```bash
# List available architectures
class-dump --list-arches /path/to/binary

# Select a specific architecture
class-dump --arch arm64 /path/to/binary
class-dump --arch x86_64 /path/to/binary
```

#### Display Options

```bash
# Show instance variable offsets
class-dump -a /path/to/binary

# Show implementation addresses
class-dump -A /path/to/binary

# Suppress the header comment
class-dump -t /path/to/binary
```

#### Sorting Options

```bash
# Sort classes and categories by name
class-dump -s /path/to/binary

# Sort by inheritance hierarchy
class-dump -I /path/to/binary

# Sort methods by name
class-dump -S /path/to/binary
```

#### Filtering

```bash
# Only show classes matching a pattern
class-dump -C "NS.*View" /path/to/binary

# Find methods containing a string
class-dump -f "initWith" /path/to/binary
```

#### Output Options

```bash
# Generate individual header files
class-dump -H /path/to/binary

# Specify output directory
class-dump -H -o ./output /path/to/binary

# Recursively process frameworks
class-dump -r /path/to/binary
```

#### SDK Options

```bash
# Specify iOS SDK version
class-dump --sdk-ios 17.0 /path/to/binary

# Specify macOS SDK version
class-dump --sdk-mac 14.0 /path/to/binary

# Specify full SDK path
class-dump --sdk-root /path/to/SDK /path/to/binary
```

### Examples

```bash
# Dump AppKit framework
class-dump /System/Library/Frameworks/AppKit.framework

# Generate headers for a specific app
class-dump -H -o ~/Desktop/headers /Applications/Notes.app

# Find all methods related to "password"
class-dump -f password /Applications/Keychain\ Access.app

# Dump only UIView subclasses from UIKit
class-dump -C "UI.*View" /System/Library/Frameworks/UIKit.framework
```

## deprotect

Decrypts protected segments found in some legacy macOS binaries (macOS 10.5-10.6 era).

### Basic Usage

```bash
# Decrypt a protected binary
deprotect /path/to/protected-binary /path/to/output

# Specify architecture for universal binaries
deprotect --arch x86_64 /path/to/binary /path/to/output
```

### Options

| Option | Description |
|--------|-------------|
| `-a, --arch <arch>` | Select architecture from universal binary |
| `-h, --help` | Show help message |
| `--version` | Show version |

### How It Works

Some older macOS binaries have encrypted `__TEXT` segments that are decrypted by the kernel at load time. The `deprotect` tool:

1. Identifies protected segments (marked with `SG_PROTECTED_VERSION_1`)
2. Decrypts the segment data using the appropriate cipher (Blowfish or AES)
3. Writes the decrypted binary with the protection flag cleared

> Note: Protected binaries are rare in modern macOS. This tool is primarily useful for analyzing legacy software.

### Example Workflow

```bash
# Check if a binary is protected
otool -l /path/to/binary | grep -A2 "__TEXT"

# Deprotect the binary
deprotect /path/to/protected /tmp/decrypted

# Now analyze with class-dump
class-dump /tmp/decrypted
```

## formatType

A utility for parsing and formatting Objective-C type encodings.

### Basic Usage

```bash
# Format type encodings from a file
formatType types.txt

# Format as instance variables (default)
formatType -i types.txt

# Format as method signatures
formatType -m types.txt

# Check bracket balance
formatType -b types.txt
```

### Input Format

The input file should contain one entry per line:

```
# For ivar mode (-i):
name typeEncoding
_delegate @"<UITableViewDelegate>"
_items @"NSArray"

# For method mode (-m):
methodName typeEncoding
initWithFrame: @24@0:8{CGRect={CGPoint=dd}{CGSize=dd}}16
```

### Options

| Option | Description |
|--------|-------------|
| `-i, --ivar` | Format as instance variables (default) |
| `-m, --method` | Format as method signatures |
| `-b, --balance` | Check bracket balance in encodings |
| `-h, --help` | Show help message |
| `--version` | Show version |

### Type Encoding Reference

Common Objective-C type encodings:

| Encoding | Type |
|----------|------|
| `c` | char |
| `i` | int |
| `s` | short |
| `l` | long |
| `q` | long long |
| `C` | unsigned char |
| `I` | unsigned int |
| `S` | unsigned short |
| `L` | unsigned long |
| `Q` | unsigned long long |
| `f` | float |
| `d` | double |
| `B` | bool (C++) |
| `v` | void |
| `*` | char * |
| `@` | id (object) |
| `#` | Class |
| `:` | SEL |
| `^type` | pointer to type |
| `@"ClassName"` | typed object |
| `{name=types}` | struct |
| `(name=types)` | union |
| `[count type]` | array |
| `b num` | bitfield |

### Examples

```bash
# Create a test file
echo '_name @"NSString"' > test.txt
echo '_count Q' >> test.txt

# Format as ivars
formatType -i test.txt
# Output:
# NSString *_name;
# unsigned long long _count;

# Format method types
echo 'setObject:forKey: v32@0:8@16@24' > methods.txt
formatType -m methods.txt
# Output:
# - (void)setObject:(id)arg1 forKey:(id)arg2;
```

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/g-cqd/class-dump.git
cd class-dump

# Build release binaries
swift build -c release

# Install to /usr/local/bin
sudo cp .build/release/class-dump /usr/local/bin/
sudo cp .build/release/deprotect /usr/local/bin/
sudo cp .build/release/formatType /usr/local/bin/
```

### Using Swift Package Manager

```swift
.package(url: "https://github.com/g-cqd/class-dump.git", from: "4.0.0")
```

## See Also

- <doc:GettingStarted>
- ``MachOBinary``
- ``ObjCTypeParser``
