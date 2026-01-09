// SPDX-License-Identifier: MIT
// Copyright (C) 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Actor-Based Caches

/// An actor-based cache for storing key-value pairs with actor isolation.
///
/// This cache uses Swift's actor model for thread safety, providing
/// better integration with structured concurrency.
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

// MARK: - Lock-Based Caches (For Synchronous Code Paths)

/// A thread-safe cache for storing key-value pairs with concurrent access support.
///
/// This cache uses an NSLock for thread safety, suitable for synchronous code paths
/// that can't use async/await.
///
/// ## Usage
/// ```swift
/// let cache = ThreadSafeCache<UInt64, ObjCClass>()
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
///     // Create expensive value
///     return createClass()
/// }
/// ```
public final class ThreadSafeCache<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    private var storage: [Key: Value] = [:]
    private let lock = NSLock()

    public init() {}

    /// Get a value from the cache.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or nil if not present.
    public func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    /// Set a value in the cache.
    ///
    /// - Parameters:
    ///   - key: The key to store under.
    ///   - value: The value to store.
    public func set(_ key: Key, value: Value) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
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
        lock.lock()
        defer { lock.unlock() }

        if let existing = storage[key] {
            return existing
        }

        let value = create()
        storage[key] = value
        return value
    }

    /// Check if a key exists in the cache.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: True if the key exists.
    public func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] != nil
    }

    /// Remove a value from the cache.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or nil if not present.
    @discardableResult
    public func remove(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage.removeValue(forKey: key)
    }

    /// Clear all entries from the cache.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }

    /// Get the number of entries in the cache.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    /// Get all keys in the cache.
    public var keys: [Key] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.keys)
    }

    /// Get all values in the cache.
    public var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.values)
    }
}

/// A specialized thread-safe cache for string table lookups.
///
/// This cache is optimized for caching strings read from Mach-O string tables,
/// where the key is the file offset (address) of the string.
public final class StringTableCache: @unchecked Sendable {
    private var storage: [UInt64: String] = [:]
    private let lock = NSLock()

    public init() {}

    /// Get a cached string at the given address.
    ///
    /// - Parameter address: The address/offset of the string.
    /// - Returns: The cached string, or nil if not present.
    public func get(at address: UInt64) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[address]
    }

    /// Set a cached string at the given address.
    ///
    /// - Parameters:
    ///   - address: The address/offset of the string.
    ///   - string: The string to cache.
    public func set(at address: UInt64, string: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[address] = string
    }

    /// Get an existing string or read it using the provided closure.
    ///
    /// - Parameters:
    ///   - address: The address/offset of the string.
    ///   - read: A closure that reads the string from the binary.
    /// - Returns: The cached or newly read string, or nil if read fails.
    public func getOrRead(at address: UInt64, read: () -> String?) -> String? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = storage[address] {
            return cached
        }

        if let string = read() {
            storage[address] = string
            return string
        }

        return nil
    }

    /// Clear all cached strings.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }

    /// Get the number of cached strings.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}

/// A thread-safe cache for type encoding parsing results.
///
/// This cache stores parsed ObjC types to avoid re-parsing the same
/// type encoding strings multiple times.
public final class TypeEncodingCache: @unchecked Sendable {
    private var storage: [String: ObjCType] = [:]
    private let lock = NSLock()

    public init() {}

    /// Get a cached parsed type for the given encoding.
    ///
    /// - Parameter encoding: The ObjC type encoding string.
    /// - Returns: The cached parsed type, or nil if not present.
    public func get(encoding: String) -> ObjCType? {
        lock.lock()
        defer { lock.unlock() }
        return storage[encoding]
    }

    /// Set a cached parsed type for the given encoding.
    ///
    /// - Parameters:
    ///   - encoding: The ObjC type encoding string.
    ///   - type: The parsed type to cache.
    public func set(encoding: String, type: ObjCType) {
        lock.lock()
        defer { lock.unlock() }
        storage[encoding] = type
    }

    /// Get an existing parsed type or parse it using the provided closure.
    ///
    /// - Parameters:
    ///   - encoding: The ObjC type encoding string.
    ///   - parse: A closure that parses the type if not cached.
    /// - Returns: The cached or newly parsed type, or nil if parsing fails.
    public func getOrParse(encoding: String, parse: () -> ObjCType?) -> ObjCType? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = storage[encoding] {
            return cached
        }

        if let parsed = parse() {
            storage[encoding] = parsed
            return parsed
        }

        return nil
    }

    /// Clear all cached types.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }

    /// Get the number of cached types.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}
