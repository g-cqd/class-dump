# ``ClassDumpCLI``

Command-line tool for generating Objective-C headers from Mach-O binaries.

## Overview

`class-dump` is the primary tool in the class-dump suite. It examines Mach-O files and generates Objective-C header declarations for all classes, categories, and protocols found in the binary.

### Features

- Extract class, protocol, and category declarations
- Support for universal (fat) binaries with architecture selection
- Generate individual header files or combined output
- Filter output by class name patterns
- Search for specific method names
- Sort output by name or inheritance hierarchy

## Usage

```bash
# Basic usage - dump to stdout
class-dump /path/to/binary

# Generate header files
class-dump -H -o ./headers /path/to/binary

# List architectures in a universal binary
class-dump --list-arches /path/to/binary

# Dump specific architecture
class-dump --arch arm64 /path/to/binary

# Filter by class name
class-dump -C "NS.*View" /path/to/binary

# Find methods containing a string
class-dump -f "initWith" /path/to/binary
```

## Options

### Architecture Options

| Option | Description |
|--------|-------------|
| `--arch <arch>` | Select architecture (arm64, x86_64, etc.) |
| `--list-arches` | List available architectures and exit |

### Display Options

| Option | Description |
|--------|-------------|
| `-a` | Show instance variable offsets |
| `-A` | Show implementation addresses |
| `-t` | Suppress header comment in output |

### Sorting Options

| Option | Description |
|--------|-------------|
| `-s` | Sort classes and categories by name |
| `-I` | Sort by inheritance hierarchy |
| `-S` | Sort methods by name |

### Filtering Options

| Option | Description |
|--------|-------------|
| `-C <regex>` | Only show classes matching pattern |
| `-f <string>` | Find string in method names |

### Output Options

| Option | Description |
|--------|-------------|
| `-H` | Generate individual header files |
| `-o <dir>` | Output directory for headers |
| `-r` | Recursively process frameworks |

### SDK Options

| Option | Description |
|--------|-------------|
| `--sdk-ios <version>` | Specify iOS SDK version |
| `--sdk-mac <version>` | Specify macOS SDK version |
| `--sdk-root <path>` | Specify full SDK root path |

## Topics

### Command

- ``ClassDumpCommand``
