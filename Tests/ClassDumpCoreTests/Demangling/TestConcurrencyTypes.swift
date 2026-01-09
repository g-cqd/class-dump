// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

// MARK: - Swift Concurrency Type Demangling

@Suite("Swift Concurrency Type Demangling")
struct ConcurrencyTypeDemanglingTests {
    // MARK: - Task Types (42.1)

    @Test(
        "Task types with generic parameters demangle correctly",
        arguments: [
            // Task<Void, Never>
            ("ScTyytNeverG", "Task<Void, Never>"),
            // Task<String, Error>
            ("ScTySSs5ErrorpG", "Task<String, Error>"),
            // Task<Int, Never>
            ("ScTySiNeverG", "Task<Int, Never>"),
            // Task<Bool, Error>
            ("ScTySbs5ErrorpG", "Task<Bool, Error>"),
        ]
    )
    func taskTypesWithGenerics(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }

    @Test("Task type without generic parameters returns basic Task")
    func taskTypeBasic() {
        #expect(SwiftDemangler.demangle("ScT") == "Task")
    }

    // MARK: - Continuation Types (42.2)

    @Test(
        "Continuation types demangle correctly",
        arguments: [
            // CheckedContinuation
            ("ScC", "CheckedContinuation"),
            // UnsafeContinuation
            ("ScU", "UnsafeContinuation"),
        ]
    )
    func continuationTypes(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }

    // MARK: - Actor Types (42.3)

    @Test("Actor type demangles correctly")
    func actorType() {
        #expect(SwiftDemangler.demangle("ScA") == "Actor")
    }

    @Test("MainActor attribute recognized")
    func mainActorType() {
        #expect(SwiftDemangler.demangle("ScM") == "MainActor")
    }

    // MARK: - AsyncStream/AsyncSequence Types (42.4)

    @Test(
        "AsyncStream types demangle correctly",
        arguments: [
            ("ScS", "AsyncStream"),
            ("ScF", "AsyncThrowingStream"),
        ]
    )
    func asyncStreamTypes(mangled: String, expected: String) {
        #expect(SwiftDemangler.demangle(mangled) == expected)
    }

    // MARK: - TaskGroup Types

    @Test("TaskGroup type demangles correctly")
    func taskGroupType() {
        #expect(SwiftDemangler.demangle("Scg") == "TaskGroup")
    }

    @Test("ThrowingTaskGroup type demangles correctly")
    func throwingTaskGroupType() {
        #expect(SwiftDemangler.demangle("ScG") == "ThrowingTaskGroup")
    }

    // MARK: - TaskPriority

    @Test("TaskPriority type demangles correctly")
    func taskPriorityType() {
        #expect(SwiftDemangler.demangle("ScP") == "TaskPriority")
    }
}
