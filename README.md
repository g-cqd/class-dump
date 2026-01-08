class-dump
==========

class-dump is a command-line utility for examining the Objective-C
segment of Mach-O files.  It generates declarations for the classes,
categories and protocols.  This is the same information provided by
using 'otool -ov', but presented as normal Objective-C declarations.

**Version 4.0.0 is a complete rewrite in Swift.**

The latest version and information is available at:

    http://stevenygard.com/projects/class-dump

The source code is also available from my Github repository at:

    https://github.com/g-cqd/class-dump

Installation
------------

### Swift Package Manager

Add `class-dump` as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/g-cqd/class-dump.git", from: "4.0.1")
]
```

### Pre-built Binaries

You can download pre-built binaries for macOS from the [Releases](https://github.com/g-cqd/class-dump/releases) page.

Usage
-----

    class-dump 4.0.0 (Swift)
    Usage: class-dump [options] <file>

      ARGUMENTS:
        <file>                  The Mach-O file to process

      OPTIONS:
        --arch <arch>           Select a specific architecture from a universal binary (ppc, ppc64, i386, x86_64, armv6, armv7, armv7s, arm64)
        --list-arches           List the architectures in the file, then exit
        -a                      Show instance variable offsets
        -A                      Show implementation addresses
        -t                      Suppress header in output, for testing
        -s                      Sort classes and categories by name
        -I                      Sort classes, categories, and protocols by inheritance (overrides -s)
        -S                      Sort methods by name
        -C <match>              Only display classes matching regular expression
        -f <find>               Find string in method name
        -H                      Generate header files in current directory, or directory specified with -o
        -o <output-dir>         Output directory used for -H
        -r                      Recursively expand frameworks and fixed VM shared libraries
        --sdk-ios <sdk-ios>     Specify iOS SDK version
        --sdk-mac <sdk-mac>     Specify Mac OS X SDK version
        --sdk-root <sdk-root>   Specify the full SDK root path
        --hide <hide>           Hide section (structures, protocols, or all)
        -h, --help              Show help information

Development
-----------

### Building

    swift build

### Testing

    swift test

### Tools

This project uses `swa` (Swift Static Analysis) for linting and quality checks.

    swa unused Sources
    swa duplicates Sources


License
-------

This file is part of class-dump, a utility for examining the
Objective-C segment of Mach-O files.
Copyright (C) 1997-2019 Steve Nygard.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

Contact
-------

You may contact the author by:
   e-mail:  nygard at gmail.com
