// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Build platform type.
public enum BuildPlatform: UInt32, Sendable {
  case macOS = 1
  case iOS = 2
  case tvOS = 3
  case watchOS = 4
  case bridgeOS = 5
  case macCatalyst = 6
  case iOSSimulator = 7
  case tvOSSimulator = 8
  case watchOSSimulator = 9
  case driverKit = 10
  case visionOS = 11
  case visionOSSimulator = 12

  /// The name of the platform.
  public var name: String {
    switch self {
    case .macOS: return "macOS"
    case .iOS: return "iOS"
    case .tvOS: return "tvOS"
    case .watchOS: return "watchOS"
    case .bridgeOS: return "bridgeOS"
    case .macCatalyst: return "macCatalyst"
    case .iOSSimulator: return "iOS Simulator"
    case .tvOSSimulator: return "tvOS Simulator"
    case .watchOSSimulator: return "watchOS Simulator"
    case .driverKit: return "DriverKit"
    case .visionOS: return "visionOS"
    case .visionOSSimulator: return "visionOS Simulator"
    }
  }
}

/// Build tool version information.
public struct BuildToolVersion: Sendable {
  /// The tool type.
  public let tool: UInt32

  /// The tool version.
  public let version: DylibCommand.Version

  /// The name of the tool.
  public var toolName: String {
    switch tool {
    case 1: return "clang"
    case 2: return "swift"
    case 3: return "ld"
    case 4: return "lld"
    default: return "unknown(\(tool))"
    }
  }
}

/// Build version load command (LC_BUILD_VERSION).
public struct BuildVersionCommand: LoadCommandProtocol, Sendable {
  /// The command type (LC_BUILD_VERSION).
  public let cmd: UInt32

  /// The size of the command in bytes.
  public let cmdsize: UInt32

  /// The target platform.
  public let platform: BuildPlatform?

  /// The raw platform value.
  public let platformRaw: UInt32

  /// The minimum OS version.
  public let minos: DylibCommand.Version

  /// The SDK version.
  public let sdk: DylibCommand.Version

  /// The build tools used.
  public let tools: [BuildToolVersion]

  /// Parse a build version command from data.
  public init(data: Data, byteOrder: ByteOrder) throws {
    do {
      var cursor = try DataCursor(data: data, offset: 0)

      if byteOrder == .little {
        self.cmd = try cursor.readLittleInt32()
        self.cmdsize = try cursor.readLittleInt32()
        self.platformRaw = try cursor.readLittleInt32()
        self.minos = DylibCommand.Version(packed: try cursor.readLittleInt32())
        self.sdk = DylibCommand.Version(packed: try cursor.readLittleInt32())
        let ntools = try cursor.readLittleInt32()

        var tools: [BuildToolVersion] = []
        tools.reserveCapacity(Int(ntools))
        for _ in 0..<ntools {
          let tool = try cursor.readLittleInt32()
          let version = DylibCommand.Version(packed: try cursor.readLittleInt32())
          tools.append(BuildToolVersion(tool: tool, version: version))
        }
        self.tools = tools
      } else {
        self.cmd = try cursor.readBigInt32()
        self.cmdsize = try cursor.readBigInt32()
        self.platformRaw = try cursor.readBigInt32()
        self.minos = DylibCommand.Version(packed: try cursor.readBigInt32())
        self.sdk = DylibCommand.Version(packed: try cursor.readBigInt32())
        let ntools = try cursor.readBigInt32()

        var tools: [BuildToolVersion] = []
        tools.reserveCapacity(Int(ntools))
        for _ in 0..<ntools {
          let tool = try cursor.readBigInt32()
          let version = DylibCommand.Version(packed: try cursor.readBigInt32())
          tools.append(BuildToolVersion(tool: tool, version: version))
        }
        self.tools = tools
      }

      self.platform = BuildPlatform(rawValue: platformRaw)
    } catch {
      throw LoadCommandError.dataTooSmall(expected: 24, actual: data.count)
    }
  }
}

extension BuildVersionCommand: CustomStringConvertible {
  /// A textual description of the command.
  public var description: String {
    let platformName = platform?.name ?? "unknown(\(platformRaw))"
    return "BuildVersionCommand(\(platformName), minos: \(minos), sdk: \(sdk))"
  }
}
