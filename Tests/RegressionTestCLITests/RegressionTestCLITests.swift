import Foundation
import Testing

@testable import RegressionTestCLI

@Suite("RegressionTestCLI Tests")
struct RegressionTestCLITests {
    @Suite("TargetCollection Tests")
    struct TargetCollectionTests {
        @Test("Total counts all targets")
        func testTotal() {
            let collection = TargetCollection(
                frameworks: [
                    URL(fileURLWithPath: "/System/Library/Frameworks/Foundation.framework"),
                    URL(fileURLWithPath: "/System/Library/Frameworks/AppKit.framework"),
                ],
                apps: [
                    URL(fileURLWithPath: "/Applications/Safari.app")
                ],
                bundles: [
                    URL(fileURLWithPath: "/System/Library/CoreServices/Finder.bundle")
                ]
            )

            #expect(collection.total == 4)
            #expect(collection.frameworks.count == 2)
            #expect(collection.apps.count == 1)
            #expect(collection.bundles.count == 1)
        }

        @Test("Empty collection has zero total")
        func testEmptyCollection() {
            let collection = TargetCollection(
                frameworks: [],
                apps: [],
                bundles: []
            )

            #expect(collection.total == 0)
        }
    }

    @Suite("TestResult Tests")
    struct TestResultTests {
        @Test("Successful result")
        func testSuccessfulResult() {
            let result = TestResult(success: true, error: nil)

            #expect(result.success == true)
            #expect(result.error == nil)
        }

        @Test("Failed result with error")
        func testFailedResult() {
            let result = TestResult(success: false, error: "Binary crashed")

            #expect(result.success == false)
            #expect(result.error == "Binary crashed")
        }
    }

    @Suite("RegressionTestError Tests")
    struct RegressionTestErrorTests {
        @Test("Binary not found error description")
        func testBinaryNotFoundDescription() {
            let error = RegressionTestError.binaryNotFound("/usr/bin/missing")

            #expect(error.description == "Binary not found: /usr/bin/missing")
        }

        @Test("SDK not found error description")
        func testSDKNotFoundDescription() {
            let error = RegressionTestError.sdkNotFound("iphoneos99.0")

            #expect(error.description == "SDK not found: iphoneos99.0")
        }

        @Test("Test failed error description")
        func testTestFailedDescription() {
            let error = RegressionTestError.testFailed("Timeout exceeded")

            #expect(error.description == "Test failed: Timeout exceeded")
        }
    }

    @Suite("Command Configuration Tests")
    struct CommandConfigurationTests {
        @Test("Command name is correct")
        func testCommandName() {
            #expect(RegressionTestCommand.configuration.commandName == "regression-test")
        }

        @Test("Version contains Swift marker")
        func testVersionContainsSwift() {
            let version = RegressionTestCommand.configuration.version
            #expect(version.contains("Swift"))
        }

        @Test("Version follows semantic versioning")
        func testVersionFormat() {
            let version = RegressionTestCommand.configuration.version
            // Should match pattern like "4.0.0 (Swift)"
            let regex = /\d+\.\d+\.\d+ \(Swift\)/
            #expect(version.contains(regex))
        }

        @Test("Abstract is not empty")
        func testAbstractNotEmpty() {
            #expect(!RegressionTestCommand.configuration.abstract.isEmpty)
        }

        @Test("Discussion contains examples")
        func testDiscussionContainsExamples() {
            let discussion = RegressionTestCommand.configuration.discussion
            #expect(discussion.contains("Examples"))
            #expect(discussion.contains("--reference"))
        }
    }
}
