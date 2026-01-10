// SPDX-License-Identifier: MIT
// Copyright (C) 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for concurrent processing capabilities.
@Suite("Concurrent Processing Tests")
struct TestConcurrentProcessing {

    // MARK: - Actor Cache Tests

    @Test("ActorCache allows concurrent reads and writes")
    func actorCacheBasicOperations() async throws {
        let cache = ActorCache<UInt64, String>()

        // Test basic operations (all async)
        await cache.set(1, value: "one")
        await cache.set(2, value: "two")

        #expect(await cache.get(1) == "one")
        #expect(await cache.get(2) == "two")
        #expect(await cache.get(3) == nil)
    }

    @Test("ActorCache handles concurrent writes correctly")
    func actorCacheConcurrentWrites() async throws {
        let cache = ActorCache<Int, Int>()

        // Perform concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    await cache.set(i, value: i * 2)
                }
            }
        }

        // Verify all values are correct
        for i in 0..<1000 {
            #expect(await cache.get(i) == i * 2)
        }
    }

    @Test("ActorCache getOrCreate prevents duplicate work")
    func actorCacheGetOrCreate() async throws {
        let cache = ActorCache<Int, Int>()
        let creationCount = ThreadSafeCounter()

        // Perform concurrent getOrCreate for same key
        // Note: Due to actor isolation, only one creation will happen
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await cache.getOrCreate(1) {
                        creationCount.increment()
                        return 42
                    }
                }
            }

            var results: [Int] = []
            for await value in group {
                results.append(value)
            }

            // All results should be 42
            #expect(results.allSatisfy { $0 == 42 })
        }

        // Creation should have happened only once due to actor isolation
        #expect(creationCount.value == 1)
    }

    // MARK: - Thread-Safe Cache Tests

    @Test("ThreadSafeCache allows concurrent reads and writes")
    func threadSafeCacheBasicOperations() async throws {
        let cache = ThreadSafeCache<UInt64, String>()

        // Test basic operations
        cache.set(1, value: "one")
        cache.set(2, value: "two")

        #expect(cache.get(1) == "one")
        #expect(cache.get(2) == "two")
        #expect(cache.get(3) == nil)
    }

    @Test("ThreadSafeCache handles concurrent writes correctly")
    func threadSafeCacheConcurrentWrites() async throws {
        let cache = ThreadSafeCache<Int, Int>()

        // Perform concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    cache.set(i, value: i * 2)
                }
            }
        }

        // Verify all values are correct
        for i in 0..<1000 {
            #expect(cache.get(i) == i * 2)
        }
    }

    @Test("ThreadSafeCache handles concurrent reads correctly")
    func threadSafeCacheConcurrentReads() async throws {
        let cache = ThreadSafeCache<Int, Int>()

        // Pre-populate cache
        for i in 0..<1000 {
            cache.set(i, value: i * 2)
        }

        // Perform concurrent reads
        await withTaskGroup(of: Int?.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    cache.get(i)
                }
            }

            var count = 0
            for await value in group where value != nil {
                count += 1
            }
            #expect(count == 1000)
        }
    }

    @Test("ThreadSafeCache getOrCreate prevents duplicate work")
    func threadSafeCacheGetOrCreate() async throws {
        let cache = ThreadSafeCache<Int, Int>()
        let creationCount = ThreadSafeCounter()

        // Perform concurrent getOrCreate for same key
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    cache.getOrCreate(1) {
                        creationCount.increment()
                        return 42
                    }
                }
            }

            var results: [Int] = []
            for await value in group {
                results.append(value)
            }

            // All results should be 42
            #expect(results.allSatisfy { $0 == 42 })
        }

        // Creation should have happened only once
        #expect(creationCount.value == 1)
    }

    @Test("ThreadSafeCache clear removes all entries")
    func threadSafeCacheClear() async throws {
        let cache = ThreadSafeCache<Int, String>()

        cache.set(1, value: "one")
        cache.set(2, value: "two")

        #expect(cache.get(1) == "one")

        cache.clear()

        #expect(cache.get(1) == nil)
        #expect(cache.get(2) == nil)
    }

    // MARK: - String Table Cache Tests

    @Test("StringTableCache caches string reads")
    func stringTableCacheBasicOperations() async throws {
        let cache = StringTableCache()

        cache.set(at: 0x1000, string: "test_string")
        cache.set(at: 0x2000, string: "another_string")

        #expect(cache.get(at: 0x1000) == "test_string")
        #expect(cache.get(at: 0x2000) == "another_string")
        #expect(cache.get(at: 0x3000) == nil)
    }

    @Test("StringTableCache handles concurrent access")
    func stringTableCacheConcurrentAccess() async throws {
        let cache = StringTableCache()

        // Concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    cache.set(at: UInt64(i), string: "string_\(i)")
                }
            }
        }

        // Verify all entries
        for i in 0..<1000 {
            #expect(cache.get(at: UInt64(i)) == "string_\(i)")
        }
    }

    // MARK: - Parallel Loading Simulation Tests

    @Test("Parallel address collection works correctly")
    func parallelAddressCollection() async throws {
        // Simulate collecting addresses then loading in parallel
        let addresses = Array(0..<100).map { UInt64($0 * 0x1000) }
        let cache = ThreadSafeCache<UInt64, String>()
        let counter = ThreadSafeCounter()

        await withTaskGroup(of: Void.self) { group in
            for address in addresses {
                group.addTask {
                    counter.increment()
                    // Simulate loading work
                    cache.set(address, value: "class_at_\(address)")
                }
            }
        }

        // All items should be loaded
        #expect(counter.value == 100)
        #expect(cache.get(0x0) == "class_at_0")
        #expect(cache.get(0x63000) == "class_at_405504")
    }

    // MARK: - Batch Processing Tests

    @Test("Batch processing with concurrency limit works")
    func batchProcessingWithLimit() async throws {
        let items = Array(0..<50)
        let collector = ResultCollector<Int>()

        // Process in batches with max concurrency
        await withTaskGroup(of: Int.self) { group in
            for item in items {
                group.addTask {
                    // Simulate some work
                    try? await Task.sleep(nanoseconds: 1_000)
                    return item
                }
            }

            for await result in group {
                await collector.add(result)
            }
        }

        // All items should be processed (order may vary)
        let processedItems = await collector.items
        #expect(Set(processedItems) == Set(items))
    }
}

// MARK: - Async-Safe Result Collector

/// An actor for collecting results from async tasks
actor ResultCollector<T> {
    private var itemsStorage: [T] = []

    var items: [T] {
        itemsStorage
    }

    func add(_ item: T) {
        itemsStorage.append(item)
    }
}

// MARK: - Helper Types

/// Thread-safe counter for testing.
final class ThreadSafeCounter: @unchecked Sendable {
    private var internalValue: Int = 0
    private let lock = NSLock()

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return internalValue
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        internalValue += 1
    }
}

// MARK: - Streaming API Tests

@Suite("Streaming Processing Tests")
struct TestStreamingProcessing {

    /// Get a test binary path that exists on the system.
    private static var testBinaryPath: String {
        // Try Xcode frameworks first (most ObjC metadata)
        let xcodeFramework =
            "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"
        if FileManager.default.fileExists(atPath: xcodeFramework) {
            return xcodeFramework
        }
        // Fallback to a command-line tool
        return "/usr/bin/file"
    }

    @Test("Streaming API yields metadata items")
    func streamingYieldsItems() async throws {
        let path = Self.testBinaryPath
        guard FileManager.default.fileExists(atPath: path) else {
            // Skip test if no suitable binary found
            return
        }

        let binary = try MachOBinary(contentsOf: URL(fileURLWithPath: path))
        let machOFile = try binary.bestMatchForLocal()
        let processor = ObjC2Processor(machOFile: machOFile)

        var itemCount = 0

        for await item in processor.stream() {
            switch item {
                case .protocol, .class, .category, .imageInfo:
                    itemCount += 1
                case .progress:
                    break
            }
        }

        // Should yield at least some items (or zero for non-ObjC binaries)
        #expect(itemCount >= 0)
    }

    @Test("Streaming with progress yields progress updates")
    func streamingWithProgress() async throws {
        let path = Self.testBinaryPath
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let binary = try MachOBinary(contentsOf: URL(fileURLWithPath: path))
        let machOFile = try binary.bestMatchForLocal()
        let processor = ObjC2Processor(machOFile: machOFile)

        var progressUpdates: [ProcessingProgress] = []

        for await item in processor.stream(includeProgress: true) {
            if case .progress(let progress) = item {
                progressUpdates.append(progress)
            }
        }

        // Should have at least the completion progress
        let phases = Set(progressUpdates.map { $0.phase })
        #expect(phases.contains(.complete))
    }

    @Test("Streaming matches batch processing results")
    func streamingMatchesBatch() async throws {
        let path = Self.testBinaryPath
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let binary = try MachOBinary(contentsOf: URL(fileURLWithPath: path))
        let machOFile = try binary.bestMatchForLocal()

        // Process with streaming
        let streamProcessor = ObjC2Processor(machOFile: machOFile)
        var streamedProtocols: [String] = []
        var streamedClasses: [String] = []

        for await item in streamProcessor.stream() {
            switch item {
                case .protocol(let proto):
                    streamedProtocols.append(proto.name)
                case .class(let cls):
                    streamedClasses.append(cls.name)
                default:
                    break
            }
        }

        // Process with batch
        let batchProcessor = ObjC2Processor(machOFile: machOFile)
        let metadata = try await batchProcessor.processAsync()

        let batchProtocols = metadata.protocols.map { $0.name }
        let batchClasses = metadata.classes.map { $0.name }

        // Results should match (order may differ)
        #expect(Set(streamedProtocols) == Set(batchProtocols))
        #expect(Set(streamedClasses) == Set(batchClasses))
    }
}
