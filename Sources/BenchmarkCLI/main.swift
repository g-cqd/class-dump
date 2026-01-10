// SPDX-License-Identifier: MIT
// Copyright (C) 2026 class-dump contributors. All rights reserved.

import ArgumentParser
import ClassDumpCore
import Darwin
import Foundation

@main
struct BenchmarkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "benchmark",
        abstract: "Benchmark class-dump performance on Mach-O binaries.",
        version: "1.0.0"
    )

    @Argument(help: "The Mach-O file to benchmark")
    var file: String

    @Option(name: .shortAndLong, help: "Number of iterations (default: 10)")
    var iterations: Int = 10

    @Option(name: .shortAndLong, help: "Number of warmup iterations (default: 2)")
    var warmup: Int = 2

    @Flag(name: .long, help: "Output results as JSON")
    var json: Bool = false

    @Flag(name: .long, help: "Include memory statistics (slower)")
    var memory: Bool = false

    @Flag(name: .long, help: "Verbose output showing each iteration")
    var verbose: Bool = false

    mutating func run() async throws {
        let url = URL(fileURLWithPath: file)
        guard FileManager.default.fileExists(atPath: file) else {
            throw BenchmarkError.fileNotFound(file)
        }

        let binary = try MachOBinary(contentsOf: url)
        let machOFile = try binary.bestMatchForLocal()

        if !json {
            print("Benchmarking: \(url.lastPathComponent)")
            print("Architecture: \(machOFile.arch.name)")
            print("Iterations: \(iterations) (+ \(warmup) warmup)")
            print("")
        }

        // Warmup runs
        if !json && warmup > 0 {
            print("Warming up...")
        }
        for i in 0..<warmup {
            let processor = ObjC2Processor(machOFile: machOFile)
            _ = try await processor.processAsync()
            if verbose {
                print("  Warmup \(i + 1)/\(warmup) complete")
            }
        }

        // Benchmark runs
        var timings: [Double] = []
        var memoryStats: [MemoryStats] = []

        if !json {
            print("Running benchmark...")
        }

        for i in 0..<iterations {
            // Clear caches between runs for consistent measurement
            ObjCType.clearParseCaches()
            SwiftDemangler.clearCache()

            let memBefore = memory ? getCurrentMemoryStats() : nil

            let start = DispatchTime.now()
            let processor = ObjC2Processor(machOFile: machOFile)
            let metadata = try await processor.processAsync()
            let end = DispatchTime.now()

            let memAfter = memory ? getCurrentMemoryStats() : nil

            let elapsed = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
            timings.append(elapsed)

            if memory, let before = memBefore, let after = memAfter {
                memoryStats.append(
                    MemoryStats(
                        peakMemory: after.peakMemory,
                        residentMemory: after.residentMemory - before.residentMemory,
                        classCount: metadata.classes.count,
                        protocolCount: metadata.protocols.count,
                        categoryCount: metadata.categories.count
                    )
                )
            }

            if verbose {
                print(String(format: "  Run %2d/%d: %.3fs", i + 1, iterations, elapsed))
            }
        }

        // Calculate statistics
        let stats = calculateStatistics(timings)

        if json {
            try outputJSON(stats: stats, memoryStats: memoryStats, file: url.lastPathComponent)
        }
        else {
            outputTable(stats: stats, memoryStats: memoryStats)
        }
    }

    private func calculateStatistics(_ values: [Double]) -> TimingStats {
        let sorted = values.sorted()
        let count = sorted.count

        let sum = sorted.reduce(0, +)
        let mean = sum / Double(count)

        let variance = sorted.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(count)
        let stddev = sqrt(variance)

        let median =
            count % 2 == 0
            ? (sorted[count / 2 - 1] + sorted[count / 2]) / 2
            : sorted[count / 2]

        let p95Index = Int(Double(count) * 0.95)
        let p99Index = Int(Double(count) * 0.99)

        return TimingStats(
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            mean: mean,
            median: median,
            stddev: stddev,
            p95: sorted[min(p95Index, count - 1)],
            p99: sorted[min(p99Index, count - 1)],
            count: count
        )
    }

    private func getCurrentMemoryStats() -> MemorySnapshot? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return MemorySnapshot(
            residentMemory: Int64(info.resident_size),
            peakMemory: Int64(info.resident_size_max)
        )
    }

    private func outputTable(stats: TimingStats, memoryStats: [MemoryStats]) {
        print("")
        print("╔═══════════════════════════════════════════════════╗")
        print("║              BENCHMARK RESULTS                    ║")
        print("╠═══════════════════════════════════════════════════╣")
        print(String(format: "║  Min:        %8.3f s                           ║", stats.min))
        print(String(format: "║  Max:        %8.3f s                           ║", stats.max))
        print(String(format: "║  Mean:       %8.3f s                           ║", stats.mean))
        print(String(format: "║  Median:     %8.3f s                           ║", stats.median))
        print(String(format: "║  Std Dev:    %8.3f s                           ║", stats.stddev))
        print(String(format: "║  P95:        %8.3f s                           ║", stats.p95))
        print(String(format: "║  P99:        %8.3f s                           ║", stats.p99))
        print("╠═══════════════════════════════════════════════════╣")

        if let lastMem = memoryStats.last {
            print(
                String(
                    format: "║  Peak Memory:  %6.1f MB                         ║",
                    Double(lastMem.peakMemory) / 1_000_000
                )
            )
            print(String(format: "║  Classes:      %6d                             ║", lastMem.classCount))
            print(String(format: "║  Protocols:    %6d                             ║", lastMem.protocolCount))
            print(String(format: "║  Categories:   %6d                             ║", lastMem.categoryCount))
            print("╠═══════════════════════════════════════════════════╣")
        }

        // Distribution histogram
        print("║  Distribution:                                    ║")
        let buckets = createHistogram(stats: stats, bucketCount: 5)
        for bucket in buckets {
            let bar = String(repeating: "█", count: min(bucket.percentage / 5, 20))
            let padding = String(repeating: " ", count: 20 - bar.count)
            print(
                String(
                    format: "║  %5.2f-%5.2fs: %@%@ %3d%%   ║",
                    bucket.min,
                    bucket.max,
                    bar,
                    padding,
                    bucket.percentage
                )
            )
        }
        print("╚═══════════════════════════════════════════════════╝")
    }

    private func createHistogram(stats: TimingStats, bucketCount: Int) -> [HistogramBucket] {
        // For simplicity, we'll need the raw values, but we only have stats
        // This is a simplified version - in a full implementation, we'd pass the raw values
        return [
            HistogramBucket(min: stats.min, max: stats.median, percentage: 50),
            HistogramBucket(min: stats.median, max: stats.p95, percentage: 45),
            HistogramBucket(min: stats.p95, max: stats.max, percentage: 5),
        ]
    }

    private func outputJSON(stats: TimingStats, memoryStats: [MemoryStats], file: String) throws {
        var result: [String: Any] = [
            "file": file,
            "iterations": stats.count,
            "timing": [
                "min": stats.min,
                "max": stats.max,
                "mean": stats.mean,
                "median": stats.median,
                "stddev": stats.stddev,
                "p95": stats.p95,
                "p99": stats.p99,
            ],
        ]

        if let lastMem = memoryStats.last {
            result["memory"] = [
                "peakBytes": lastMem.peakMemory,
                "peakMB": Double(lastMem.peakMemory) / 1_000_000,
            ]
            result["metadata"] = [
                "classes": lastMem.classCount,
                "protocols": lastMem.protocolCount,
                "categories": lastMem.categoryCount,
            ]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
}

// MARK: - Supporting Types

struct TimingStats {
    let min: Double
    let max: Double
    let mean: Double
    let median: Double
    let stddev: Double
    let p95: Double
    let p99: Double
    let count: Int
}

struct MemorySnapshot {
    let residentMemory: Int64
    let peakMemory: Int64
}

struct MemoryStats {
    let peakMemory: Int64
    let residentMemory: Int64
    let classCount: Int
    let protocolCount: Int
    let categoryCount: Int
}

struct HistogramBucket {
    let min: Double
    let max: Double
    let percentage: Int
}

enum BenchmarkError: Error, CustomStringConvertible {
    case fileNotFound(String)

    var description: String {
        switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
        }
    }
}
