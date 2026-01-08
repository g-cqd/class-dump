# ``DeprotectCLI``

Command-line tool for decrypting protected Mach-O segments.

## Overview

`deprotect` decrypts protected segments found in some legacy macOS binaries. These protected binaries were common in macOS 10.5-10.6 era and use segment encryption that is decrypted by the kernel at load time.

### How It Works

Some older macOS binaries have encrypted `__TEXT` segments marked with the `SG_PROTECTED_VERSION_1` flag. The `deprotect` tool:

1. Identifies protected segments in the binary
2. Decrypts the segment data using the appropriate cipher (Blowfish or AES)
3. Writes a new binary with decrypted content and the protection flag cleared

> Note: Protected binaries are rare in modern macOS. This tool is primarily useful for analyzing legacy software.

## Usage

```bash
# Basic usage
deprotect /path/to/protected-binary /path/to/output

# Specify architecture for universal binaries
deprotect --arch x86_64 /path/to/binary /path/to/output

# Show help
deprotect --help

# Show version
deprotect --version
```

## Options

| Option | Description |
|--------|-------------|
| `-a, --arch <arch>` | Select architecture from universal binary |
| `-h, --help` | Show help message |
| `--version` | Show version information |

## Example Workflow

```bash
# Check if a binary is protected
otool -l /path/to/binary | grep -A2 "SG_PROTECTED"

# Deprotect the binary
deprotect /path/to/protected /tmp/decrypted

# Now analyze with class-dump
class-dump /tmp/decrypted
```

## Supported Encryption Types

| Type | Description |
|------|-------------|
| Blowfish | Legacy encryption (macOS 10.5) |
| AES | Standard encryption (macOS 10.6) |

## Topics

### Command

- ``DeprotectCommand``
