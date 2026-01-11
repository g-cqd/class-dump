// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjCMethod Tests", .serialized)
struct ObjCMethodTests {
    @Test("Method argument count")
    func argumentCount() {
        let method1 = ObjCMethod(name: "init", typeString: "@16@0:8")
        #expect(method1.argumentCount == 0)
        #expect(method1.isUnary)

        let method2 = ObjCMethod(name: "initWithFrame:", typeString: "@40@0:8{CGRect=dddd}16")
        #expect(method2.argumentCount == 1)
        #expect(!method2.isUnary)

        let method3 = ObjCMethod(name: "tableView:cellForRowAtIndexPath:", typeString: "@32@0:8@16@24")
        #expect(method3.argumentCount == 2)
    }

    @Test("Method comparison")
    func comparison() {
        let method1 = ObjCMethod(name: "aMethod", typeString: "v16@0:8")
        let method2 = ObjCMethod(name: "bMethod", typeString: "v16@0:8")
        #expect(method1 < method2)
    }
}
