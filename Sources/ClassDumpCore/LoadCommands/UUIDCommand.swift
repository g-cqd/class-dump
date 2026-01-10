// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// UUID load command (LC_UUID).
public struct UUIDCommand: LoadCommandProtocol, Sendable {
  /// The command type (LC_UUID).
  public let cmd: UInt32

  /// The size of the command in bytes.
  public let cmdsize: UInt32

  /// The UUID value.
  public let uuid: UUID

  /// Parse a UUID command from data.
  public init(data: Data) throws {
    guard data.count >= 24 else {
      throw LoadCommandError.dataTooSmall(expected: 24, actual: data.count)
    }

    self.cmd = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }
    self.cmdsize = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) }

    // Read 16-byte UUID
    let uuidBytes = data.subdata(in: 8..<24)
    self.uuid = uuidBytes.withUnsafeBytes { ptr in
      UUID(uuid: ptr.loadUnaligned(as: uuid_t.self))
    }
  }

  /// The string representation of the UUID.
  public var uuidString: String {
    uuid.uuidString
  }
}

extension UUIDCommand: CustomStringConvertible {
  /// A textual description of the command.
  public var description: String {
    "UUIDCommand(\(uuidString))"
  }
}
