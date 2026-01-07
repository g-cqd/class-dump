import XCTest

import ClassDumpCore

final class TestBlockSignature: XCTestCase {
  private func ascii(_ scalar: UnicodeScalar) -> Int32 {
    Int32(scalar.value)
  }

  func testZeroArguments() throws {
    var types: [CDType] = []
    types.append(CDType(simpleType: ascii("v")))
    types.append(CDType(blockTypeWithTypes: nil))

    let blockType = try XCTUnwrap(CDType(blockTypeWithTypes: types))
    let blockSignatureString = blockType.blockSignatureString()

    XCTAssertEqual(blockSignatureString, "void (^)(void)")
  }

  func testOneArgument() throws {
    var types: [CDType] = []
    types.append(CDType(simpleType: ascii("v")))
    types.append(CDType(blockTypeWithTypes: nil))

    let typeName = CDTypeName()
    typeName.name = "NSData"
    types.append(CDType(idType: typeName))

    let blockType = try XCTUnwrap(CDType(blockTypeWithTypes: types))
    let blockSignatureString = blockType.blockSignatureString()

    XCTAssertEqual(blockSignatureString, "void (^)(NSData *)")
  }

  func testTwoArguments() throws {
    var types: [CDType] = []
    types.append(CDType(simpleType: ascii("v")))
    types.append(CDType(blockTypeWithTypes: nil))
    types.append(CDType(idType: nil))

    let typeName = CDTypeName()
    typeName.name = "NSError"
    types.append(CDType(idType: typeName))

    let blockType = try XCTUnwrap(CDType(blockTypeWithTypes: types))
    let blockSignatureString = blockType.blockSignatureString()

    XCTAssertEqual(blockSignatureString, "void (^)(id, NSError *)")
  }

  func testBlockArgument() throws {
    var types: [CDType] = []
    types.append(CDType(simpleType: ascii("v")))
    types.append(CDType(blockTypeWithTypes: nil))

    let nestedTypes = types
    types.append(CDType(blockTypeWithTypes: nestedTypes))

    let blockType = try XCTUnwrap(CDType(blockTypeWithTypes: types))
    let blockSignatureString = blockType.blockSignatureString()

    XCTAssertEqual(blockSignatureString, "void (^)(void (^)(void))")
  }

  func testBoolArgument() throws {
    var types: [CDType] = []
    types.append(CDType(simpleType: ascii("v")))
    types.append(CDType(blockTypeWithTypes: nil))
    types.append(CDType(simpleType: ascii("c")))

    let blockType = try XCTUnwrap(CDType(blockTypeWithTypes: types))
    let blockSignatureString = blockType.blockSignatureString()

    XCTAssertEqual(blockSignatureString, "void (^)(BOOL)")
  }
}
