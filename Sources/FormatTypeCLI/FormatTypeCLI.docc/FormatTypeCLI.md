# ``FormatTypeCLI``

Command-line tool for parsing and formatting Objective-C type encodings.

## Overview

`formatType` is a utility for working with Objective-C type encodings. It can parse raw type encoding strings and format them as readable instance variable declarations or method signatures.

### Use Cases

- Debug type encoding issues
- Understand complex type encodings
- Generate readable declarations from raw encodings
- Validate bracket balance in type strings

## Usage

```bash
# Format type encodings from a file as instance variables (default)
formatType types.txt

# Format as instance variables explicitly
formatType -i types.txt

# Format as method signatures
formatType -m types.txt

# Check bracket balance
formatType -b types.txt

# Show help
formatType --help
```

## Input Format

The input file should contain one entry per line:

### Instance Variable Mode (-i)

```
name typeEncoding
_delegate @"<UITableViewDelegate>"
_items @"NSArray"
_count Q
```

### Method Mode (-m)

```
methodName typeEncoding
initWithFrame: @24@0:8{CGRect={CGPoint=dd}{CGSize=dd}}16
setObject:forKey: v32@0:8@16@24
```

## Options

| Option | Description |
|--------|-------------|
| `-i, --ivar` | Format as instance variables (default) |
| `-m, --method` | Format as method signatures |
| `-b, --balance` | Check bracket balance in encodings |
| `-h, --help` | Show help message |
| `--version` | Show version information |

## Type Encoding Reference

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

## Examples

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

## Topics

### Command

- ``FormatTypeCommand``
