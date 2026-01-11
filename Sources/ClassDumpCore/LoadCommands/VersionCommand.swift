// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO

/// Version minimum load command (LC_VERSION_MIN_*).
public struct VersionCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The minimum OS version.
    public let version: DylibCommand.Version

    /// The SDK version.
    public let sdk: DylibCommand.Version

    /// The platform this command targets.
    public var platform: Platform {
        switch cmd {
            case UInt32(LC_VERSION_MIN_MACOSX): return .macOS
            case UInt32(LC_VERSION_MIN_IPHONEOS): return .iOS
            case UInt32(LC_VERSION_MIN_TVOS): return .tvOS
            case UInt32(LC_VERSION_MIN_WATCHOS): return .watchOS
            default: return .unknown
        }
    }

    /// Supported platforms.
    public enum Platform: Sendable {
        case macOS
        case iOS
        case tvOS
        case watchOS
        case unknown
    }

    /// Parse a version command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.version = DylibCommand.Version(packed: try cursor.readLittleInt32())
                self.sdk = DylibCommand.Version(packed: try cursor.readLittleInt32())
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.version = DylibCommand.Version(packed: try cursor.readBigInt32())
                self.sdk = DylibCommand.Version(packed: try cursor.readBigInt32())
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 16, actual: data.count)
        }
    }
}

extension VersionCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "VersionCommand(\(platform), version: \(version), sdk: \(sdk))"
    }
}
