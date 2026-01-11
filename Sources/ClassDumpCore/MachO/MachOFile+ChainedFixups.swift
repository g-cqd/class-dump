// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - ChainedFixups + MachOFile Integration

extension MachOFile {
    /// Parse chained fixups from LC_DYLD_CHAINED_FIXUPS if present.
    public func parseChainedFixups() throws -> ChainedFixups? {
        // Find LC_DYLD_CHAINED_FIXUPS load command
        guard
            let fixupsCommand = loadCommands.first(where: {
                $0.cmd == 0x8000_0034  // LC_DYLD_CHAINED_FIXUPS
            })
        else {
            return nil
        }

        // Get the linkedit data command info
        guard case .linkeditData(let linkedit) = fixupsCommand else {
            return nil
        }

        // Read the fixups data directly from file data
        let offset = Int(linkedit.dataoff)
        let size = Int(linkedit.datasize)
        guard offset >= 0, size > 0, offset + size <= data.count else {
            throw ChainedFixupsError.dataTooSmall
        }

        let fixupsData = data.subdata(in: offset..<(offset + size))
        return try ChainedFixups(data: fixupsData, byteOrder: byteOrder)
    }

    /// Check if this binary uses chained fixups.
    public var hasChainedFixups: Bool {
        loadCommands.contains { $0.cmd == 0x8000_0034 }
    }
}
