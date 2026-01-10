// SPDX-License-Identifier: MIT
// Copyright (c) 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Code Signature Magic Values

/// Code signature blob magic values.
public enum CodeSignatureMagic: UInt32 {
    /// SuperBlob containing multiple sub-blobs.
    case superBlob = 0xFADE_0CC0

    /// Code directory blob.
    case codeDirectory = 0xFADE_0C02

    /// Entitlements blob (XML plist).
    case entitlements = 0xFADE_7171

    /// DER entitlements blob (binary DER format).
    case entitlementsDER = 0xFADE_7172

    /// Requirements blob.
    case requirements = 0xFADE_0C01

    /// CMS signature blob.
    case blobWrapper = 0xFADE_0B01

    /// Launch constraint blob (self).
    case launchConstraintSelf = 0xFADE_8181

    /// Launch constraint blob (parent).
    case launchConstraintParent = 0xFADE_8182

    /// Launch constraint blob (responsible).
    case launchConstraintResponsible = 0xFADE_8183
}

/// Code signature slot types.
public enum CodeSignatureSlot: UInt32 {
    /// Code directory slot.
    case codeDirectory = 0

    /// Info.plist slot.
    case infoPlist = 1

    /// Requirements slot.
    case requirements = 2

    /// Resource directory slot.
    case resourceDir = 3

    /// Application-specific slot.
    case application = 4

    /// Entitlements slot (XML plist).
    case entitlements = 5

    /// DER entitlements slot (binary DER format).
    case entitlementsDER = 7

    /// Launch constraint self slot.
    case launchConstraintSelf = 8

    /// Launch constraint parent slot.
    case launchConstraintParent = 9

    /// Launch constraint responsible slot.
    case launchConstraintResponsible = 10

    /// CMS signature slot.
    case cmsSignature = 0x10000
}

// MARK: - Code Signature Blob Structures

/// A single blob in the code signature.
public struct CodeSignatureBlob: Sendable {
    /// The blob type (slot).
    public let type: UInt32

    /// The offset of the blob within the SuperBlob.
    public let offset: UInt32

    /// The blob data.
    public let data: Data

    /// The magic value of the blob.
    public var magic: CodeSignatureMagic? {
        guard data.count >= 4 else { return nil }
        let magic = data.withUnsafeBytes { ptr -> UInt32 in
            UInt32(bigEndian: ptr.loadUnaligned(as: UInt32.self))
        }
        return CodeSignatureMagic(rawValue: magic)
    }

    /// The slot type if known.
    public var slot: CodeSignatureSlot? {
        CodeSignatureSlot(rawValue: type)
    }
}

// MARK: - Code Signature Parser

/// Parser for Mach-O code signatures.
public struct CodeSignature: Sendable {
    /// The raw code signature data.
    public let data: Data

    /// The parsed blobs in the signature.
    public let blobs: [CodeSignatureBlob]

    /// The XML entitlements string, if present.
    public var entitlements: String? {
        guard let blob = blobs.first(where: { $0.slot == .entitlements }) else {
            return nil
        }
        return extractEntitlementsString(from: blob.data)
    }

    /// The DER entitlements data, if present.
    public var entitlementsDER: Data? {
        guard let blob = blobs.first(where: { $0.slot == .entitlementsDER }) else {
            return nil
        }
        // Skip the 8-byte header (magic + length)
        guard blob.data.count > 8 else { return nil }
        return blob.data.subdata(in: 8..<blob.data.count)
    }

    /// The code directory blob, if present.
    public var codeDirectory: Data? {
        blobs.first(where: { $0.slot == .codeDirectory })?.data
    }

    /// The CMS signature blob, if present.
    public var cmsSignature: Data? {
        blobs.first(where: { $0.slot == .cmsSignature })?.data
    }

    /// Parse a code signature from data.
    public init(data: Data) throws {
        self.data = data

        guard data.count >= 12 else {
            throw CodeSignatureError.dataTooSmall
        }

        // Read SuperBlob header (big-endian)
        let magic = data.withUnsafeBytes { ptr -> UInt32 in
            UInt32(bigEndian: ptr.loadUnaligned(as: UInt32.self))
        }

        guard magic == CodeSignatureMagic.superBlob.rawValue else {
            throw CodeSignatureError.invalidMagic(magic)
        }

        let length = data.withUnsafeBytes { ptr -> UInt32 in
            UInt32(bigEndian: ptr.loadUnaligned(fromByteOffset: 4, as: UInt32.self))
        }

        let count = data.withUnsafeBytes { ptr -> UInt32 in
            UInt32(bigEndian: ptr.loadUnaligned(fromByteOffset: 8, as: UInt32.self))
        }

        guard Int(length) <= data.count else {
            throw CodeSignatureError.invalidLength(expected: Int(length), actual: data.count)
        }

        // Parse blob index entries
        var blobs: [CodeSignatureBlob] = []
        blobs.reserveCapacity(Int(count))

        var offset = 12
        for _ in 0..<count {
            guard offset + 8 <= data.count else { break }

            let type = data.withUnsafeBytes { ptr -> UInt32 in
                UInt32(bigEndian: ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
            }

            let blobOffset = data.withUnsafeBytes { ptr -> UInt32 in
                UInt32(bigEndian: ptr.loadUnaligned(fromByteOffset: offset + 4, as: UInt32.self))
            }

            // Read blob length from blob header
            let blobStart = Int(blobOffset)
            guard blobStart + 8 <= data.count else { break }

            let blobLength = data.withUnsafeBytes { ptr -> UInt32 in
                UInt32(bigEndian: ptr.loadUnaligned(fromByteOffset: blobStart + 4, as: UInt32.self))
            }

            let blobEnd = blobStart + Int(blobLength)
            guard blobEnd <= data.count else { break }

            let blobData = data.subdata(in: blobStart..<blobEnd)
            blobs.append(CodeSignatureBlob(type: type, offset: blobOffset, data: blobData))

            offset += 8
        }

        self.blobs = blobs
    }

    /// Extract entitlements from a Mach-O file.
    public static func extractEntitlements(from machOFile: MachOFile) throws -> String? {
        // Find LC_CODE_SIGNATURE load command
        guard
            let codeSignatureCmd = machOFile.loadCommands
                .compactMap({ cmd -> LinkeditDataCommand? in
                    if case .linkeditData(let linkedit) = cmd,
                        linkedit.cmd == UInt32(LC_CODE_SIGNATURE)
                    {
                        return linkedit
                    }
                    return nil
                })
                .first
        else {
            return nil
        }

        // Extract code signature data
        let start = Int(codeSignatureCmd.dataoff)
        let end = start + Int(codeSignatureCmd.datasize)
        guard end <= machOFile.data.count else {
            throw CodeSignatureError.invalidRange
        }

        let signatureData = machOFile.data.subdata(in: start..<end)
        let signature = try CodeSignature(data: signatureData)
        return signature.entitlements
    }

    /// Extract entitlements string from blob data.
    private func extractEntitlementsString(from data: Data) -> String? {
        // Skip the 8-byte header (magic + length)
        guard data.count > 8 else { return nil }
        let xmlData = data.subdata(in: 8..<data.count)

        // Convert to string
        guard let xmlString = String(data: xmlData, encoding: .utf8) else {
            return nil
        }

        // Trim any trailing null bytes
        return xmlString.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
    }
}

// MARK: - Errors

/// Errors that can occur when parsing code signatures.
public enum CodeSignatureError: Error, CustomStringConvertible {
    case dataTooSmall
    case invalidMagic(UInt32)
    case invalidLength(expected: Int, actual: Int)
    case invalidRange
    case noCodeSignature

    public var description: String {
        switch self {
            case .dataTooSmall:
                return "Code signature data too small"
            case .invalidMagic(let magic):
                return "Invalid code signature magic: 0x\(String(magic, radix: 16))"
            case .invalidLength(let expected, let actual):
                return "Invalid code signature length: expected \(expected), actual \(actual)"
            case .invalidRange:
                return "Code signature range exceeds file bounds"
            case .noCodeSignature:
                return "No code signature found in binary"
        }
    }
}
