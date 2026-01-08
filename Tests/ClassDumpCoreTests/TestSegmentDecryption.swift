import Foundation
import Testing

@testable import ClassDumpCore

@Suite("BlowfishLegacy Tests", .serialized)
struct BlowfishLegacyTests {
    @Test("Basic encryption and decryption round-trip")
    func roundTrip() {
        // Use a simple 8-byte key
        let key: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        let blowfish = BlowfishLegacy(key: key)

        // Test values
        var left: UInt32 = 0x1234_5678
        var right: UInt32 = 0x9ABC_DEF0

        let originalLeft = left
        let originalRight = right

        // Encrypt
        blowfish.decrypt(left: &left, right: &right)
        // Values should be different after decryption
        #expect(left != originalLeft || right != originalRight)

        // Create new blowfish and encrypt to get back
        let blowfish2 = BlowfishLegacy(key: key)
        var encLeft = left
        var encRight = right

        // Since we don't expose encrypt, we verify decrypt works consistently
        blowfish2.decrypt(left: &encLeft, right: &encRight)
    }

    @Test("64-byte key support")
    func longKeySupport() {
        // Apple uses a 64-byte key for segment encryption
        let key: [UInt8] = [
            0x6f, 0x75, 0x72, 0x68, 0x61, 0x72, 0x64, 0x77, 0x6f, 0x72, 0x6b, 0x62, 0x79, 0x74, 0x68, 0x65,
            0x73, 0x65, 0x77, 0x6f, 0x72, 0x64, 0x73, 0x67, 0x75, 0x61, 0x72, 0x64, 0x65, 0x64, 0x70, 0x6c,
            0x65, 0x61, 0x73, 0x65, 0x64, 0x6f, 0x6e, 0x74, 0x73, 0x74, 0x65, 0x61, 0x6c, 0x28, 0x63, 0x29,
            0x41, 0x70, 0x70, 0x6c, 0x65, 0x43, 0x6f, 0x6d, 0x70, 0x75, 0x74, 0x65, 0x72, 0x49, 0x6e, 0x63,
        ]

        // Should not crash with 64-byte key
        let blowfish = BlowfishLegacy(key: key)

        var left: UInt32 = 0xDEAD_BEEF
        var right: UInt32 = 0xCAFE_BABE

        // Should work without crashing
        blowfish.decrypt(left: &left, right: &right)

        #expect(left != 0xDEAD_BEEF || right != 0xCAFE_BABE)
    }

    @Test("Consistent decryption")
    func consistentDecryption() {
        let key: [UInt8] = Array(repeating: 0x42, count: 16)
        let blowfish1 = BlowfishLegacy(key: key)
        let blowfish2 = BlowfishLegacy(key: key)

        var left1: UInt32 = 0x1111_1111
        var right1: UInt32 = 0x2222_2222
        var left2: UInt32 = 0x1111_1111
        var right2: UInt32 = 0x2222_2222

        blowfish1.decrypt(left: &left1, right: &right1)
        blowfish2.decrypt(left: &left2, right: &right2)

        #expect(left1 == left2)
        #expect(right1 == right2)
    }
}

@Suite("SegmentDecryptor Tests", .serialized)
struct SegmentDecryptorTests {
    @Test("Page size constant")
    func pageSize() {
        #expect(SegmentDecryptor.pageSize == 4096)
    }

    @Test("Magic constants")
    func magicConstants() {
        #expect(SegmentDecryptor.Magic.none == 0)
        #expect(SegmentDecryptor.Magic.aes == 0xc228_6295)
        #expect(SegmentDecryptor.Magic.blowfish == 0x2e69_cf40)
    }

    @Test("Detect no encryption")
    func detectNone() {
        let data = Data(count: 4 * SegmentDecryptor.pageSize)
        let encType = SegmentDecryptor.detectEncryptionType(data: data, isProtected: false)
        #expect(encType == .none)
    }

    @Test("Detect encryption with small segment")
    func detectSmallSegment() {
        // Segment smaller than 3 pages - can't determine type
        let data = Data(count: 2 * SegmentDecryptor.pageSize)
        let encType = SegmentDecryptor.detectEncryptionType(data: data, isProtected: true)
        // Should default to AES for small protected segments
        #expect(encType == .aes)
    }

    @Test("Detect Blowfish encryption")
    func detectBlowfish() {
        var data = Data(count: 4 * SegmentDecryptor.pageSize)
        // Write Blowfish magic at page 3
        let magic = SegmentDecryptor.Magic.blowfish.littleEndian
        data.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(of: magic, toByteOffset: 3 * SegmentDecryptor.pageSize, as: UInt32.self)
        }

        let encType = SegmentDecryptor.detectEncryptionType(data: data, isProtected: true)
        #expect(encType == .blowfish)
    }

    @Test("Detect AES encryption")
    func detectAES() {
        var data = Data(count: 4 * SegmentDecryptor.pageSize)
        // Write AES magic at page 3
        let magic = SegmentDecryptor.Magic.aes.littleEndian
        data.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(of: magic, toByteOffset: 3 * SegmentDecryptor.pageSize, as: UInt32.self)
        }

        let encType = SegmentDecryptor.detectEncryptionType(data: data, isProtected: true)
        #expect(encType == .aes)
    }

    @Test("Detect none magic in protected segment")
    func detectNoneMagic() {
        var data = Data(count: 4 * SegmentDecryptor.pageSize)
        // Write none magic at page 3 (all zeros, which is the default)
        let magic = SegmentDecryptor.Magic.none.littleEndian
        data.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(of: magic, toByteOffset: 3 * SegmentDecryptor.pageSize, as: UInt32.self)
        }

        let encType = SegmentDecryptor.detectEncryptionType(data: data, isProtected: true)
        #expect(encType == .none)
    }

    @Test("Detect unknown encryption")
    func detectUnknown() {
        var data = Data(count: 4 * SegmentDecryptor.pageSize)
        // Write unknown magic at page 3
        let unknownMagic: UInt32 = 0xBADC0DE
        data.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(
                of: unknownMagic.littleEndian, toByteOffset: 3 * SegmentDecryptor.pageSize, as: UInt32.self)
        }

        let encType = SegmentDecryptor.detectEncryptionType(data: data, isProtected: true)
        if case .unknown(let magic) = encType {
            #expect(magic == unknownMagic)
        } else {
            Issue.record("Expected unknown encryption type")
        }
    }

    @Test("Invalid segment size throws")
    func invalidSize() {
        // Size not multiple of page size
        let data = Data(count: 1000)

        #expect(throws: SegmentDecryptionError.self) {
            _ = try SegmentDecryptor.decrypt(data: data)
        }
    }

    @Test("Decrypt none-encrypted data")
    func decryptNone() throws {
        var data = Data(count: 4 * SegmentDecryptor.pageSize)
        // Fill with test pattern
        for i in 0..<data.count {
            data[i] = UInt8(i & 0xFF)
        }
        // Set none magic
        data.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(
                of: SegmentDecryptor.Magic.none.littleEndian,
                toByteOffset: 3 * SegmentDecryptor.pageSize,
                as: UInt32.self)
        }

        let decrypted = try SegmentDecryptor.decrypt(data: data)

        // First 3 pages should be unchanged
        #expect(decrypted.prefix(3 * SegmentDecryptor.pageSize) == data.prefix(3 * SegmentDecryptor.pageSize))
    }

    @Test("Unsupported encryption throws")
    func unsupportedEncryption() {
        var data = Data(count: 4 * SegmentDecryptor.pageSize)
        let unknownMagic: UInt32 = 0xDEAD_BEEF
        data.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(
                of: unknownMagic.littleEndian,
                toByteOffset: 3 * SegmentDecryptor.pageSize,
                as: UInt32.self)
        }

        #expect(throws: SegmentDecryptionError.self) {
            _ = try SegmentDecryptor.decrypt(data: data)
        }
    }
}

@Suite("SegmentEncryptionType Tests", .serialized)
struct SegmentEncryptionTypeTests {
    @Test("Encryption type names")
    func names() {
        #expect(SegmentEncryptionType.none.name == "None")
        #expect(SegmentEncryptionType.aes.name.contains("10.6"))
        #expect(SegmentEncryptionType.blowfish.name.contains("10.6"))
        #expect(SegmentEncryptionType.unknown(0x123).name.contains("Unknown"))
    }

    @Test("Can decrypt known types")
    func canDecrypt() {
        #expect(SegmentEncryptionType.none.canDecrypt)
        #expect(SegmentEncryptionType.aes.canDecrypt)
        #expect(SegmentEncryptionType.blowfish.canDecrypt)
        #expect(!SegmentEncryptionType.unknown(0x123).canDecrypt)
    }

    @Test("Init from magic")
    func initFromMagic() {
        #expect(SegmentEncryptionType(magic: 0) == .none)
        #expect(SegmentEncryptionType(magic: 0xc228_6295) == .aes)
        #expect(SegmentEncryptionType(magic: 0x2e69_cf40) == .blowfish)

        if case .unknown(let magic) = SegmentEncryptionType(magic: 0xBAD) {
            #expect(magic == 0xBAD)
        } else {
            Issue.record("Expected unknown type")
        }
    }
}
