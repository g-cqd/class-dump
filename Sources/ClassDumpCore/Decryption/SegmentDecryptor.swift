import CommonCrypto
import Foundation

/// Errors during segment decryption.
public enum SegmentDecryptionError: Error, Sendable {
    case invalidSegmentSize
    case unsupportedEncryption(UInt32)
    case decryptionFailed
    case aesError(CCCryptorStatus)
}

/// Handles decryption of protected Mach-O segments.
///
/// Protected segments were used in macOS 10.5-10.6 era for App Store binaries.
/// Two encryption types were used:
/// - Type 1 (AES): Used in 10.5
/// - Type 2 (Blowfish): Used in 10.6
public struct SegmentDecryptor: Sendable {
    /// The standard page size for segment encryption (4096 bytes).
    public static let pageSize = 4096

    /// Magic values identifying encryption types.
    public struct Magic: Sendable {
        public static let none: UInt32 = 0
        public static let aes: UInt32 = 0xc228_6295
        public static let blowfish: UInt32 = 0x2e69_cf40
    }

    /// The 64-byte key used by Apple for segment encryption.
    /// This is the ASCII representation of "ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
    private static let encryptionKey: [UInt8] = [
        0x6f, 0x75, 0x72, 0x68, 0x61, 0x72, 0x64, 0x77, 0x6f, 0x72, 0x6b, 0x62, 0x79, 0x74, 0x68, 0x65,
        0x73, 0x65, 0x77, 0x6f, 0x72, 0x64, 0x73, 0x67, 0x75, 0x61, 0x72, 0x64, 0x65, 0x64, 0x70, 0x6c,
        0x65, 0x61, 0x73, 0x65, 0x64, 0x6f, 0x6e, 0x74, 0x73, 0x74, 0x65, 0x61, 0x6c, 0x28, 0x63, 0x29,
        0x41, 0x70, 0x70, 0x6c, 0x65, 0x43, 0x6f, 0x6d, 0x70, 0x75, 0x74, 0x65, 0x72, 0x49, 0x6e, 0x63,
    ]

    /// Detect the encryption type from segment data.
    /// - Parameters:
    ///   - data: The raw segment data
    ///   - isProtected: Whether the segment has the protected flag set
    /// - Returns: The detected encryption type
    public static func detectEncryptionType(data: Data, isProtected: Bool) -> SegmentEncryptionType {
        guard isProtected else { return .none }

        // First three pages aren't encrypted
        guard data.count > 3 * pageSize else {
            // Can't tell, assume AES (which we can decrypt)
            return .aes
        }

        let magicOffset = 3 * pageSize
        let magic = data.withUnsafeBytes { buffer -> UInt32 in
            buffer.load(fromByteOffset: magicOffset, as: UInt32.self).littleEndian
        }

        switch magic {
        case Magic.none: return .none
        case Magic.aes: return .aes
        case Magic.blowfish: return .blowfish
        default: return .unknown(magic)
        }
    }

    /// Decrypt a protected segment.
    /// - Parameter data: The raw segment data
    /// - Returns: Decrypted segment data
    /// - Throws: `SegmentDecryptionError` if decryption fails
    public static func decrypt(data: Data) throws -> Data {
        guard data.count % pageSize == 0 else {
            throw SegmentDecryptionError.invalidSegmentSize
        }

        // Check encryption type
        let encryptionType = detectEncryptionType(data: data, isProtected: true)

        switch encryptionType {
        case .none:
            return data
        case .aes:
            return try decryptAES(data: data)
        case .blowfish:
            return try decryptBlowfish(data: data)
        case .unknown(let magic):
            throw SegmentDecryptionError.unsupportedEncryption(magic)
        }
    }

    /// Decrypt using AES (10.5 encryption).
    private static func decryptAES(data: Data) throws -> Data {
        var result = Data(count: data.count)

        // Copy first 3 pages unencrypted
        let unencryptedSize = min(3 * pageSize, data.count)
        result.replaceSubrange(0..<unencryptedSize, with: data.subdata(in: 0..<unencryptedSize))

        guard data.count > 3 * pageSize else {
            return result
        }

        // Split the 64-byte key into two 32-byte AES keys
        let key1 = Array(encryptionKey[0..<32])
        let key2 = Array(encryptionKey[32..<64])

        let encryptedStart = 3 * pageSize
        let pageCount = (data.count / pageSize) - 3
        let halfPageSize = pageSize / 2

        for pageIndex in 0..<pageCount {
            let srcOffset = encryptedStart + pageIndex * pageSize
            let destOffset = srcOffset

            // Decrypt first half with key1
            try decryptAESBlock(
                source: data,
                sourceOffset: srcOffset,
                destination: &result,
                destOffset: destOffset,
                size: halfPageSize,
                key: key1
            )

            // Decrypt second half with key2
            try decryptAESBlock(
                source: data,
                sourceOffset: srcOffset + halfPageSize,
                destination: &result,
                destOffset: destOffset + halfPageSize,
                size: halfPageSize,
                key: key2
            )
        }

        return result
    }

    /// Decrypt a single AES block.
    private static func decryptAESBlock(
        source: Data,
        sourceOffset: Int,
        destination: inout Data,
        destOffset: Int,
        size: Int,
        key: [UInt8]
    ) throws {
        var cryptor: CCCryptorRef?

        var status = key.withUnsafeBufferPointer { keyBuffer in
            CCCryptorCreate(
                CCOperation(kCCDecrypt),
                CCAlgorithm(kCCAlgorithmAES),
                CCOptions(0),  // No padding, ECB mode
                keyBuffer.baseAddress,
                keyBuffer.count,
                nil,  // No IV for ECB
                &cryptor
            )
        }

        guard status == kCCSuccess, let cryptorRef = cryptor else {
            throw SegmentDecryptionError.aesError(status)
        }

        defer { CCCryptorRelease(cryptorRef) }

        var bytesDecrypted: Int = 0

        source.withUnsafeBytes { srcBuffer in
            let srcPtr = srcBuffer.baseAddress!.advanced(by: sourceOffset)

            destination.withUnsafeMutableBytes { destBuffer in
                let destPtr = destBuffer.baseAddress!.advanced(by: destOffset)

                status = CCCryptorUpdate(
                    cryptorRef,
                    srcPtr,
                    size,
                    destPtr,
                    size,
                    &bytesDecrypted
                )
            }
        }

        guard status == kCCSuccess && bytesDecrypted == size else {
            throw SegmentDecryptionError.aesError(status)
        }
    }

    /// Decrypt using Blowfish (10.6 encryption).
    /// Uses CBC mode with big-endian byte order.
    private static func decryptBlowfish(data: Data) throws -> Data {
        var result = Data(count: data.count)

        // Copy first 3 pages unencrypted
        let unencryptedSize = min(3 * pageSize, data.count)
        result.replaceSubrange(0..<unencryptedSize, with: data.subdata(in: 0..<unencryptedSize))

        guard data.count > 3 * pageSize else {
            return result
        }

        // Initialize Blowfish with the 64-byte key
        let blowfish = BlowfishLegacy(key: encryptionKey)

        let encryptedStart = 3 * pageSize
        let pageCount = (data.count / pageSize) - 3

        for pageIndex in 0..<pageCount {
            let srcOffset = encryptedStart + pageIndex * pageSize
            let destOffset = srcOffset

            // Decrypt the page using CBC mode
            decryptBlowfishPage(
                source: data,
                sourceOffset: srcOffset,
                destination: &result,
                destOffset: destOffset,
                blowfish: blowfish
            )
        }

        return result
    }

    /// Decrypt a single page using Blowfish CBC mode.
    private static func decryptBlowfishPage(
        source: Data,
        sourceOffset: Int,
        destination: inout Data,
        destOffset: Int,
        blowfish: BlowfishLegacy
    ) {
        var previousLeft: UInt32 = 0
        var previousRight: UInt32 = 0

        for blockIndex in 0..<(pageSize / 8) {
            let srcBlockOffset = sourceOffset + blockIndex * 8
            let destBlockOffset = destOffset + blockIndex * 8

            // Read big-endian values
            let left = source.withUnsafeBytes { buffer -> UInt32 in
                buffer.load(fromByteOffset: srcBlockOffset, as: UInt32.self).bigEndian
            }
            let right = source.withUnsafeBytes { buffer -> UInt32 in
                buffer.load(fromByteOffset: srcBlockOffset + 4, as: UInt32.self).bigEndian
            }

            // Decrypt
            var decryptedLeft = left
            var decryptedRight = right
            blowfish.decrypt(left: &decryptedLeft, right: &decryptedRight)

            // XOR with previous block (CBC mode)
            decryptedLeft ^= previousLeft
            decryptedRight ^= previousRight

            // Save current ciphertext for next block
            previousLeft = left
            previousRight = right

            // Write big-endian values
            destination.withUnsafeMutableBytes { buffer in
                buffer.storeBytes(of: decryptedLeft.bigEndian, toByteOffset: destBlockOffset, as: UInt32.self)
                buffer.storeBytes(of: decryptedRight.bigEndian, toByteOffset: destBlockOffset + 4, as: UInt32.self)
            }
        }
    }
}
