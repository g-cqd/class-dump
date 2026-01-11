// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("SIMD/Vector Type Tests")
struct SIMDVectorTypeTests {

    @Test("Parse simd_float2 as struct")
    func parseSimdFloat2() throws {
        let type = try ObjCType.parse("{simd_float2=ff}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_float2")
        #expect(members.count == 2)
        #expect(members[0].type == .float)
        #expect(members[1].type == .float)
    }

    @Test("Parse simd_float3 as struct")
    func parseSimdFloat3() throws {
        let type = try ObjCType.parse("{simd_float3=fff}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_float3")
        #expect(members.count == 3)
    }

    @Test("Parse simd_float4 as struct")
    func parseSimdFloat4() throws {
        let type = try ObjCType.parse("{simd_float4=ffff}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_float4")
        #expect(members.count == 4)
    }

    @Test("Parse simd_float4x4 matrix")
    func parseSimdFloat4x4() throws {
        let encoding = "{simd_float4x4=\"columns\"[4{simd_float4=ffff}]}"
        let type = try ObjCType.parse(encoding)

        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_float4x4")
        #expect(members.count == 1)
        #expect(members[0].name == "columns")

        guard case .array(let count, let elementType) = members[0].type else {
            Issue.record("Expected array type")
            return
        }
        #expect(count == "4")

        guard case .structure(let vecName, let vecMembers) = elementType else {
            Issue.record("Expected structure element type")
            return
        }
        #expect(vecName?.name == "simd_float4")
        #expect(vecMembers.count == 4)
    }

    @Test("Parse simd_int4 as struct")
    func parseSimdInt4() throws {
        let type = try ObjCType.parse("{simd_int4=iiii}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_int4")
        #expect(members.count == 4)
        #expect(members.allSatisfy { $0.type == .int })
    }

    @Test("Parse simd_double2 as struct")
    func parseSimdDouble2() throws {
        let type = try ObjCType.parse("{simd_double2=dd}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_double2")
        #expect(members.count == 2)
        #expect(members.allSatisfy { $0.type == .double })
    }
}
