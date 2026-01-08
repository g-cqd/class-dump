import Foundation

/// Byte order for reading multi-byte values.
public enum ByteOrder: Sendable {
    case little
    case big

    /// The native byte order of the current system.
    public static var native: ByteOrder {
        #if _endian(little)
            return .little
        #else
            return .big
        #endif
    }
}
