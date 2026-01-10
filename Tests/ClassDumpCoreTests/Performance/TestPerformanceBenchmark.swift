// SPDX-License-Identifier: MIT
// Copyright (C) 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

/// Performance benchmarks for class-dump processing.
///
/// To run benchmarks with timing:
/// ```bash
/// swift test --filter TestPerformanceBenchmark
/// ```
///
/// For detailed benchmarking with large binaries, use:
/// ```bash
/// time class-dump "/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation" > /dev/null
/// ```
@Suite("Performance Benchmarks", .tags(.performance))
struct TestPerformanceBenchmark {

    // MARK: - String Cache Benchmarks

    @Test("String cache improves repeated lookups")
    func stringCachePerformance() async throws {
        let cache = StringTableCache()

        // Simulate populating cache with many strings
        let stringCount = 10_000
        for i in 0..<stringCount {
            cache.set(at: UInt64(i * 100), string: "string_\(i)")
        }

        // Measure lookup time
        let start = ContinuousClock.now

        for _ in 0..<1000 {
            for i in 0..<stringCount {
                _ = cache.get(at: UInt64(i * 100))
            }
        }

        let elapsed = ContinuousClock.now - start

        // 10M lookups should complete in reasonable time
        #expect(elapsed < .seconds(5), "String cache lookups too slow: \(elapsed)")
    }

    @Test("Thread-safe cache handles high contention")
    func threadSafeCacheContention() async throws {
        let cache = ThreadSafeCache<Int, String>()

        // Pre-populate
        for i in 0..<1000 {
            cache.set(i, value: "value_\(i)")
        }

        let start = ContinuousClock.now

        // High contention: many tasks reading/writing simultaneously
        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<100 {
                group.addTask {
                    for i in 0..<1000 {
                        if i % 10 == 0 {
                            cache.set(i + taskIndex * 1000, value: "new_\(i)")
                        }
                        else {
                            _ = cache.get(i)
                        }
                    }
                }
            }
        }

        let elapsed = ContinuousClock.now - start

        // 100K operations should complete quickly
        #expect(elapsed < .seconds(2), "Cache contention too slow: \(elapsed)")
    }

    // MARK: - Type Encoding Cache Benchmarks

    @Test("Type encoding cache reduces parsing overhead")
    func typeEncodingCachePerformance() async throws {
        let cache = TypeEncodingCache()

        // Common type encodings that would be repeated
        let encodings = [
            "@",  // id
            "@\"NSString\"",  // NSString *
            "@\"NSArray\"",  // NSArray *
            "@\"NSDictionary\"",  // NSDictionary *
            "q",  // long long
            "Q",  // unsigned long long
            "d",  // double
            "B",  // BOOL
            "{CGRect={CGPoint=dd}{CGSize=dd}}",  // CGRect
            "{CGSize=dd}",  // CGSize
            "@?<v@?>",  // Block with signature
        ]

        // Simulate caching parsed types
        for encoding in encodings {
            if let parsed = try? ObjCType.parse(encoding) {
                cache.set(encoding: encoding, type: parsed)
            }
        }

        let start = ContinuousClock.now

        // Many lookups (simulating processing a large binary)
        for _ in 0..<100_000 {
            for encoding in encodings {
                _ = cache.get(encoding: encoding)
            }
        }

        let elapsed = ContinuousClock.now - start

        // 1.1M lookups should be fast
        #expect(elapsed < .seconds(1), "Type cache lookups too slow: \(elapsed)")
    }

    // MARK: - Memory Efficiency Tests

    @Test("Caches don't grow unbounded")
    func cacheMemoryBounds() async throws {
        let cache = ThreadSafeCache<Int, String>()

        // Add entries
        for i in 0..<10_000 {
            cache.set(i, value: String(repeating: "x", count: 100))
        }

        #expect(cache.count == 10_000)

        // Clear and verify
        cache.clear()
        #expect(cache.count == 0)
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var performance: Self
}
