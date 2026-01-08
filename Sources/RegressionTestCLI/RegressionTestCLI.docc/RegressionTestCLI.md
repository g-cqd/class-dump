# ``RegressionTestCLI``

Command-line tool for regression testing class-dump against reference binaries.

## Overview

`regression-test` compares output from a reference (old) version of class-dump with the current version against system frameworks and applications. This helps detect regressions when making changes to the class-dump codebase.

### Features

- Compare reference vs current class-dump output
- Support for macOS and iOS SDK targets
- Filter targets by name pattern
- Limit number of targets for quick checks
- Automatic architecture detection
- Integration with diff tools (Kaleidoscope)

## Usage

```bash
# Basic usage - compare against reference binary
regression-test --reference ~/bin/class-dump-3.5

# Test iOS SDK targets
regression-test --reference ~/bin/class-dump-3.5 --ios

# Specify a particular SDK
regression-test --reference ~/bin/class-dump-3.5 --sdk iphoneos

# Filter to specific frameworks
regression-test --reference ~/bin/class-dump-3.5 --filter "Foundation"

# Limit to first 10 targets for quick testing
regression-test --reference ~/bin/class-dump-3.5 --limit 10

# Verbose output showing all results
regression-test --reference ~/bin/class-dump-3.5 --verbose

# Open diff tool after testing
regression-test --reference ~/bin/class-dump-3.5 --diff

# List available SDKs
regression-test --show-sdks
```

## Options

### Required Options

| Option | Description |
|--------|-------------|
| `--reference <path>` | Path to the reference (old) class-dump binary |

### Target Options

| Option | Description |
|--------|-------------|
| `--current <path>` | Path to new class-dump binary (default: class-dump in PATH) |
| `--ios` | Test iOS targets instead of macOS |
| `--sdk <name>` | Specify an SDK (e.g., iphoneos, macosx) |

### Output Options

| Option | Description |
|--------|-------------|
| `-o, --output <dir>` | Output directory for test results |
| `--diff` | Open diff tool after testing (requires Kaleidoscope) |
| `--verbose` | Show all test results |

### Filter Options

| Option | Description |
|--------|-------------|
| `--filter <pattern>` | Only test targets matching pattern |
| `--limit <n>` | Maximum number of targets to test |

### Other Options

| Option | Description |
|--------|-------------|
| `--show-sdks` | List available SDKs and exit |
| `--help` | Show help message |
| `--version` | Show version information |

## Output

Results are saved to the output directory (default: `/tmp/class-dump-regression`):

```
/tmp/class-dump-regression/
├── reference/     # Output from reference binary
│   ├── Foundation-arm64-framework.txt
│   ├── AppKit-arm64-framework.txt
│   └── ...
└── current/       # Output from current binary
    ├── Foundation-arm64-framework.txt
    ├── AppKit-arm64-framework.txt
    └── ...
```

## Example Workflow

```bash
# 1. Build the current version
swift build -c release

# 2. Run regression tests
regression-test \
    --reference ~/bin/class-dump-3.5 \
    --current .build/release/class-dump \
    --filter "Foundation|AppKit" \
    --verbose

# 3. Compare results
diff -r /tmp/class-dump-regression/reference /tmp/class-dump-regression/current

# Or use Kaleidoscope
ksdiff /tmp/class-dump-regression/reference /tmp/class-dump-regression/current
```

## Topics

### Command

- ``RegressionTestCommand``

### Supporting Types

- ``TargetCollection``
- ``TestResult``
- ``RegressionTestError``
