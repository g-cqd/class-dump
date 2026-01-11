import Foundation
import Synchronization

// MARK: - Mutex-Based Caches (Swift 6 Synchronization Framework)

/// A thread-safe cache using the Swift Synchronization framework's Mutex.
///
/// This cache uses `Mutex<T>` for thread safety, providing:
/// - Automatic `Sendable` conformance (no `@unchecked` needed)
/// - Minimal overhead compared to actors (no suspension points)
/// - Reference semantics (shared across tasks)
///
/// ## Usage
/// ```swift
/// let cache = MutexCache<UInt64, ObjCClass>()
///
/// // Set a value
/// cache.set(0x1000, value: myClass)
///
/// // Get a value
/// if let cached = cache.get(0x1000) {
///     // Use cached value
/// }
///
/// // Get or create (atomic operation)
/// let value = cache.getOrCreate(0x2000) {
///     return createClass()
/// }
/// ```
public final class MutexCache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private let storage: Mutex<[Key: Value]>

    /// Initialize an empty cache.
    public init() {
        self.storage = Mutex([:])
    }

    /// Get a value from the cache.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or nil if not present.
    public func get(_ key: Key) -> Value? {
        storage.withLock { $0[key] }
    }

    /// Set a value in the cache.
    ///
    /// - Parameters:
    ///   - key: The key to store under.
    ///   - value: The value to store.
    public func set(_ key: Key, value: Value) {
        storage.withLock { $0[key] = value }
    }

    /// Get an existing value or create a new one atomically.
    ///
    /// This operation is atomic - the create closure will only be called
    /// if the key doesn't exist, and concurrent calls for the same key
    /// will result in only one creation.
    ///
    /// - Parameters:
    ///   - key: The key to look up or create.
    ///   - create: A closure that creates the value if not present.
    /// - Returns: The existing or newly created value.
    public func getOrCreate(_ key: Key, create: () -> Value) -> Value {
        storage.withLock { dict in
            if let existing = dict[key] {
                return existing
            }
            let value = create()
            dict[key] = value
            return value
        }
    }

    /// Check if a key exists in the cache.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: True if the key exists.
    public func contains(_ key: Key) -> Bool {
        storage.withLock { $0[key] != nil }
    }

    /// Remove a value from the cache.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or nil if not present.
    @discardableResult
    public func remove(_ key: Key) -> Value? {
        storage.withLock { $0.removeValue(forKey: key) }
    }

    /// Clear all entries from the cache.
    public func clear() {
        storage.withLock { $0.removeAll() }
    }

    /// Get the number of entries in the cache.
    public var count: Int {
        storage.withLock { $0.count }
    }

    /// Get all keys in the cache.
    public var keys: [Key] {
        storage.withLock { Array($0.keys) }
    }

    /// Get all values in the cache.
    public var values: [Value] {
        storage.withLock { Array($0.values) }
    }

    // MARK: - Lock-Scoped Operations

    /// Execute an action with exclusive access to the underlying storage.
    ///
    /// Use this for compound operations that need atomicity, such as
    /// check-then-act patterns or multiple reads/writes that must be consistent.
    ///
    /// - Parameter action: A closure that receives mutable access to the dictionary.
    /// - Returns: The value returned by the action.
    ///
    /// ## Example
    /// ```swift
    /// // Atomic check-and-set with return value
    /// let (cached, count) = cache.withLock { dict -> (String?, Int) in
    ///     if let existing = dict[key] {
    ///         return (existing, dict.count)
    ///     }
    ///     dict[key] = newValue
    ///     return (nil, dict.count)
    /// }
    /// ```
    public func withLock<T>(_ action: (inout [Key: Value]) -> T) -> T {
        storage.withLock { dict in
            action(&dict)
        }
    }

    /// Execute a throwing action with exclusive access to the underlying storage.
    ///
    /// - Parameter action: A throwing closure that receives mutable access to the dictionary.
    /// - Returns: The value returned by the action.
    /// - Throws: Any error thrown by the action.
    public func withLockThrowing<T>(_ action: (inout [Key: Value]) throws -> T) rethrows -> T {
        try storage.withLock { dict in
            try action(&dict)
        }
    }
}

// MARK: - Type Aliases for Backward Compatibility

/// A thread-safe cache for storing key-value pairs.
///
/// Now backed by `MutexCache` using the Swift Synchronization framework.
public typealias ThreadSafeCache<Key: Hashable & Sendable, Value: Sendable> = MutexCache<Key, Value>

// MARK: - Specialized Caches

/// Mutex-based string interner for synchronous contexts.
///
/// Deduplicates string content so that identical strings share memory,
/// regardless of where they were read from. This is particularly effective
/// for ObjC metadata where selector names like "init", "dealloc", etc.
/// appear across hundreds of classes.
///
/// ## Usage
/// ```swift
/// let interner = MutexStringInterner()
/// let s1 = interner.intern("init")
/// let s2 = interner.intern("init")  // Same underlying storage as s1
/// ```
///
/// ## Performance Characteristics
/// - O(1) average lookup time (hash table)
/// - Thread-safe via Mutex (minimal overhead for sync access)
/// - Memory savings: 60-80% for typical binaries with repeated selectors
public final class MutexStringInterner: Sendable {
    /// Storage uses a struct to hold both the intern table and hit count.
    private struct State: Sendable {
        var table: [String: String] = [:]
        var hitCount: Int = 0
    }

    private let state: Mutex<State>

    /// Initialize an empty interner.
    public init() {
        self.state = Mutex(State())
    }

    /// Intern a string, returning the canonical version.
    ///
    /// If this string content has been seen before, returns the previously
    /// stored instance (deduplicating memory). Otherwise, stores and returns
    /// the provided string.
    ///
    /// - Parameter string: The string to intern.
    /// - Returns: The canonical interned string with the same content.
    public func intern(_ string: String) -> String {
        state.withLock { state in
            if let existing = state.table[string] {
                state.hitCount += 1
                return existing
            }
            state.table[string] = string
            return string
        }
    }

    /// Get statistics about the interner.
    ///
    /// - Returns: Tuple of (unique strings count, hit count for reuse).
    public var stats: (uniqueCount: Int, hitCount: Int) {
        state.withLock { s in (s.table.count, s.hitCount) }
    }

    /// Clear all interned strings.
    public func clear() {
        state.withLock { state in
            state.table.removeAll()
            state.hitCount = 0
        }
    }
}

/// A specialized thread-safe cache for string table lookups with automatic interning.
///
/// This cache is optimized for caching strings read from Mach-O string tables,
/// where the key is the file offset (address) of the string. It automatically
/// interns all strings to deduplicate memory for repeated content.
///
/// ## Memory Optimization
/// When the same string content appears at different addresses (e.g., "init"
/// selector in multiple classes), the interner ensures they share memory.
/// This typically saves 60-80% memory for string storage in ObjC binaries.
public final class StringTableCache: Sendable {
    /// Storage holds both address-to-string mapping and the interner.
    private struct State: Sendable {
        var cache: [UInt64: String] = [:]
        var internTable: [String: String] = [:]
        var internHitCount: Int = 0
    }

    private let state: Mutex<State>

    /// Initialize an empty cache.
    public init() {
        self.state = Mutex(State())
    }

    /// Get a cached string at the given address.
    ///
    /// - Parameter address: The address/offset of the string.
    /// - Returns: The cached string, or nil if not present.
    public func get(at address: UInt64) -> String? {
        state.withLock { $0.cache[address] }
    }

    /// Set a cached string at the given address.
    ///
    /// The string is automatically interned to deduplicate memory.
    ///
    /// - Parameters:
    ///   - address: The address/offset of the string.
    ///   - string: The string to cache.
    public func set(at address: UInt64, string: String) {
        state.withLock { state in
            let interned = intern(string, state: &state)
            state.cache[address] = interned
        }
    }

    /// Get an existing string or read it using the provided closure.
    ///
    /// The read string is automatically interned to deduplicate memory.
    ///
    /// - Parameters:
    ///   - address: The address/offset of the string.
    ///   - read: A closure that reads the string from the binary.
    /// - Returns: The cached or newly read string, or nil if read fails.
    public func getOrRead(at address: UInt64, read: () -> String?) -> String? {
        state.withLock { state in
            if let cached = state.cache[address] {
                return cached
            }
            if let string = read() {
                let interned = intern(string, state: &state)
                state.cache[address] = interned
                return interned
            }
            return nil
        }
    }

    /// Intern a string within the state lock.
    private func intern(_ string: String, state: inout State) -> String {
        if let existing = state.internTable[string] {
            state.internHitCount += 1
            return existing
        }
        state.internTable[string] = string
        return string
    }

    /// Clear all cached strings and interned strings.
    public func clear() {
        state.withLock { state in
            state.cache.removeAll()
            state.internTable.removeAll()
            state.internHitCount = 0
        }
    }

    /// Get the number of cached string addresses.
    public var count: Int {
        state.withLock { $0.cache.count }
    }

    /// Get statistics about string interning.
    ///
    /// - Returns: Tuple of (unique string count, intern cache hit count).
    public var internStats: (uniqueCount: Int, hitCount: Int) {
        state.withLock { ($0.internTable.count, $0.internHitCount) }
    }
}

/// A thread-safe cache for type encoding parsing results.
///
/// This cache stores parsed ObjC types to avoid re-parsing the same
/// type encoding strings multiple times.
public final class TypeEncodingCache: Sendable {
    private let storage: Mutex<[String: ObjCType]>

    /// Initialize an empty cache.
    public init() {
        self.storage = Mutex([:])
    }

    /// Get a cached parsed type for the given encoding.
    ///
    /// - Parameter encoding: The ObjC type encoding string.
    /// - Returns: The cached parsed type, or nil if not present.
    public func get(encoding: String) -> ObjCType? {
        storage.withLock { $0[encoding] }
    }

    /// Set a cached parsed type for the given encoding.
    ///
    /// - Parameters:
    ///   - encoding: The ObjC type encoding string.
    ///   - type: The parsed type to cache.
    public func set(encoding: String, type: ObjCType) {
        storage.withLock { $0[encoding] = type }
    }

    /// Get an existing parsed type or parse it using the provided closure.
    ///
    /// - Parameters:
    ///   - encoding: The ObjC type encoding string.
    ///   - parse: A closure that parses the type if not cached.
    /// - Returns: The cached or newly parsed type, or nil if parsing fails.
    public func getOrParse(encoding: String, parse: () -> ObjCType?) -> ObjCType? {
        storage.withLock { dict in
            if let cached = dict[encoding] {
                return cached
            }
            if let parsed = parse() {
                dict[encoding] = parsed
                return parsed
            }
            return nil
        }
    }

    /// Clear all cached types.
    public func clear() {
        storage.withLock { $0.removeAll() }
    }

    /// Get the number of cached types.
    public var count: Int {
        storage.withLock { $0.count }
    }
}

/// A thread-safe cache for method type encoding parsing results.
///
/// This cache stores parsed method types (return type + arguments) to avoid
/// re-parsing the same method type encoding strings multiple times.
/// Method encodings like "@24@0:8@16" are commonly repeated across many methods.
public final class MethodTypeCache: Sendable {
    private let storage: Mutex<[String: [ObjCMethodType]]>

    /// Initialize an empty cache.
    public init() {
        self.storage = Mutex([:])
    }

    /// Get a cached parsed method type for the given encoding.
    ///
    /// - Parameter encoding: The ObjC method type encoding string.
    /// - Returns: The cached parsed method types, or nil if not present.
    public func get(encoding: String) -> [ObjCMethodType]? {
        storage.withLock { $0[encoding] }
    }

    /// Set a cached parsed method type for the given encoding.
    ///
    /// - Parameters:
    ///   - encoding: The ObjC method type encoding string.
    ///   - types: The parsed method types to cache.
    public func set(encoding: String, types: [ObjCMethodType]) {
        storage.withLock { $0[encoding] = types }
    }

    /// Get an existing parsed method type or parse it using the provided closure.
    ///
    /// Uses double-checked locking: checks cache, releases lock during parsing,
    /// then re-checks before storing to handle concurrent parses of the same encoding.
    ///
    /// - Parameters:
    ///   - encoding: The ObjC method type encoding string.
    ///   - parse: A closure that parses the method type if not cached.
    /// - Returns: The cached or newly parsed method types.
    /// - Throws: If parsing fails.
    public func getOrParse(encoding: String, parse: () throws -> [ObjCMethodType]) throws -> [ObjCMethodType] {
        // First check: fast path if already cached
        if let cached = storage.withLock({ $0[encoding] }) {
            return cached
        }

        // Parse outside the lock to avoid holding it during expensive operations
        let parsed = try parse()

        // Second check: another thread may have parsed while we were parsing
        return storage.withLock { dict in
            if let cached = dict[encoding] {
                return cached
            }
            dict[encoding] = parsed
            return parsed
        }
    }

    /// Clear all cached method types.
    public func clear() {
        storage.withLock { $0.removeAll() }
    }

    /// Get the number of cached method types.
    public var count: Int {
        storage.withLock { $0.count }
    }
}

// MARK: - Actor-Based Cache (For Async Contexts)

/// An actor-based cache for storing key-value pairs with actor isolation.
///
/// Use this when you need cache access from async contexts and want
/// to leverage Swift's structured concurrency. For high-frequency
/// synchronous access, prefer `MutexCache` instead.
///
/// ## Usage
/// ```swift
/// let cache = ActorCache<UInt64, ObjCClass>()
///
/// // Set a value (async)
/// await cache.set(0x1000, value: myClass)
///
/// // Get a value (async)
/// if let cached = await cache.get(0x1000) {
///     // Use cached value
/// }
/// ```
public actor ActorCache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: Value] = [:]

    /// Initialize an empty cache.
    public init() {}

    /// Get a value from the cache.
    public func get(_ key: Key) -> Value? {
        storage[key]
    }

    /// Set a value in the cache.
    public func set(_ key: Key, value: Value) {
        storage[key] = value
    }

    /// Get an existing value or create a new one.
    public func getOrCreate(_ key: Key, create: () -> Value) -> Value {
        if let existing = storage[key] {
            return existing
        }
        let value = create()
        storage[key] = value
        return value
    }

    /// Check if a key exists in the cache.
    public func contains(_ key: Key) -> Bool {
        storage[key] != nil
    }

    /// Remove a value from the cache.
    @discardableResult
    public func remove(_ key: Key) -> Value? {
        storage.removeValue(forKey: key)
    }

    /// Clear all entries from the cache.
    public func clear() {
        storage.removeAll()
    }

    /// Get the number of entries in the cache.
    public var count: Int {
        storage.count
    }

    /// Get all keys in the cache.
    public var keys: [Key] {
        Array(storage.keys)
    }

    /// Get all values in the cache.
    public var values: [Value] {
        Array(storage.values)
    }
}

// MARK: - String Interner (Memory Optimization)

/// Actor-based string interner for deduplicating repeated strings.
///
/// String interning reduces memory usage by ensuring that identical string
/// content shares a single underlying storage. This is particularly effective
/// for selector names, type names, and other strings that appear many times
/// in a binary (e.g., "init" appears in hundreds of classes).
///
/// ## Usage
/// ```swift
/// let interner = StringInterner()
///
/// // Intern a string - returns canonical version
/// let s1 = await interner.intern("init")
/// let s2 = await interner.intern("init")  // Same underlying storage as s1
///
/// // Check stats
/// let (count, hits) = await interner.stats
/// print("Interned \(count) unique strings, \(hits) cache hits")
/// ```
///
/// ## Performance Characteristics
/// - O(1) average lookup time (hash table)
/// - Thread-safe via actor isolation
/// - Memory savings: 60-80% for typical binaries with repeated selectors
public actor StringInterner {
    /// Storage: maps string content to the canonical interned instance.
    private var storage: [String: String] = [:]

    /// Track cache hits (for debugging/profiling).
    private var hitCount: Int = 0

    /// Initialize an empty interner.
    public init() {}

    /// Intern a string, returning the canonical version.
    ///
    /// If this string content has been seen before, returns the previously
    /// stored instance (deduplicating memory). Otherwise, stores and returns
    /// the provided string.
    ///
    /// - Parameter string: The string to intern.
    /// - Returns: The canonical interned string with the same content.
    public func intern(_ string: String) -> String {
        if let existing = storage[string] {
            hitCount += 1
            return existing
        }
        storage[string] = string
        return string
    }

    /// Intern a string if it's not nil.
    ///
    /// Convenience method for optional strings.
    ///
    /// - Parameter string: The optional string to intern.
    /// - Returns: The interned string or nil.
    public func intern(_ string: String?) -> String? {
        guard let s = string else { return nil }
        return intern(s)
    }

    /// Get statistics about the interner.
    ///
    /// - Returns: Tuple of (unique strings count, hit count for reuse).
    public var stats: (uniqueCount: Int, hitCount: Int) {
        (storage.count, hitCount)
    }

    /// Clear all interned strings.
    public func clear() {
        storage.removeAll()
        hitCount = 0
    }
}
